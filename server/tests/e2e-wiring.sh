#!/bin/bash
# E2E: every connection the installer wires up is really there, read back from each
# service's own API. Prints one PASS/FAIL line per check; exit code = number of failures.
set -u
S=/opt/tortugarr/secrets.json
RK=$(jq -r .radarr_api_key $S); SK=$(jq -r .sonarr_api_key $S); PK=$(jq -r .prowlarr_api_key $S)
BK=$(jq -r .bazarr_api_key $S); JK=$(jq -r .jellyfin_api_key $S)
U=$(jq -r .admin_user $S); P=$(jq -r .admin_password $S)
GUID=$(jq -r .moonfin_plugin_guid /opt/tortugarr/state.json | tr -d -)
net() { docker run --rm --network tortugarr curlimages/curl -s "$@"; }
fails=0
check() {  # description, then a command whose output must be "true"
  local what=$1; shift
  local got; got=$("$@" 2>&1 | tail -1)
  if [ "$got" = true ]; then echo "PASS  $what"; else echo "FAIL  $what (got: ${got:0:200})"; fails=$((fails + 1)); fi
}

check "prowlarr syncs to sonarr and radarr" bash -c \
  "$(declare -f net); net -H 'X-Api-Key: $PK' http://prowlarr:9696/api/v1/applications | jq '[.[].implementation] | (index(\"Sonarr\") != null) and (index(\"Radarr\") != null)'"
for app in sonarr radarr; do
  key=$SK; port=8989; [ $app = radarr ] && { key=$RK; port=7878; }
  check "$app has a download client" bash -c \
    "$(declare -f net); net -H 'X-Api-Key: $key' http://$app:$port/api/v3/downloadclient | jq 'length > 0'"
  check "$app uses download category '$app' (what the app looks for)" bash -c \
    "$(declare -f net); net -H 'X-Api-Key: $key' http://$app:$port/api/v3/downloadclient | jq 'all(.[]; [.fields[] | select(.name | test(\"Category\$\")) | .value] | index(\"$app\") != null)'"
  check "$app refreshes only the changed folder in Jellyfin on import (webhook to the Tortugarr plugin with the shared hook key, no Jellyfin key)" bash -c \
    "$(declare -f net); net -H 'X-Api-Key: $key' http://$app:$port/api/v3/notification | jq 'any(.[]; .implementation == \"Webhook\" and .onDownload and (.fields[] | select(.name == \"url\") | .value) == \"http://jellyfin:8096/Tortugarr/v1/Hooks/Arr\" and ([.fields[] | select(.name == \"headers\") | .value[] | .key] | index(\"X-Tortugarr-Hook-Key\") != null) and ([.fields[] | select(.name == \"headers\") | .value[] | .value | strings | test(\"MediaBrowser\")] | any | not))'"
  check "$app does not re-download deleted files" bash -c \
    "$(declare -f net); net -H 'X-Api-Key: $key' http://$app:$port/api/v3/config/mediamanagement | jq '(.autoUnmonitorPreviouslyDownloadedEpisodes // .autoUnmonitorPreviouslyDownloadedMovies) == true'"
done
check "bazarr is linked to sonarr and radarr" bash -c \
  "$(declare -f net); net -H 'X-API-KEY: $BK' http://bazarr:6767/api/system/settings | jq '.general.use_sonarr and .general.use_radarr and .sonarr.ip == \"sonarr\" and .radarr.ip == \"radarr\"'"
check "bazarr has a default language profile" bash -c \
  "$(declare -f net); net -H 'X-API-KEY: $BK' http://bazarr:6767/api/system/settings | jq '.general.serie_default_enabled and .general.movie_default_enabled and (.general.enabled_providers | length) > 0'"
check "moonfin plugin: Seerr on, public URL for Seerr, push relay off" bash -c \
  "$(declare -f net); net -H 'Authorization: MediaBrowser Token=\"$JK\"' http://jellyfin:8096/Plugins/$GUID/Configuration | jq '.SeerrEnabled and .PublicServerUrl == \"http://jellyfin:8096\" and (.PushRelayUrl // \"\") == \"\"'"
COOKIE=$(docker run --rm --network tortugarr curlimages/curl -s -i -H 'Content-Type: application/json' \
  -d "{\"username\":\"$U\",\"password\":\"$P\"}" http://seerr:5055/api/v1/auth/jellyfin | grep -i '^set-cookie' | sed 's/^[Ss]et-[Cc]ookie: //; s/;.*//' | tr -d '\r')
check "seerr sends request updates to the moonfin plugin" bash -c \
  "$(declare -f net); net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/notifications/webhook | jq '.enabled and (.options.webhookUrl | startswith(\"http://jellyfin:8096/Moonfin/Seerr/Webhook?secret=\")) and ((.types / 2 | floor) % 2 == 1) and ((.types / 8 | floor) % 2 == 1)'"
check "seerr webhook reaches the plugin (test notification accepted)" bash -c \
  "$(declare -f net); net -o /dev/null -w '%{http_code}' -X POST -H 'Cookie: $COOKIE' -H 'Content-Type: application/json' -d \"\$(net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/notifications/webhook)\" http://seerr:5055/api/v1/settings/notifications/webhook/test | grep -qE '^(200|204)$' && echo true"
check "seerr: anime metadata from TVDB, API timeout 30 s" bash -c \
  "$(declare -f net); [ \"\$(net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/metadatas | jq -r .anime)\" = tvdb ] && net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/network | jq '.apiRequestTimeout == 30000'"
check "jellyfin libraries make chapter images (in the nightly task, not during scans)" bash -c \
  "$(declare -f net); net -H 'Authorization: MediaBrowser Token=\"$JK\"' http://jellyfin:8096/Library/VirtualFolders | jq 'length > 0 and all(.[] | select(.CollectionType == \"movies\" or .CollectionType == \"tvshows\"); .LibraryOptions.EnableChapterImageExtraction and (.LibraryOptions.ExtractChapterImagesDuringLibraryScan | not))'"
check "jellyfin movie library adds films of one series to a collection" bash -c \
  "$(declare -f net); net -H 'Authorization: MediaBrowser Token=\"$JK\"' http://jellyfin:8096/Library/VirtualFolders | jq 'any(.[]; .CollectionType == \"movies\" and .LibraryOptions.AutomaticallyAddToCollection)'"
check "seerr is linked to radarr and sonarr" bash -c \
  "$(declare -f net); [ \"\$(net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/radarr | jq length)\" -gt 0 ] && [ \"\$(net -H 'Cookie: $COOKIE' http://seerr:5055/api/v1/settings/sonarr | jq length)\" -gt 0 ] && echo true"
echo "wiring checks failed: $fails"
exit "$fails"
