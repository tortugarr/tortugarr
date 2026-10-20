#!/bin/bash
# E2E: the Tortugarr plugin's routes (docs/design/tortugarr-plugin-api.md) on a fresh install,
# without indexers: who may do what, the asynchronous search, how a title is added, the
# read-only routes, and that no key or password ever comes back. Exit code = failures.
set -u
S=/opt/tortugarr/secrets.json
U=$(jq -r .admin_user $S); P=$(jq -r .admin_password $S); RK=$(jq -r .radarr_api_key $S)
J=http://127.0.0.1:$(jq -r .ports.jellyfin /opt/tortugarr/state.json)
T=$J/Tortugarr/v1
fails=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }
auth() {  # user password -> token
  curl -s -H 'Content-Type: application/json' -H 'Authorization: MediaBrowser Client="e2e", Device="lab", DeviceId="e2e-'"$1"'", Version="1"' \
    -d "$(jq -nc --arg u "$1" --arg p "$2" '{Username:$u, Pw:$p}')" "$J/Users/AuthenticateByName" | jq -r '.AccessToken // empty'
}
call() {  # token method path [body] -> "HTTP-code<TAB>body"
  local tok=$1 m=$2 path=$3 body=${4:-}
  curl -s -o /tmp/e2e-plugin.out -w '%{http_code}' -X "$m" -H "Authorization: MediaBrowser Token=\"$tok\"" \
    ${body:+-H 'Content-Type: application/json' -d "$body"} "$T$path"
  printf '\t'; cat /tmp/e2e-plugin.out
}

ADMIN=$(auth "$U" "$P")
[ -n "$ADMIN" ] && pass "admin logged in to Jellyfin" || { fail "admin login"; exit 1; }

