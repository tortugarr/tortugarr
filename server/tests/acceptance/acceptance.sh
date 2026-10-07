#!/bin/bash
# Acceptance test, part 2 - run as root on the test machine AFTER
#   prepare-media.sh  and  ./install.sh install --answers tests/acceptance/answers.env
#
# Proves each service end to end and writes a table of what was proven and what was
# not tested to /opt/tortugarr/acceptance-report.md. Exit code = number of failures.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
I=/opt/tortugarr
S=$I/secrets.json
port() { jq -r ".ports.$1" $I/state.json; }
RK=$(jq -r .radarr_api_key $S); SK=$(jq -r .sonarr_api_key $S); PK=$(jq -r .prowlarr_api_key $S)
BK=$(jq -r .bazarr_api_key $S); JK=$(jq -r .jellyfin_api_key $S)
U=$(jq -r .admin_user $S); P=$(jq -r .admin_password $S)
RADARR=http://127.0.0.1:$(port radarr)/api/v3
SONARR=http://127.0.0.1:$(port sonarr)/api/v3
PROWLARR=http://127.0.0.1:$(port prowlarr)/api/v1
BAZARR=http://127.0.0.1:$(port bazarr)/api
JELLY=http://127.0.0.1:$(port jellyfin)
SEERR=http://127.0.0.1:$(port seerr)/api/v1
REPORT=$I/acceptance-report.md
JAR=$(mktemp)

r()  { curl -s -m 60 -H "X-Api-Key: $RK" "$@"; }
s()  { curl -s -m 60 -H "X-Api-Key: $SK" "$@"; }
pr() { curl -s -m 120 -H "X-Api-Key: $PK" "$@"; }
bz() { curl -s -m 120 -H "X-API-KEY: $BK" "$@"; }
jf() { curl -s -m 60 -H "Authorization: MediaBrowser Token=\"$JK\"" "$@"; }
se() { curl -s -m 60 -b "$JAR" -c "$JAR" "$@"; }

declare -A PROVEN NOTE
FAILS=0
pass() { echo "PASS  [$1] $2"; PROVEN[$1]+="- $2"$'\n'; }
fail() { echo "FAIL  [$1] $2"; NOTE[$1]+="- **FAILED:** $2"$'\n'; FAILS=$((FAILS + 1)); }
info() { echo "INFO  [$1] $2"; NOTE[$1]+="- $2"$'\n'; }
# wait_for SECONDS "jq-test or shell command" - polls every 10 s until it prints "true"
wait_for() {
  local t=$1; shift
  local end=$((SECONDS + t))
  while [ $SECONDS -lt $end ]; do
    [ "$("$@" 2>/dev/null | tail -1)" = true ] && return 0
    sleep 10
  done
  return 1
}
jellyfin_refresh() { jf -X POST "$JELLY/Library/Refresh" >/dev/null; }
jf_items() { jf "$JELLY/Items?Recursive=true&IncludeItemTypes=$1&Fields=Path"; }

echo "== 1. Existing library (pointed to by the installer)"
jellyfin_refresh
for m in "Big Buck Bunny" "Sintel" "Tears of Steel"; do
  if wait_for 300 bash -c "$(declare -f jf jf_items); JK='$JK' JELLY='$JELLY'; jf_items Movie | jq --arg n '$m' 'any(.Items[]; .Name == \$n)'"; then
    pass jellyfin "existing movie '$m' identified in the library"
  else fail jellyfin "existing movie '$m' not in the library after 5 min"; fi
done
if wait_for 300 bash -c "$(declare -f jf jf_items); JK='$JK' JELLY='$JELLY'; jf_items Episode | jq '[.Items[] | select(.SeriesName == \"The Beverly Hillbillies\")] | length == 2'"; then
  pass jellyfin "existing series identified, both episodes listed"
else fail jellyfin "existing series not fully listed: $(jf_items Episode | jq -c '[.Items[] | {SeriesName, Name}]')"; fi
for m in "Big Buck Bunny" "Sintel" "Tears of Steel"; do
  got=$(r "$RADARR/movie" | jq -r --arg n "$m" '[.[] | select(.title == $n)][0] | "\(.hasFile) \(.monitored)"')
  case "$got" in
    "true false") pass radarr "existing movie '$m' registered with its file, unmonitored (no re-download)" ;;
    "true true")  pass radarr "existing movie '$m' registered with its file"; info radarr "'$m' is monitored - upgrades could be fetched" ;;
    *) fail radarr "existing movie '$m' not registered with its file (got: $got)" ;;
  esac
done
got=$(s "$SONARR/series" | jq -r '[.[] | select(.title == "The Beverly Hillbillies")][0] | "\(.statistics.episodeFileCount)"')
[ "$got" = 2 ] && pass sonarr "existing series registered with both episode files" \
  || fail sonarr "existing series not registered with its files (episode files: $got)"

echo "== 2. Indexer: Prowlarr search, sync to Sonarr/Radarr"
# A local web seed and a local Torznab feed with only the two test releases, so the
# chain needs no public tracker or swarm and always sees the same bytes.
TOOLS=$(grep -E '^IMAGE_TOOLS=' "$HERE/../../versions.env" | cut -d= -f2-)
docker rm -f tortugarr-test-seed tortugarr-test-indexer >/dev/null 2>&1
docker run -d --name tortugarr-test-seed --network tortugarr -v /srv/test-seed:/usr/share/nginx/html:ro nginx:alpine >/dev/null
for f in /srv/test-seed/files/*; do
  python3 "$HERE/make_torrent.py" "$f" "http://tortugarr-test-seed/files/" "/srv/test-seed/torrents/$(basename "$f").torrent" >/dev/null
done
docker run -d --name tortugarr-test-indexer --network tortugarr -v "$HERE:/t:ro" -v /srv/test-seed:/seed:ro "$TOOLS" python3 /t/torznab_mock.py >/dev/null
sleep 3
schema=$(pr "$PROWLARR/indexer/schema" | jq -c '[.[] | select(.implementation == "Torznab")][0]')
body=$(jq -c '.name = "Acceptance test indexer" | .enable = true | .appProfileId = 1 | .priority = 25
  | .fields |= map(if .name == "baseUrl" then .value = "http://tortugarr-test-indexer:8080" elif .name == "apiPath" then .value = "/api" else . end)' <<< "$schema")
add=$(pr -H 'Content-Type: application/json' -d "$body" "$PROWLARR/indexer")
if [ -n "$(jq -r '.id? // empty' <<< "$add" 2>/dev/null)" ]; then pass prowlarr "Torznab indexer added and its connection test passed"
else fail prowlarr "could not add the test indexer: $(head -c 300 <<< "$add")"; fi
hits=$(pr "$PROWLARR/search?query=Elephants%20Dream&type=search&limit=50" | jq '[.[] | select(.title | test("Elephants"))] | length' 2>/dev/null)
[ "${hits:-0}" -gt 0 ] && pass prowlarr "search 'Elephants Dream' through Prowlarr found the release" \
  || fail prowlarr "search 'Elephants Dream' through Prowlarr found nothing"
# The sync command itself must succeed (Prowlarr 2.5.2 answered 500 "Sequence contains no matching
# element" and stopped after the first app: Sonarr got the indexers, Radarr none).
sync=$(pr -w '\t%{http_code}' -X POST -H 'Content-Type: application/json' -d '{"name":"ApplicationIndexerSync"}' "$PROWLARR/command")
sid=$(jq -r '.id // empty' <<< "${sync%$'\t'*}" 2>/dev/null); st=""
for i in $(seq 1 30); do st=$(pr "$PROWLARR/command/$sid" | jq -r '.status // empty'); case $st in completed|failed|aborted) break ;; esac; sleep 2; done
[ "${sync##*$'\t'}" = 201 ] && [ "$st" = completed ] && pass prowlarr "the application sync command ran to completed (HTTP 201)" \
  || fail prowlarr "application sync: HTTP ${sync##*$'\t'}, status '${st:-none}': $(head -c 200 <<< "${sync%$'\t'*}")"
for app in sonarr radarr; do
  fn=s; api=$SONARR; [ $app = radarr ] && { fn=r; api=$RADARR; }
  if wait_for 120 bash -c "$(declare -f $fn); SK='$SK' RK='$RK'; $fn '$api/indexer' | jq 'any(.[]; .name | test(\"Acceptance test indexer\"))'"; then
    pass prowlarr "indexer synced to ${app^} automatically"
  else fail prowlarr "indexer did not sync to ${app^}"; fi
done
# Both apps, not only the first one, and the *arr can reach Prowlarr through the indexer it got.
[ "$(s "$SONARR/indexer" | jq length)" -ge 1 ] && [ "$(r "$RADARR/indexer" | jq length)" -ge 1 ] \
  && pass prowlarr "after the sync BOTH Sonarr ($(s "$SONARR/indexer" | jq length)) and Radarr ($(r "$RADARR/indexer" | jq length)) have the indexer(s)" \
  || fail prowlarr "after the sync Sonarr has $(s "$SONARR/indexer" | jq length), Radarr $(r "$RADARR/indexer" | jq length) indexer(s)"
for app in sonarr radarr; do
  fn=s; api=$SONARR; [ $app = radarr ] && { fn=r; api=$RADARR; }
  body=$($fn "$api/indexer" | jq -c '[.[] | select(.name | test("Acceptance test indexer"))][0]')
  code=$($fn -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "$body" "$api/indexer/test")
  [ "$code" = 200 ] && pass prowlarr "${app^} reaches Prowlarr through the synced indexer (indexer test OK)" || fail prowlarr "${app^} indexer test answered $code"
done
# Prowlarr 2.6 added hostname validation, Allowed Hosts and Trusted Networks: nothing may block
# the containers' calls (above) or the user's browser on the LAN address.
ph=$(pr "$PROWLARR/health" | jq -c '[.[] | select(.message | test("host|trusted|allowed"; "i")) | .message]')
[ "$ph" = "[]" ] && pass prowlarr "no Allowed Hosts / Trusted Networks warnings in Prowlarr's health" || fail prowlarr "Prowlarr health: $ph"
lan=$(jq -r .lan_ip $I/state.json)
[ "$(curl -s -o /dev/null -w '%{http_code}' -m 20 "http://$lan:$(port prowlarr)/ping")" = 200 ] \
  && pass prowlarr "Prowlarr answers on the LAN address the user's browser uses (http://$lan:$(port prowlarr))" \
  || fail prowlarr "Prowlarr does not answer on http://$lan:$(port prowlarr)"

echo "== 3. Download chain: Seerr -> Sonarr/Radarr (automatic search) -> qBittorrent -> automatic import -> Jellyfin"
T3=$(date -u +%Y-%m-%dT%H:%M:%SZ)
se -H 'Content-Type: application/json' -d "{\"username\":\"$U\",\"password\":\"$P\"}" "$SEERR/auth/jellyfin" >/dev/null

chain() {  # kind(tv|movie) "search title" release-file
  local kind=$1 title=$2 file=$3 app svc api id tmdb body t0 ok_import=""
  [ "$kind" = tv ] && { app=sonarr; svc=s; api=$SONARR; } || { app=radarr; svc=r; api=$RADARR; }
  tmdb=$(se "$SEERR/search?query=$(jq -rn --arg q "$title" '$q|@uri')&page=1" | jq -r --arg k "$kind" --arg t "$title" \
    '[.results[] | select(.mediaType == $k and ((.name // .title) | ascii_downcase | startswith($t | ascii_downcase)))][0].id // empty')
  [ -z "$tmdb" ] && { fail seerr "'$title' not found in Seerr search"; return; }
  pass seerr "'$title' found in Seerr search (TMDB $tmdb)"
  if [ "$kind" = tv ]; then body="{\"mediaType\":\"tv\",\"mediaId\":$tmdb,\"seasons\":[1]}"; else body="{\"mediaType\":\"movie\",\"mediaId\":$tmdb}"; fi
  local req; req=$(se -H 'Content-Type: application/json' -d "$body" "$SEERR/request")
  if [ "$(jq -r '.status // empty' <<< "$req")" = 2 ]; then pass seerr "request for '$title' approved and sent on"
  else fail seerr "request for '$title' failed: $(head -c 300 <<< "$req")"; return; fi
  if [ "$kind" = tv ]; then
    wait_for 120 bash -c "$(declare -f s); SK='$SK'; s '$SONARR/series' | jq --arg t '$title' 'any(.[]; .title == \$t)'" \
      && pass sonarr "'$title' added by Seerr" || { fail sonarr "'$title' never arrived from Seerr"; return; }
    id=$(s "$SONARR/series" | jq -r --arg t "$title" '.[] | select(.title == $t) | .id')
  else
    wait_for 120 bash -c "$(declare -f r); RK='$RK'; r '$RADARR/movie' | jq --arg t '$title' 'any(.[]; .title == \$t)'" \
      && pass radarr "'$title' added by Seerr" || { fail radarr "'$title' never arrived from Seerr"; return; }
    id=$(r "$RADARR/movie" | jq -r --arg t "$title" '.[] | select(.title == $t) | .id')
  fi
  local rel; rel=$(basename "$file"); rel=${rel%.*}
  t0=$SECONDS
  # Seerr asks for a search when it adds the title; the synced indexer should answer it.
  if wait_for 240 bash -c "$(declare -f $svc); SK='$SK' RK='$RK'; $svc '$api/history?pageSize=20' | jq --arg r '$rel' 'any(.records[]; .eventType == \"grabbed\" and .sourceTitle == \$r)'"; then
    pass $app "'$rel' found by the automatic search after the request and grabbed (within $((SECONDS - t0 + 10)) s)"
  else
    info $app "automatic search did not grab '$rel' within 4 min - handing the release over directly instead"
    local push; push=$($svc -H 'Content-Type: application/json' -d "$(jq -nc --arg t "$rel" --arg u "http://tortugarr-test-seed/torrents/$(basename "$file").torrent" \
        --argjson z "$(stat -c %s "$file")" '{title:$t, downloadUrl:$u, protocol:"torrent", publishDate:(now|todate), size:$z, indexer:"Acceptance test"}')" "$api/release/push")
    if [ "$(jq -r '(.[0] // .).approved' <<< "$push")" = true ]; then info $app "release '$rel' accepted when handed over directly"
    else fail $app "release '$rel' rejected: $(jq -c '(.[0] // .).rejections' <<< "$push")"; return; fi
  fi
  t0=$SECONDS
  if [ "$kind" = tv ]; then
    wait_for 900 bash -c "$(declare -f s); SK='$SK'; s '$SONARR/episode?seriesId=$id' | jq 'any(.[]; .seasonNumber == 1 and .episodeNumber == 1 and .hasFile)'" && ok_import=1
  else
    wait_for 900 bash -c "$(declare -f r); RK='$RK'; r '$RADARR/movie/$id' | jq '.hasFile'" && ok_import=1
  fi
  if [ -n "$ok_import" ]; then
    pass qbittorrent "'$rel' downloaded (category from $app)"
    pass $app "'$title' imported automatically, no manual import (done within $((SECONDS - t0 + 10)) s of the grab)"
    local lib; lib=$(find /srv/tortugarr/media -type f -path "*${title}*" -printf '%n %p\n' | head -1)
    [ "${lib%% *}" = 2 ] && pass $app "library file is a hardlink to the download (no extra space): ${lib#* }" \
      || info $app "library file link count: ${lib:-not found}"
    local type=Movie; [ "$kind" = tv ] && type=Episode
    if wait_for 300 bash -c "$(declare -f jf jf_items); JK='$JK' JELLY='$JELLY'; jf_items $type | jq --arg t '$title' 'any(.Items[]; (.SeriesName // .Name) == \$t)'"; then
      pass jellyfin "'$title' appeared after the import (refresh webhook from $app)"
    else fail jellyfin "'$title' not in Jellyfin 5 min after import"; fi
  else
    fail $app "'$title' not imported within 15 min; queue: $($svc "$api/queue?pageSize=5" | jq -c '[.records[] | {title, status, trackedDownloadState, statusMessages}]' | head -c 600)"
  fi
}
chain tv "Pioneer One" /srv/test-seed/files/Pioneer.One.S01E01.1080p.WEB-DL.AAC2.0.H.264-TEST.mkv
chain movie "Elephants Dream" /srv/test-seed/files/Elephants.Dream.2006.1080p.WEB-DL.AAC2.0.H.264-TEST.mov

# The imports above reached Jellyfin through the plugin's targeted refresh (spec 3.12), not a
# scan of every library.
# Seerr shows the request as available soon after the import (the plugin starts Seerr's
# recently-added scan), not only at Seerr's next 5-minute run.
EDT3=$(se "$SEERR/search?query=Elephants%20Dream&page=1" | jq -r '[.results[] | select(.mediaType == "movie" and .title == "Elephants Dream")][0].id // empty')
if wait_for 150 bash -c "$(declare -f se); JAR='$JAR'; se '$SEERR/movie/$EDT3' | jq '.mediaInfo.status == 5'" \
   && [ "$(docker logs --since "$T3" tortugarr-jellyfin 2>&1 | grep -c 'Seerr recently-added scan started')" -ge 1 ]; then
  pass seerr "the request showed as available right after the import (scan started by the plugin)"
else fail seerr "Elephants Dream not available in Seerr within 150 s of the import, or no scan started by the plugin"; fi
hooks=$(docker logs --since "$T3" tortugarr-jellyfin 2>&1 | grep -c "hook - refreshing")
full=$(docker logs --since "$T3" tortugarr-jellyfin 2>&1 | grep -c "Validating media library")
[ "$hooks" -ge 2 ] && [ "$full" = 0 ] \
  && pass jellyfin "imports refreshed only the changed folder ($hooks targeted refresh(es), no scan of all libraries)" \
  || fail jellyfin "targeted refresh: $hooks hook refresh(es), $full full library scan(s) since the chain started"
echo "== 3b. The Tortugarr plugin chain (what the public app uses): search -> grab -> check -> import"
PT=$JELLY/Tortugarr/v1
ATOK=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: MediaBrowser Client="acceptance", Device="lab", DeviceId="acceptance-admin", Version="1"' \
  -d "$(jq -nc --arg u "$U" --arg p "$P" '{Username:$u, Pw:$p}')" "$JELLY/Users/AuthenticateByName" | jq -r '.AccessToken // empty')
pc() { curl -s -m 200 -H "Authorization: MediaBrowser Token=\"$ATOK\"" "$@"; }
A327=$(r "$RADARR/movie/lookup?term=$(jq -rn '"Sita Sings the Blues"|@uri')" | jq -r '[.[] | select((.title | test("^Sita Sings the Blues")) and .year == 2008)][0].tmdbId // empty')
if [ -z "$A327" ]; then fail plugin "test title 'Sita Sings the Blues' not found in Radarr's lookup"
else
  sid=$(pc -X POST -H 'Content-Type: application/json' -d "{\"type\":\"movie\",\"tmdbId\":$A327}" "$PT/Searches" | jq -r '.searchId // empty')
  st=running
  for i in $(seq 1 90); do res=$(pc "$PT/Searches/$sid"); st=$(jq -r .status <<< "$res"); [ "$st" != running ] && break; sleep 2; done
  if [ "$st" != done ]; then fail plugin "search ended as $st: $(head -c 300 <<< "$res")"
  else
    pass plugin "asynchronous search done: $(jq '.result.releases | length' <<< "$res") release(s) after the filters, droppedEarly $(jq .result.droppedEarly <<< "$res")"
    [ "$(jq '.result.dropped | type' <<< "$res")" = '"object"' ] && pass plugin "the search result says what the filters dropped: $(jq -c .result.dropped <<< "$res")" || fail plugin "no dropped counts in the search result"
    rel=$(jq -c '[.result.releases[] | select(.recommended and (.title | test("Sita.Sings")))][0] // empty' <<< "$res")
    arrId=$(jq -r .result.arrId <<< "$res")
    [ "$(r "$RADARR/movie/$arrId" | jq .monitored)" = true ] && pass plugin "the movie was added to Radarr monitored, without a search of its own"
    if [ -z "$rel" ]; then fail plugin "no recommended release for the test title: $(jq -c '[.result.releases[] | {title, rejections}]' <<< "$res" | head -c 400)"
    else
      g=$(pc -X POST -H 'Content-Type: application/json' -d "$(jq -nc --argjson a "$arrId" --argjson x "$rel" '{type:"movie", arrId:$a, guid:$x.guid, indexerId:$x.indexerId}')" "$PT/Grab")
      did=$(jq -r '.downloadId // empty' <<< "$g")
      [ "$(jq .queued <<< "$g")" = true ] && [ -n "$did" ] && pass plugin "Grab answered once the movie was in Radarr's queue (queued: true) - the app's Seerr request can follow safely" \
        || fail plugin "Grab: $(head -c 300 <<< "$g")"
      act=wait
      for i in $(seq 1 30); do chk=$(pc -X POST "$PT/Downloads/$did/Check"); act=$(jq -r '.action // .error.code' <<< "$chk"); [ "$act" != wait ] && break; sleep 2; done
      case $act in
        kept) pass plugin "video check right after the grab: the torrent holds a video (kept)" ;;
        *) fail plugin "video check answered: $(head -c 300 <<< "$chk")" ;;
      esac
      if wait_for 900 bash -c "$(declare -f r); RK='$RK'; r '$RADARR/movie/$arrId' | jq '.hasFile'"; then
        pass plugin "imported automatically by Radarr after the plugin's grab"
        wait_for 300 bash -c "$(declare -f jf jf_items); JK='$JK' JELLY='$JELLY'; jf_items Movie | jq 'any(.Items[]; .Name | test(\"^Sita Sings the Blues\"))'" \
          && pass plugin "the movie appeared in Jellyfin" || fail plugin "not in Jellyfin 5 min after the import"
      else fail plugin "not imported within 15 min"; fi
    fi
  fi
fi

echo "== 3c. Adult library through the plugin (switched on by tests/e2e-plugin.sh, as the admin page does)"
if [ "$(pc "$PT/Capabilities" | jq .features.adult)" != true ]; then fail plugin "adult library is not on"
else
  asid=$(pc -X POST -H 'Content-Type: application/json' -d '{"query":"Sample Clip"}' "$PT/Adult/Searches" | jq -r '.searchId // empty')
  for i in $(seq 1 90); do ares=$(pc "$PT/Adult/Searches/$asid"); [ "$(jq -r .status <<< "$ares")" != running ] && break; sleep 2; done
  arel=$(jq -c '[.result.releases[]? | select(.title | test("Sample.Clip"))][0] // empty' <<< "$ares")
  if [ -z "$arel" ]; then fail plugin "adult search found nothing: $(head -c 300 <<< "$ares")"
  else
    pass plugin "adult search (phrase + each word, categories 6000-6090): found the test clip, matchedWords $(jq .matchedWords <<< "$arel")"
    ag=$(pc -X POST -H 'Content-Type: application/json' -d "$(jq -nc --arg s "$asid" --argjson x "$arel" '{searchId:$s, guid:$x.guid, indexerId:$x.indexerId}')" "$PT/Adult/Grab")
    [ -n "$(jq -r '.downloadId // empty' <<< "$ag")" ] && pass plugin "adult grab went straight to qBittorrent (category adult)" || fail plugin "adult grab: $(head -c 300 <<< "$ag")"
    alib=$(jf "$JELLY/Library/VirtualFolders" | jq -r '[.[] | select(.Locations | index("/data/media/adult"))][0].ItemId // empty')
    if wait_for 300 bash -c "$(declare -f jf); JK='$JK'; jf '$JELLY/Items?Recursive=true&ParentId=$alib&IncludeItemTypes=Video,Movie' | jq '.TotalRecordCount > 0'"; then
      pass plugin "the clip landed in the adult library's folder and shows in that library"
    else fail plugin "the clip did not show in the adult library within 5 min"; fi
    curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ATOK\"" -H 'Content-Type: application/json' -d '{"Name":"acceptance-viewer","Password":"Viewer-pass-456"}' "$JELLY/Users/New"
    vtok=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: MediaBrowser Client="acceptance", Device="lab", DeviceId="acceptance-viewer", Version="1"' \
      -d '{"Username":"acceptance-viewer","Pw":"Viewer-pass-456"}' "$JELLY/Users/AuthenticateByName" | jq -r '.AccessToken // empty')
    seen=$(curl -s -H "Authorization: MediaBrowser Token=\"$vtok\"" "$JELLY/Items?Recursive=true&SearchTerm=Sample" | jq '.TotalRecordCount')
    [ "$seen" = 0 ] && pass plugin "a non-admin user does not see the clip" || fail plugin "a non-admin sees $seen adult item(s)"
  fi
fi

echo "== 3d. Series status, season switch and free space through the plugin (spec 3.14, 3.15)"
ser=$(pc "$PT/Series/170551")
ep1=$(jq -c '[.seasons[]? | select(.seasonNumber == 1) | .episodes[] | select(.episodeNumber == 1)][0]' <<< "$ser")
[ "$(jq .inSonarr <<< "$ser")" = true ] && [ "$(jq .hasFile <<< "$ep1")" = true ] && [ "$(jq '.queued | type' <<< "$ep1")" = '"boolean"' ] \
  && pass plugin "series status (3.14): Pioneer One with its seasons, S01E01 has its file, queue state per episode" \
  || fail plugin "series status: $(head -c 300 <<< "$ser")"
[ "$(pc "$PT/Series/999999999" | jq .inSonarr)" = false ] && pass plugin "series status of a series Sonarr does not have: inSonarr false (not added)" || fail plugin "unknown series was not answered with inSonarr false"
poid=$(jq .arrId <<< "$ser")
on=$(pc -X PUT -H 'Content-Type: application/json' -d '{"monitored":true,"search":false}' "$PT/Series/170551/Seasons/1")
sv=$(s "$SONARR/series/$poid"); aired_on=$(s "$SONARR/episode?seriesId=$poid&seasonNumber=1" | jq --arg now "$(date -u +%FT%TZ)" '[.[] | select(.airDateUtc != null and .airDateUtc <= $now and .monitored)] | length')
if [ "$(jq -r '.seasonMonitoring["1"]' <<< "$on")" = true ] && [ "$(jq .monitored <<< "$sv")" = true ] && [ "$(jq -r .monitorNewItems <<< "$sv")" = none ] && [ "$aired_on" = 0 ]; then
  pass plugin "season switched on without a search (3.14): season and series monitored, new items 'none', aired episodes unmonitored - as the app does"
else fail plugin "season on: $(head -c 200 <<< "$on"); series monitored $(jq .monitored <<< "$sv"), monitorNewItems $(jq -r .monitorNewItems <<< "$sv"), aired still monitored: $aired_on"; fi
off=$(pc -X PUT -H 'Content-Type: application/json' -d '{"monitored":false}' "$PT/Series/170551/Seasons/1")
[ "$(jq -r '.seasonMonitoring["1"]' <<< "$off")" = false ] && [ "$(s "$SONARR/series/$poid" | jq .monitored)" = false ] \
  && pass plugin "season switched off: the last monitored season off turns the series off" || fail plugin "season off: $(head -c 200 <<< "$off")"
cand=$(pc "$PT/Space/Candidates")
if [ "$(jq '[.titles[] | select(.kind == "movie" and .bytes > 0 and .jellyfinId != null)] | length' <<< "$cand")" -ge 1 ] \
   && [ "$(jq '[.titles[] | select(.kind == "series")] | length' <<< "$cand")" -ge 1 ] && [ "$(jq '.duplicates | type' <<< "$cand")" = '"array"' ] \
   && [ "$(jq '[.titles[] | has("lastPlayed") and has("favorite") and has("added")] | all' <<< "$cand")" = true ]; then
  pass plugin "free-space candidates (3.15): $(jq '.titles | length' <<< "$cand") title(s) with size, Jellyfin id, added, last played and favorite; $(jq '.duplicates | length' <<< "$cand") duplicate torrent(s)"
else fail plugin "free-space candidates: $(head -c 300 <<< "$cand")"; fi
[ "$(pc -o /dev/null -w '%{http_code}' -X DELETE "$PT/Space/Duplicates/0000000000000000000000000000000000000000")" = 404 ] \
  && pass plugin "removing a torrent that is not a duplicate: 404" || fail plugin "unknown duplicate was not refused"
small=$(pc "$PT/Space/Check?bytes=1000"); huge=$(pc "$PT/Space/Check?bytes=1000000000000000")
if [ "$(jq .neededBytes <<< "$small")" = "$(( 1000 + 10737418240 ))" ] && [ "$(jq .enough <<< "$huge")" = false ] && [ "$(jq '.shortfallBytes > 0' <<< "$huge")" = true ]; then
  pass plugin "space check (3.15): needed = size + 10 GB buffer, a release far beyond the free space has a shortfall"
else fail plugin "space check: small $(head -c 200 <<< "$small") huge $(head -c 200 <<< "$huge")"; fi

echo "== 4. Bazarr subtitles"
bz -X POST -d taskid=update_movies "$BAZARR/system/tasks" >/dev/null
bz -X POST -d taskid=update_series "$BAZARR/system/tasks" >/dev/null
WITH_FILES=$(r "$RADARR/movie" | jq '[.[] | select(.hasFile)] | length')
wait_for 300 bash -c "$(declare -f bz); BK='$BK'; bz '$BAZARR/movies?start=0&length=-1' | jq '(.data | length) >= $WITH_FILES'" \
  && pass bazarr "synced all $WITH_FILES movies that have a file from Radarr" \
  || fail bazarr "movies did not arrive from Radarr: $(bz "$BAZARR/movies?start=0&length=-1" | head -c 300)"
TOS=$(bz "$BAZARR/movies?start=0&length=-1" | jq -r '.data[] | select(.title == "Tears of Steel") | .radarrId')
if [ -n "$TOS" ]; then
  bz -X PATCH -d "radarrid=$TOS" -d action=scan-disk "$BAZARR/movies" >/dev/null; sleep 5
  [ "$(bz "$BAZARR/movies?radarrid%5B%5D=$TOS" | jq '[.data[0].subtitles[]? | select(.code2 == "en" and .path != null)] | length > 0')" = true ] \
    && pass bazarr "found the existing English subtitle file next to 'Tears of Steel'" \
    || fail bazarr "did not see the subtitle file next to 'Tears of Steel'"
fi
fetched_online=""; fetched_file=""
for t in "Big Buck Bunny" "Sintel" "Elephants Dream"; do
  id=$(bz "$BAZARR/movies?start=0&length=-1" | jq -r --arg t "$t" '.data[] | select(.title == $t) | .radarrId')
  [ -z "$id" ] && continue
  cands=$(bz "$BAZARR/providers/movies?radarrid=$id")
  n=$(jq '.data | length' <<< "$cands" 2>/dev/null || echo 0)
  info bazarr "provider search for '$t': ${n:-0} candidate(s)$( [ "${n:-0}" -gt 0 ] && echo " from $(jq -r '[.data[].provider] | unique | join(", ")' <<< "$cands")")"
  [ "${n:-0}" -gt 0 ] || continue
  # Prefer a subtitle from the internet over one extracted from the video file.
  c=$(jq -c '([.data[] | select(.provider != "embeddedsubtitles")][0]) // .data[0]' <<< "$cands")
  prov=$(jq -r .provider <<< "$c")
  bz -X POST --data-urlencode "radarrid=$id" --data-urlencode "hi=$(jq -r '.hearing_impaired // "False"' <<< "$c")" \
     --data-urlencode "forced=$(jq -r '.forced // "False"' <<< "$c")" --data-urlencode "original_format=False" \
     --data-urlencode "provider=$prov" --data-urlencode "subtitle=$(jq -r .subtitle <<< "$c")" \
     "$BAZARR/providers/movies" >/dev/null
  sleep 5
  [ "$(bz "$BAZARR/movies?radarrid%5B%5D=$id" | jq '[.data[0].subtitles[]? | select(.path != null)] | length > 0')" = true ] || continue
  if [ "$prov" = embeddedsubtitles ]; then
    pass bazarr "saved a subtitle for '$t' extracted from the video file itself (embeddedsubtitles - no internet source)"; fetched_file=1
  else
    pass bazarr "downloaded a subtitle for '$t' from the internet ($prov) and saved it next to the file"; fetched_online=1
  fi
done
sub=$(curl -s -m 200 -H "Authorization: MediaBrowser Token=\"$ATOK\"" "$JELLY/Tortugarr/v1/Subtitles?type=movie&tmdbId=45745")
[ "$(jq '.candidates | type' <<< "$sub" 2>/dev/null)" = '"array"' ] \
  && pass plugin "subtitle search through the plugin (Sintel): $(jq '.candidates | length' <<< "$sub") candidate(s)" \
  || fail plugin "subtitle search through the plugin: $(head -c 300 <<< "$sub")"
st=$(curl -s -m 60 -H "Authorization: MediaBrowser Token=\"$ATOK\"" "$JELLY/Tortugarr/v1/Subtitles/State?type=movie&tmdbId=133701")
[ "$(jq '.have | index("en") != null' <<< "$st" 2>/dev/null)" = true ] && [ "$(jq '.missing | type' <<< "$st")" = '"array"' ] \
  && pass plugin "subtitle state through the plugin (Tears of Steel): have $(jq -c .have <<< "$st"), missing $(jq -c .missing <<< "$st")" \
  || fail plugin "subtitle state: $(head -c 300 <<< "$st")"
code=$(curl -s -o /dev/null -w '%{http_code}' -m 60 -X POST -H "Authorization: MediaBrowser Token=\"$ATOK\"" -H 'Content-Type: application/json' \
  -d '{"type":"movie","tmdbId":133701,"languages":[]}' "$JELLY/Tortugarr/v1/Subtitles/Search")
[ "$code" = 202 ] && pass plugin "Bazarr's automatic search for the missing languages started through the plugin (202)" || fail plugin "subtitle search for missing languages answered $code"
[ "$(jq '.candidates | length' <<< "$sub")" = 0 ] || { [ "$(jq '[.candidates[] | (.originalFormat | type) == "boolean"] | all' <<< "$sub")" = true ] \
  && pass plugin "subtitle candidates carry originalFormat" || fail plugin "subtitle candidates without originalFormat"; }
[ -z "$fetched_online" ] && info bazarr "NOT PROVEN: download from an internet subtitle source - none of the account-free sources had a subtitle for these films (searches above)"

echo "== 4b. Deleting titles through the plugin (spec 3.10) and Seerr after deletes (3.11)"
# Seerr's job runs 2 min after the last removal (debounced); the plugin logs each run.
syncs_since() { docker logs --since "$1" tortugarr-jellyfin 2>&1 | grep -c "Seerr availability-sync started"; }
jf_id() { jf_items "$1" | jq -r --arg t "$2" '[.Items[] | select((.SeriesName // .Name) == $t)][0].Id // empty'; }
gone_in_jellyfin() {  # as the app does: every 3 s, up to 3 min
  local id=$1 i
  for i in $(seq 1 60); do
    [ "$(jf -o /dev/null -w '%{http_code}' "$JELLY/Items/$id")" = 404 ] && return 0
    [ "$(jf "$JELLY/Items?Ids=$id" | jq .TotalRecordCount)" = 0 ] && return 0
    sleep 3
  done
  return 1
}
QB=http://127.0.0.1:$(port torrent_web); QJAR=$(mktemp)
curl -s -c "$QJAR" -H "Referer: $QB" --data-urlencode "username=$U" --data-urlencode "password=$P" "$QB/api/v2/auth/login" >/dev/null
qb_count() { curl -s -b "$QJAR" "$QB/api/v2/torrents/info" | jq --arg n "$1" '[.[] | select(.name | startswith($n))] | length'; }
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Movie: Elephants Dream has a Seerr request from section 3, so "Clear Data" must show.
ED=$(jf_id Movie "Elephants Dream"); EDT=$(r "$RADARR/movie" | jq -r '.[] | select(.title == "Elephants Dream") | .tmdbId')
if [ -z "$ED" ]; then fail plugin "delete: Elephants Dream is not in Jellyfin"
else
  before=$(se "$SEERR/movie/$EDT" | jq -r '.mediaInfo.status // "none"')
  d=$(pc -X DELETE "$PT/Library/$ED")
  if [ "$(jq -r .deleted <<< "$d")" = movie ] && [ "$(jq -r .seerr <<< "$d")" = cleared ]; then
    pass plugin "delete movie (3.10): Elephants Dream deleted with $(jq .files <<< "$d") file, Seerr cleared for that title (was status $before)"
  else fail plugin "delete movie answered: $(head -c 300 <<< "$d")"; fi
  [ "$(jq .torrentsRemoved <<< "$d")" = 1 ] && [ "$(qb_count Elephants)" = 0 ] \
    && pass plugin "its torrent was removed from qBittorrent too (a later request of the same release works)" \
    || fail plugin "Elephants Dream torrent after the delete: torrentsRemoved $(jq .torrentsRemoved <<< "$d"), still in qBittorrent: $(qb_count Elephants)"
  [ "$(r "$RADARR/movie" | jq '[.[] | select(.title == "Elephants Dream")] | length')" = 0 ] \
    && pass plugin "the movie is gone from Radarr (no import exclusion: $(r "$RADARR/exclusions" | jq 'length') exclusion(s))" || fail plugin "Elephants Dream still in Radarr"
  [ "$(se "$SEERR/movie/$EDT" | jq -r '.mediaInfo.status // "none"')" = none ] \
    && pass seerr "after the plugin's delete Seerr has no entry for the movie - it can be requested again at once" \
    || fail seerr "Seerr still has the movie: $(se "$SEERR/movie/$EDT" | jq -c '.mediaInfo | {status}')"
  gone_in_jellyfin "$ED" && pass jellyfin "the deleted movie left Jellyfin within 3 min (the app's check)" || fail jellyfin "Elephants Dream still in Jellyfin after 3 min"
fi
# The same release again right after the delete, through Radarr's own search as a Seerr request
# does (Elephants Dream is under the plugin's 700 MB movie minimum). Radarr before 6.4.4 kept the
# hash as "imported" and never imported the new grab (emulator test, 2026-10-06).
sid=$(pc -X POST -H 'Content-Type: application/json' -d "{\"type\":\"movie\",\"tmdbId\":$EDT}" "$PT/Searches" | jq -r '.searchId // empty')
for i in $(seq 1 90); do res=$(pc "$PT/Searches/$sid"); [ "$(jq -r .status <<< "$res")" != running ] && break; sleep 2; done
edid=$(jq -r '.result.arrId // empty' <<< "$res")
rel=$([ -n "$edid" ] && r "$RADARR/release?movieId=$edid" | jq -c '[.[] | select(.title | test("Elephants"))][0] // empty')
if [ -z "$rel" ]; then fail radarr "re-grab after delete: Radarr found no Elephants Dream release"
else
  r -X POST -H 'Content-Type: application/json' -d "$(jq -c '{guid, indexerId}' <<< "$rel")" "$RADARR/release" >/dev/null
  if wait_for 300 bash -c "$(declare -f r); RK='$RK'; r '$RADARR/movie/$edid' | jq '.hasFile'"; then
    pass radarr "the same release, grabbed again right after the delete, was imported"
  else fail radarr "the same release grabbed again after the delete was not imported within 5 min (Radarr kept the hash as imported)"; fi
fi
# Episode: request history of the series must stay; only the debounced full sync.
PO=$(jf_items Episode | jq -r '[.Items[] | select(.SeriesName == "Pioneer One" and .ParentIndexNumber == 1 and .IndexNumber == 1)][0].Id // empty')
POS=$(s "$SONARR/series" | jq -c '.[] | select(.title == "Pioneer One") | {id, tmdbId}')
if [ -z "$PO" ] || [ -z "$POS" ]; then fail plugin "delete: Pioneer One S01E01 not in Jellyfin/Sonarr"
else
  potm=$(jq .tmdbId <<< "$POS"); poid=$(jq .id <<< "$POS")
  hist=$(se "$SEERR/tv/$potm" | jq -c '[(.mediaInfo.requests // [] | length), (.mediaInfo.id // 0)]')
  d=$(pc -X DELETE "$PT/Library/$PO")
  [ "$(jq -r .deleted <<< "$d")" = episode ] && [ "$(jq -r .seerr <<< "$d")" = sync_queued ] \
    && pass plugin "delete episode (3.10): Pioneer One S01E01 deleted ($(jq .files <<< "$d") file), Seerr: sync queued, no Clear Data" \
    || fail plugin "delete episode answered: $(head -c 300 <<< "$d")"
  [ "$(jq .torrentsRemoved <<< "$d")" = 1 ] && [ "$(qb_count Pioneer)" = 0 ] \
    && pass plugin "the episode's own torrent was removed from qBittorrent" \
    || fail plugin "Pioneer One torrent after the delete: torrentsRemoved $(jq .torrentsRemoved <<< "$d"), still in qBittorrent: $(qb_count Pioneer)"
  ep=$(s "$SONARR/episode?seriesId=$poid&seasonNumber=1" | jq -c '[.[] | select(.episodeNumber == 1)][0] | {monitored, hasFile}')
  [ "$ep" = '{"monitored":false,"hasFile":false}' ] && pass plugin "the episode was unmonitored first and its file deleted; the series stays in Sonarr" \
    || fail plugin "Sonarr episode after delete: $ep"
  after=$(se "$SEERR/tv/$potm" | jq -c '[(.mediaInfo.requests // [] | length), (.mediaInfo.id // 0)]')
  [ "$after" = "$hist" ] && [ "$(jq '.[1]' <<< "$hist")" != 0 ] && pass seerr "the series' Seerr entry and request history are kept after an episode delete ($hist)" \
    || fail seerr "Seerr entry/requests changed by an episode delete: $hist -> $after"
  gone_in_jellyfin "$PO" && pass jellyfin "the deleted episode left Jellyfin within 3 min" || fail jellyfin "Pioneer One S01E01 still in Jellyfin after 3 min"
  # Episode grab through the plugin, as the app's Download Now does. Its history lookup asked Sonarr
  # 4 for eventType=grabbed, which Sonarr rejects (HTTP 400): the app said "Download failed" while
  # the download went ahead (emulator test round 16). The import itself is not checked here: the
  # same release right after a delete is Sonarr 4's known limit (docs/troubleshooting.md).
  sid=$(pc -X POST -H 'Content-Type: application/json' -d '{"type":"episode","tvdbId":170551,"season":1,"episode":1}' "$PT/Searches" | jq -r '.searchId // empty')
  for i in $(seq 1 90); do res=$(pc "$PT/Searches/$sid"); [ "$(jq -r .status <<< "$res")" != running ] && break; sleep 2; done
  rel=$(jq -c '[.result.releases[]? | select(.title | test("Pioneer.One.S01E01"))][0] // empty' <<< "$res")
  if [ -z "$rel" ]; then fail plugin "episode search through the plugin found no Pioneer One S01E01 release ($(head -c 200 <<< "$res"))"
  else
    g=$(pc -X POST -H 'Content-Type: application/json' -d "$(jq -nc --argjson a "$(jq .result.arrId <<< "$res")" --argjson x "$rel" '{type:"episode", arrId:$a, guid:$x.guid, indexerId:$x.indexerId}')" "$PT/Grab")
    if [ "$(jq .queued <<< "$g")" = true ] && [ -n "$(jq -r '.downloadId // empty' <<< "$g")" ] && [ "$(qb_count Pioneer)" = 1 ]; then
      pass plugin "episode grab through the plugin: queued, download id $(jq -r .downloadId <<< "$g" | cut -c1-8)..., the torrent is in qBittorrent"
    else fail plugin "episode grab through the plugin answered: $(head -c 300 <<< "$g") (torrents: $(qb_count Pioneer))"; fi
  fi
fi
# Exactly one Seerr sync for both deletes (the movie was cleared directly; the episode was debounced).
wait_for 300 bash -c "$(declare -f syncs_since); [ \$(syncs_since $T0) -ge 1 ] && echo true" \
  && { sleep 150; n=$(syncs_since "$T0"); [ "$n" = 1 ] && pass seerr "debounced: one availability-sync for the deletes above (runs: $n)" || fail seerr "expected one availability-sync, got $n"; } \
  || fail seerr "no availability-sync within 5 min of the episode delete"
# The last title of a library: The Beverly Hillbillies is the only series in the existing library
# /data/library/2. After the delete that folder is empty, and Jellyfin's scan skips empty library
# folders - the plugin must drop the entry itself (emulator test, 2026-10-07).
BH=$(jf_items Series | jq -r '[.Items[] | select(.Name == "The Beverly Hillbillies")][0].Id // empty')
d=$( [ -n "$BH" ] && pc -X DELETE "$PT/Library/$BH")
[ "$(jq -r .deleted <<< "$d" 2>/dev/null)" = series ] && pass plugin "delete of a whole series (the last one in its library): $(jq -r .files <<< "$d") file(s)" \
  || fail plugin "series delete answered: $(head -c 300 <<< "$d")"
gone_in_jellyfin "$BH" && [ "$(jf_items Episode | jq '[.Items[] | select(.SeriesName == "The Beverly Hillbillies")] | length')" = 0 ] \
  && pass jellyfin "the series and its episodes left Jellyfin although their library folder is now empty" \
  || fail jellyfin "The Beverly Hillbillies (or its episodes) still in Jellyfin after the delete"
# Deleted elsewhere (directly in Radarr): the safety net must start a sync on its own.
T1=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SID6=$(r "$RADARR/movie" | jq -r '.[] | select(.title == "Sita Sings the Blues") | .id')
if [ -n "$SID6" ]; then
  r -X DELETE "$RADARR/movie/$SID6?deleteFiles=true&addImportExclusion=false" >/dev/null
  wait_for 420 bash -c "$(declare -f syncs_since); [ \$(syncs_since $T1) -ge 1 ] && echo true" \
    && pass seerr "a movie deleted directly in Radarr started Seerr's availability-sync through the plugin (3.11 safety net)" \
    || fail seerr "no availability-sync within 7 min after a delete in Radarr"
else fail plugin "Sita Sings the Blues not in Radarr for the safety-net test"; fi
# Grab of a release qBittorrent already has (Sita's torrent stays after the Radarr delete): 409
# already_in_client with category and progress, and the torrent is left alone (spec 3.3).
qb_has_sita() { curl -s -b "$QJAR" "$QB/api/v2/torrents/info" | jq '[.[] | select(.name | test("^Sita"))] | length'; }
before=$(qb_has_sita)
sid=$(pc -X POST -H 'Content-Type: application/json' -d "{\"type\":\"movie\",\"tmdbId\":$A327}" "$PT/Searches" | jq -r '.searchId // empty')
for i in $(seq 1 90); do res=$(pc "$PT/Searches/$sid"); [ "$(jq -r .status <<< "$res")" != running ] && break; sleep 2; done
rel=$(jq -c '[.result.releases[]? | select(.title | test("Sita.Sings"))][0] // empty' <<< "$res")
if [ -z "$rel" ]; then fail plugin "already_in_client: the search found no Sita release ($(head -c 200 <<< "$res"))"
else
  g=$(pc -X POST -H 'Content-Type: application/json' -d "$(jq -nc --argjson a "$(jq .result.arrId <<< "$res")" --argjson x "$rel" '{type:"movie", arrId:$a, guid:$x.guid, indexerId:$x.indexerId}')" "$PT/Grab")
  if [ "$(jq -r .error.code <<< "$g")" = already_in_client ] && [ "$(jq -r .error.category <<< "$g")" = radarr ]; then
    pass plugin "grab of a release qBittorrent already has: 409 already_in_client (category $(jq -r .error.category <<< "$g"), progress $(jq .error.progress <<< "$g"))"
  else fail plugin "grab of an existing torrent answered: $(head -c 300 <<< "$g")"; fi
  [ "$(qb_has_sita)" = "$before" ] && [ "$before" -ge 1 ] && pass plugin "the existing torrent was left alone (the plugin never deletes it)" \
    || fail plugin "Sita torrents in qBittorrent: before $before, after $(qb_has_sita)"
fi
# Refusals: adult title (not in an *arr) and a library folder.
# The adult clip has no Radarr/Sonarr: its qBittorrent download (category adult) goes, with the file.
AC=$(jf_items Video | jq -r '[.Items[] | select(.Name | test("Adult-Test"))][0].Id // empty')
d=$( [ -n "$AC" ] && pc -X DELETE "$PT/Library/$AC")
if [ "$(jq -r .deleted <<< "$d" 2>/dev/null)" = adult ] && [ "$(qb_count Adult-Test)" = 0 ] && [ ! -e /srv/tortugarr/media/adult/Adult-Test.Sample.Clip.1080p.m4v ]; then
  pass plugin "delete of the adult clip: its qBittorrent download and file are gone"
  gone_in_jellyfin "$AC" && pass plugin "the adult clip left Jellyfin within 3 min" || fail plugin "the adult clip is still in Jellyfin"
else fail plugin "adult clip delete answered: $(head -c 300 <<< "$d") (torrents: $(qb_count Adult-Test))"; fi
MV=$(jf "$JELLY/Library/VirtualFolders" | jq -r '.[] | select(.Name == "Movies") | .ItemId')
[ "$(pc -o /dev/null -w '%{http_code}' -X DELETE "$PT/Library/$MV")" = 400 ] && pass plugin "a library folder cannot be deleted (400)" \
  || fail plugin "deleting a library folder was not refused with 400"

echo "== 5. Connecting the app: Jellyfin Quick Connect"
# What the app on the TV and the user's phone/PC browser do, against the server.
TV='MediaBrowser Client="Tortugarr", Device="Acceptance TV", DeviceId="acceptance-tv-1", Version="1.0"'
if [ "$(curl -s "$JELLY/QuickConnect/Enabled")" = true ]; then pass jellyfin "Quick Connect is switched on"
else fail jellyfin "Quick Connect is switched off"; fi
init=$(curl -s -X POST -H "Authorization: $TV" "$JELLY/QuickConnect/Initiate")
code=$(jq -r '.Code // empty' <<< "$init"); qsecret=$(jq -r '.Secret // empty' <<< "$init")
utok=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: MediaBrowser Client="Browser", Device="Phone", DeviceId="acceptance-phone-1", Version="1"' \
  -d "$(jq -nc --arg u "$U" --arg p "$P" '{Username:$u, Pw:$p}')" "$JELLY/Users/AuthenticateByName" | jq -r '.AccessToken // empty')
if [ -n "$code" ] && [ -n "$utok" ] \
   && [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: MediaBrowser Token=\"$utok\"" "$JELLY/QuickConnect/Authorize?code=$code")" = 200 ] \
   && [ "$(curl -s -H "Authorization: $TV" "$JELLY/QuickConnect/Connect?secret=$qsecret" | jq .Authenticated)" = true ]; then
  ttok=$(curl -s -H 'Content-Type: application/json' -H "Authorization: $TV" -d "{\"Secret\":\"$qsecret\"}" "$JELLY/Users/AuthenticateWithQuickConnect" | jq -r '.AccessToken // empty')
  who=$(curl -s -H "Authorization: MediaBrowser Token=\"$ttok\"" "$JELLY/Users/Me" | jq -r '.Name // empty')
  [ "$who" = "$U" ] && pass jellyfin "Quick Connect: the TV got a 6-digit code, the user approved it after logging in with their own password, the TV is logged in as '$who'" \
    || fail jellyfin "Quick Connect: code approved, but the TV login failed (got '$who')"
else
  fail jellyfin "Quick Connect flow failed (code '${code:-none}', user login $([ -n "$utok" ] && echo ok || echo failed))"
fi

echo "== 5b. Menu commands: connection info and support bundle"
info=$(tortugarr info 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
if grep -q "http://$(jq -r .lan_ip $I/state.json):$(port jellyfin)" <<< "$info" && ! grep -qF -- "$P" <<< "$info" && grep -q 'not shown' <<< "$info"; then
  pass jellyfin "'tortugarr info' shows the addresses again, without the password"
else fail jellyfin "'tortugarr info': $(head -c 300 <<< "$info")"; fi
sup=$(tortugarr support 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); bundle=$(ls -t $I/support/tortugarr-support-*.tar.gz 2>/dev/null | head -1)
if [ -n "$bundle" ]; then
  sd=$(mktemp -d); tar -xzf "$bundle" -C "$sd"
  leaked=0
  for k in $(jq -r '.. | strings | select(length >= 6)' $S) $(jq -r '.main.apiKey // empty' $I/config/seerr/settings.json); do
    grep -rqF -- "$k" "$sd" && leaked=$((leaked + 1))
  done
  have=$(ls "$sd" "$sd/logs" | grep -cE 'summary.txt|doctor.txt|containers.txt|jellyfin.log|radarr.log')
  [ "$leaked" = 0 ] && [ "$have" -ge 5 ] \
    && pass jellyfin "support bundle $(basename "$bundle"): summary, doctor, containers and service logs, no password, key or token left" \
    || fail jellyfin "support bundle: $leaked secret(s) left, $have of 5 expected files"
  rm -rf "$sd"
else fail jellyfin "no support bundle made: $(tail -c 300 <<< "$sup")"; fi

echo "== 6. Report"
NOT_TESTED_jellyfin="The Tortugarr app itself on a real TV (Quick Connect was driven through the same server API the app uses); playback; transcoding; hardware acceleration; remote access from outside the home network."
NOT_TESTED_seerr="Requests from the TV app itself (the same API, but not this client); approvals by non-admin users; e-mail/other notification agents."
NOT_TESTED_sonarr="Real indexers (a local Torznab feed stood in); RSS sync; season packs; anime."
NOT_TESTED_radarr="Searching real/private indexers; RSS sync; upgrades of existing files (existing titles are added unmonitored on purpose)."
NOT_TESTED_prowlarr="Real/private trackers and accounts (the installer ships no indexers; a local Torznab feed stood in); Internet Archive as a public source - archive.org throttles Prowlarr (HTTP 429 / timeouts) while plain requests work, an external limit, so it was taken out of the test; FlareSolverr against a real Cloudflare-protected site; usenet indexers."
NOT_TESTED_bazarr="OpenSubtitles.com (needs the user's own account); series subtitles; subtitle sync/translation."
NOT_TESTED_qbittorrent="Downloads from a public swarm (a local web seed stood in); the VPN (gluetun) with a real provider; Transmission/Deluge end to end."
NOT_TESTED_plugin="Season grabs through the plugin; the import of an episode grabbed through the plugin (the same release after a delete is Sonarr 4's known limit); force-grab of a soft-rejected release; real adult indexers; deleting a season and the file_mismatch refusal end to end (unit tests cover the file-name check); the public app itself calling these routes (routes and rules are covered by tests/e2e-plugin.sh and here)."
NOT_TESTED_moonfin="Request status updates shown in the TV app (the webhook delivery itself is proven by tests/e2e-wiring.sh)."
{
  echo "# Tortugarr acceptance test - $(date -u '+%F %H:%M UTC')"
  echo
  echo "Installer: $(jq -r .tortugarr_version $I/state.json) on $(. /etc/os-release; echo "$PRETTY_NAME"), clean machine. Failures: **$FAILS**."
  echo
  echo "| Service | Proven | Notes / not proven | Not tested |"
  echo "|---|---|---|---|"
  for svc in jellyfin seerr sonarr radarr prowlarr bazarr qbittorrent moonfin plugin; do
    nt="NOT_TESTED_$svc"
    printf '| %s | %s | %s | %s |\n' "$svc" "$(printf '%s' "${PROVEN[$svc]:-}" | sed 's/^- //' | paste -sd ';' - | sed 's/;/<br>/g')" \
      "$(printf '%s' "${NOTE[$svc]:-}" | sed 's/^- //' | paste -sd ';' - | sed 's/;/<br>/g')" "${!nt}"
  done
} > "$REPORT"
cat "$REPORT"
# The test indexer and web seed stay up, so the lab can be used from the app afterwards
# (Download Now on the test titles); a lab reset removes them.
docker update --restart unless-stopped tortugarr-test-seed tortugarr-test-indexer >/dev/null 2>&1
rm -f "$JAR" "${QJAR:-}"
exit "$FAILS"