r=$(call "$ADMIN" GET /Capabilities); code=${r%%$'\t'*}; body=${r#*$'\t'}
if [ "$code" = 200 ] && [ "$(jq '[.features | del(.adult)[]] | all' <<< "$body")" = true ] && [ "$(jq .isAdmin <<< "$body")" = true ] \
   && [ "$(jq -r '.categories.movies + "/" + .categories.tv' <<< "$body")" = radarr/sonarr ]; then
  pass "Capabilities: admin gets every feature (adult library aside, off by default), categories radarr/sonarr"
else fail "Capabilities for admin: $code $body"; fi

# A non-admin user (made here, test machine only).
NU=e2e-viewer; NP='Viewer-pass-123'
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg n "$NU" --arg p "$NP" '{Name:$n, Password:$p}')" "$J/Users/New"
VIEWER=$(auth "$NU" "$NP")
r=$(call "$VIEWER" GET /Capabilities); body=${r#*$'\t'}
[ "$(jq '[.features[]] | any' <<< "$body")" = false ] && [ "$(jq .isAdmin <<< "$body")" = false ] \
  && pass "Capabilities: a non-admin gets every feature off" || fail "Capabilities for non-admin: $body"
r=$(call "$VIEWER" POST /Searches '{"type":"movie","tmdbId":10378}'); code=${r%%$'\t'*}
[ "$code" = 403 ] && pass "a non-admin cannot search (403)" || fail "non-admin search answered $code"
r=$(call "$VIEWER" GET /Downloads); code=${r%%$'\t'*}
[ "$code" = 403 ] && pass "a non-admin cannot see downloads (403)" || fail "non-admin downloads answered $code"
code=$(curl -s -o /dev/null -w '%{http_code}' "$T/Capabilities")
[ "$code" = 401 ] && pass "no session: 401" || fail "no session answered $code"

r=$(call "$ADMIN" POST /Searches '{"type":"movie"}'); code=${r%%$'\t'*}; body=${r#*$'\t'}
[ "$code" = 400 ] && [ "$(jq -r .error.code <<< "$body")" = bad_request ] && pass "a search without an id: 400 bad_request" || fail "bad search answered $code $body"

# Asynchronous search for a title no other test uses, so it is not in Radarr yet.
TM=$(curl -s -H "X-Api-Key: $RK" "http://127.0.0.1:7878/api/v3/movie/lookup?term=Cosmos%20Laundromat" | jq -r '[.[] | select(.year == 2015)][0].tmdbId // empty')
[ -n "$TM" ] || { fail "test title not found in Radarr's lookup"; TM=0; }
r=$(call "$ADMIN" POST /Searches "{\"type\":\"movie\",\"tmdbId\":$TM}"); code=${r%%$'\t'*}; body=${r#*$'\t'}
SID=$(jq -r '.searchId // empty' <<< "$body")
[ "$code" = 202 ] && [ -n "$SID" ] && pass "search started (202, searchId)" || fail "search start: $code $body"
r=$(call "$ADMIN" POST /Searches "{\"type\":\"movie\",\"tmdbId\":$TM}"); body=${r#*$'\t'}
[ "$(jq -r .searchId <<< "$body")" = "$SID" ] && pass "the same search again returns the running job" || echo "INFO  the first search had already finished, so a new one started"
st=running
for i in $(seq 1 90); do
  r=$(call "$ADMIN" GET "/Searches/$SID"); body=${r#*$'\t'}; st=$(jq -r .status <<< "$body")
  [ "$st" != running ] && break; sleep 2
done
# A fresh install has no indexers: the search must say so (spec 3.2), not "0 releases".
if [ "$st" = failed ] && [ "$(jq -r .error.code <<< "$body")" = no_indexers ]; then
  pass "search without indexers ends as failed/no_indexers: $(jq -r .error.message <<< "$body")"
else fail "search without indexers ended as $st: $(head -c 300 <<< "$body")"; fi
m=$(curl -s -H "X-Api-Key: $RK" "http://127.0.0.1:7878/api/v3/movie?tmdbId=$TM" | jq -c '.[0] | {title, monitored, hasFile}')
[ "$(jq .monitored <<< "$m")" = true ] && pass "the movie was added to Radarr monitored (as the app does): $m" || fail "movie in Radarr: $m"
code=$(call "$ADMIN" GET /Searches/nope | cut -f1)
[ "$code" = 404 ] && pass "an unknown searchId: 404" || fail "unknown searchId answered $code"

r=$(call "$ADMIN" POST /Grab "{\"type\":\"movie\",\"arrId\":1,\"guid\":\"x\",\"indexerId\":1}"); code=${r%%$'\t'*}
[ "$code" = 409 ] && pass "grabbing a release that was never shown: 409 search_expired" || fail "grab of unknown release answered $code"

r=$(call "$ADMIN" GET /Downloads); code=${r%%$'\t'*}; body=${r#*$'\t'}
[ "$code" = 200 ] && [ "$(jq '.items | type' <<< "$body")" = '"array"' ] && pass "Downloads answers (items: $(jq '.items | length' <<< "$body"))" || fail "Downloads: $code $body"
r=$(call "$ADMIN" GET /Space); code=${r%%$'\t'*}; body=${r#*$'\t'}
[ "$code" = 200 ] && [ "$(jq '.freeBytes > 0' <<< "$body")" = true ] && pass "Space: $(jq -c . <<< "$body")" || fail "Space: $code $body"
r=$(call "$ADMIN" DELETE /Downloads/NOPE); code=${r%%$'\t'*}
[ "$code" = 404 ] && pass "removing an unknown download: 404" || fail "remove unknown answered $code"

# ---- Adult library (spec 3.9): off by default, then switched on as the admin page does.
GUID=19f30fb1bb78444ba75e2997883b215c
# The installed Tortugarr plugin version (dist/Tortugarr_<version>), so the checks below follow a bump.
PVER=$(ls -d "$(dirname "$0")"/../plugin/dist/Tortugarr_* 2>/dev/null | sed -n 's:.*/Tortugarr_::p' | head -1)
PVER=${PVER:-1.2.1.0}
r=$(call "$ADMIN" GET /Capabilities); body=${r#*$'\t'}
[ "$(jq .features.adult <<< "$body")" = false ] && pass "adult library: off by default" || fail "adult flag by default: $body"
r=$(call "$ADMIN" POST /Adult/Searches '{"query":"anything"}'); code=${r%%$'\t'*}; body=${r#*$'\t'}
[ "$code" = 403 ] && [ "$(jq -r .error.code <<< "$body")" = feature_off ] && pass "adult search while off: 403 feature_off" || fail "adult search while off: $code $body"
conf=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Plugins/$GUID/Configuration")
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' \
  -d "$(jq -c '.AdultEnabled = true' <<< "$conf")" "$J/Plugins/$GUID/Configuration"
r=$(call "$ADMIN" GET /Capabilities); body=${r#*$'\t'}
[ "$(jq .features.adult <<< "$body")" = true ] && pass "adult library switched on: Capabilities says adult" || fail "adult flag after switching on: $body"
lib=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Library/VirtualFolders" | jq -c '[.[] | select(.Locations | index("/data/media/adult"))][0] // empty')
LIBID=$(jq -r '.ItemId // empty' <<< "$lib")
[ -n "$LIBID" ] && pass "its own Jellyfin library exists on /data/media/adult ($(jq -r .Name <<< "$lib"))" || fail "adult library not created"
vid=$(curl -s -H "Authorization: MediaBrowser Token=\"$VIEWER\"" "$J/Users/Me" | jq -r .Id)
vp=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Users/$vid" | jq -c '.Policy | {EnableAllFolders, EnabledFolders}')
[ "$(jq .EnableAllFolders <<< "$vp")" = false ] && [ "$(jq --arg l "$LIBID" '.EnabledFolders | index($l) == null' <<< "$vp")" = true ] \
  && pass "an existing non-admin cannot see the adult library" || fail "existing non-admin policy: $vp"
views=$(curl -s -H "Authorization: MediaBrowser Token=\"$VIEWER\"" "$J/UserViews?userId=$vid" | jq -c '[.Items[].Name]')
[ "$(jq --arg l "$LIBID" 'index("Adult") == null' <<< "$views")" = true ] && pass "the non-admin's library list: $views" || fail "non-admin sees: $views"
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' \
  -d '{"Name":"e2e-later","Password":"Later-pass-123"}' "$J/Users/New"
LATER=$(auth e2e-later Later-pass-123); lid=$(curl -s -H "Authorization: MediaBrowser Token=\"$LATER\"" "$J/Users/Me" | jq -r .Id)
lp=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Users/$lid" | jq -c '.Policy | {EnableAllFolders, EnabledFolders}')
[ "$(jq .EnableAllFolders <<< "$lp")" = false ] && [ "$(jq --arg l "$LIBID" '.EnabledFolders | index($l) == null' <<< "$lp")" = true ] \
  && pass "a user created after switching on cannot see it either" || fail "new user policy: $lp"
r=$(call "$VIEWER" GET /Capabilities); body=${r#*$'\t'}
[ "$(jq .features.adult <<< "$body")" = false ] && pass "Capabilities: adult stays off for a non-admin after switching on" || fail "non-admin adult flag after switching on: $body"
managed=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Plugins/$GUID/Configuration" | jq -c '.ManagedUserIds')
[ "$(jq --arg a "${vid//-/}" --arg b "${lid//-/}" 'index($a) != null and index($b) != null' <<< "$managed")" = true ] \
  && pass "the plugin keeps its own list of converted users (existing and new user both in it)" || fail "converted-user list: $managed (want ${vid//-/} and ${lid//-/})"
# An administrator who hid the adult library for himself in the app: "all except adult".
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' \
  -d '{"Name":"e2e-admin2","Password":"Admin2-pass-123"}' "$J/Users/New"
aid=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Users" | jq -r '.[] | select(.Name == "e2e-admin2") | .Id')
ordinary=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Library/VirtualFolders" | jq -c --arg l "$LIBID" '[.[] | .ItemId | select(. != $l)]')
curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Users/$aid" | jq --argjson f "$ordinary" '.Policy | .IsAdministrator = true | .EnableAllFolders = false | .EnabledFolders = $f' > /tmp/e2e-admin2.json
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' -d @/tmp/e2e-admin2.json "$J/Users/$aid/Policy"
# A new ordinary library, made after the adult library: must become visible to both, at once (event).
DATA=$(jq -r .data_dir /opt/tortugarr/state.json); mkdir -p "$DATA/media/e2e-extra"; chown "$(jq -r .puid /opt/tortugarr/state.json):$(jq -r .pgid /opt/tortugarr/state.json)" "$DATA/media/e2e-extra"
curl -s -o /dev/null -X POST -H "Authorization: MediaBrowser Token=\"$ADMIN\"" -H 'Content-Type: application/json' \
  -d '{"LibraryOptions":{"PathInfos":[{"Path":"/data/media/e2e-extra"}]}}' "$J/Library/VirtualFolders?name=E2E%20Extra&collectionType=movies&refreshLibrary=true"
# Jellyfin lists the new library (with its id) only a moment later - on a slow machine seconds
# (round 23 read it at once and got nothing). Known trap: wait for it.
XID=""
for i in $(seq 1 30); do
  XID=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Library/VirtualFolders" | jq -r '[.[] | select(.Name == "E2E Extra")][0].ItemId // empty')
  [ -n "$XID" ] && break
  sleep 2
done
[ -n "$XID" ] && pass "a new ordinary library was made after the adult library" || fail "could not make the extra library"
for who in "$vid" "$lid" "$aid"; do
  ok=""
  for i in $(seq 1 30); do
    pol=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Users/$who" | jq -c '.Policy.EnabledFolders')
    [ "$(jq --arg x "$XID" --arg l "$LIBID" 'index($x) != null and index($l) == null' <<< "$pol")" = true ] && { ok=$i; break; }
    sleep 2
  done
  [ -n "$ok" ] && pass "user ${who:0:8}: the new library is visible within $((ok * 2)) s, the adult library still hidden" \
    || fail "user ${who:0:8}: new library not added (folders: $pol)"
done
xviews=$(curl -s -H "Authorization: MediaBrowser Token=\"$LATER\"" "$J/UserViews?userId=$lid" | jq -c '[.Items[].Name]')
[ "$(jq 'index("E2E Extra") != null and index("Adult") == null' <<< "$xviews")" = true ] && pass "the later user's library list: $xviews" || fail "later user sees: $xviews"
aviews=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/UserViews" | jq -c '[.Items[].Name]')
[ "$(jq 'index("Adult") != null' <<< "$aviews")" = true ] && pass "the administrator sees it: $aviews" || fail "admin views: $aviews"
r=$(call "$VIEWER" POST /Adult/Searches '{"query":"anything"}'); code=${r%%$'\t'*}
[ "$code" = 403 ] && pass "a non-admin cannot use the adult routes (403)" || fail "non-admin adult search answered $code"
r=$(call "$ADMIN" POST /Adult/Searches '{"query":"anything at all"}'); body=${r#*$'\t'}; asid=$(jq -r '.searchId // empty' <<< "$body")
for i in $(seq 1 60); do r=$(call "$ADMIN" GET "/Adult/Searches/$asid"); body=${r#*$'\t'}; [ "$(jq -r .status <<< "$body")" != running ] && break; sleep 2; done
[ "$(jq -r .status <<< "$body")" = failed ] && [ "$(jq -r .error.code <<< "$body")" = no_indexers ] \
  && pass "adult search without indexers ends as failed/no_indexers: $(jq -r .error.message <<< "$body")" || fail "adult search: $(head -c 300 <<< "$body")"

# 3.10 delete route: who may call it, and what it refuses (no titles on a fresh install).
r=$(call "$ADMIN" GET /Capabilities); [ "$(jq .features.deleteTitles <<< "${r#*$'\t'}")" = true ] && pass "Capabilities: deleteTitles on for the admin" || fail "deleteTitles not on for the admin"
for route in "GET /Series/170551" "GET /Space/Candidates" "GET /Space/Check?bytes=1" "GET /Subtitles/State?type=movie&tmdbId=1"; do
  r=$(call "$VIEWER" ${route%% *} "${route#* }"); [ "${r%%$'\t'*}" = 403 ] && pass "non-admin: ${route} is 403" || fail "non-admin ${route} answered ${r%%$'\t'*}"
done
r=$(call "$VIEWER" DELETE "/Library/$XID"); [ "${r%%$'\t'*}" = 403 ] && pass "a non-admin cannot delete titles (403)" || fail "non-admin delete answered ${r%%$'\t'*}"
r=$(call "$ADMIN" DELETE /Library/00000000000000000000000000000001); [ "${r%%$'\t'*}" = 404 ] && pass "deleting an unknown item: 404" || fail "unknown item delete answered ${r%%$'\t'*}"
r=$(call "$ADMIN" DELETE "/Library/$XID"); [ "${r%%$'\t'*}" = 400 ] && pass "a library folder cannot be deleted: 400" || fail "library folder delete answered ${r%%$'\t'*}"
conf=$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Plugins/$GUID/Configuration")
[ "$(jq -r .SeerrUrl <<< "$conf")" = http://seerr:5055 ] && [ -n "$(jq -r '.SeerrApiKey // empty' <<< "$conf")" ] \
  && pass "the installer linked the plugin to Seerr (address and key in the plugin configuration)" || fail "plugin not linked to Seerr"
SEERR_KEY=$(jq -r .main.apiKey /opt/tortugarr/config/seerr/settings.json 2>/dev/null)

# 3.12 the refresh hook opens only with the installer's shared key, not with a Jellyfin session.
HK=$(jq -r .tortugarr_hook_key $S)
hk() { curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' "$@" -d '{"eventType":"Test"}' "$T/Hooks/Arr"; }
[ "$(hk)" = 401 ] && pass "refresh hook without a key: 401" || fail "refresh hook without a key answered $(hk)"
[ "$(hk -H 'X-Tortugarr-Hook-Key: wrong')" = 401 ] && pass "refresh hook with a wrong key: 401" || fail "refresh hook with a wrong key was not refused"
[ "$(hk -H "Authorization: MediaBrowser Token=\"$ADMIN\"")" = 401 ] && pass "refresh hook with only a Jellyfin admin session: 401 (the shared key is required)" || fail "refresh hook accepted a Jellyfin session without the key"
[ "$(hk -H "X-Tortugarr-Hook-Key: $HK")" = 204 ] && pass "refresh hook with the shared key: 204" || fail "refresh hook with the shared key answered $(hk -H "X-Tortugarr-Hook-Key: $HK")"

# The plugin's picture and a real server name instead of the container id.
[ "$(curl -s -o /dev/null -w '%{http_code}:%{content_type}' -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Plugins/$GUID/$PVER/Image")" = "200:image/png" ] \
  && pass "the plugin has its picture (the parrot logo)" || fail "plugin image: $(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Plugins/$GUID/$PVER/Image")"
sn=$(curl -s "$J/System/Info/Public" | jq -r .ServerName)
[ "$sn" = Tortugarr ] && pass "server name: $sn" || fail "server name is '$sn'"

# 3.13 the plugin's own catalog: the plugin page finds Tortugarr in a repository.
man=$(curl -s "$J/Tortugarr/v1/Repository/manifest.json")
[ "$(curl -s -o /dev/null -w '%{http_code}' "$(jq -r '.[0].imageUrl' <<< "$man" | sed "s#^http://[^/]*#$J#")")" = 200 ] && pass "the catalog shows the logo" || fail "catalog imageUrl does not answer"
[ "$(jq -r '.[0].versions[0].version' <<< "$man")" = "$PVER" ] && pass "the catalog is served without login and lists the installed version" || fail "catalog: $(head -c 200 <<< "$man")"
curl -s -o /tmp/tortugarr-pkg.zip "$(jq -r '.[0].versions[0].sourceUrl' <<< "$man" | sed "s#^http://[^/]*#$J#")"
[ "$(md5sum /tmp/tortugarr-pkg.zip | cut -d' ' -f1)" = "$(jq -r '.[0].versions[0].checksum' <<< "$man")" ] && pass "the package zip matches the catalog's checksum" || fail "package zip checksum differs"
[ "$(curl -s -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Repositories" | jq 'any(.[]; .Name == "Tortugarr")')" = true ] && pass "the installer registered the Tortugarr catalog in Jellyfin" || fail "no Tortugarr repository in Jellyfin"
pk=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: MediaBrowser Token=\"$ADMIN\"" "$J/Packages/Tortugarr?assemblyGuid=$GUID")
[ "$pk" = 200 ] && pass "Jellyfin finds the plugin in its catalogs (the plugin page shows no repository error)" || fail "/Packages/Tortugarr answered $pk"

# Nothing the plugin answers may contain a key or the password.
all=$(for p in /Capabilities /Downloads /Space "/Searches/$SID" "/Adult/Searches/$asid"; do call "$ADMIN" GET "$p"; echo; done; call "$ADMIN" DELETE "/Library/$XID"; echo "$man")
leak=0
for k in $(jq -r '[.sonarr_api_key, .radarr_api_key, .prowlarr_api_key, .bazarr_api_key, .admin_password, .tortugarr_hook_key] | .[]' $S) $SEERR_KEY; do
  grep -qF -- "$k" <<< "$all" && leak=1
done
[ $leak = 0 ] && pass "no key or password in any answer" || fail "a key or the password came back in an answer"
rm -f /tmp/e2e-plugin.out
echo "plugin checks failed: $fails"
exit "$fails"
