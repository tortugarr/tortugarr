#!/bin/bash
# E2E: Radarr -> qBittorrent -> hardlink import -> Jellyfin, with a freely licensed
# torrent (Big Buck Bunny, CC-BY, the WebTorrent demo torrent with a web seed).
S=/opt/tortugarr/secrets.json
RK=$(jq -r .radarr_api_key $S); JK=$(jq -r .jellyfin_api_key $S)
net() { docker run --rm --network tortugarr curlimages/curl -s "$@"; }
MAG='magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=wss%3A%2F%2Ftracker.webtorrent.dev&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F'
BODY=$(jq -nc --arg m "$MAG" '{title:"Big.Buck.Bunny.2008.1080p.WEB-DL.AAC.x264-TORTUGARRTEST", magnetUrl:$m, protocol:"torrent", publishDate:"2026-09-01T00:00:00Z", size:276445467}')
net -H "X-Api-Key: $RK" -H 'Content-Type: application/json' -d "$BODY" http://radarr:7878/api/v3/release/push | jq -c '.[0] // . | {approved, rejections}'
for i in $(seq 1 60); do
  Q=$(net -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/queue?pageSize=10" | jq -c '.records[0] // empty | {status, trackedDownloadState, sizeleft, msg:[.statusMessages[]?.messages[]?]}')
  F=$(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq -r '.[0].movieFile.path // empty')
  echo "$(date +%T) queue=$Q file=$F"
  [ -n "$F" ] && break
  # This test file's name cannot be parsed, so Radarr waits for a manual import
  # (e2e-manual-import.sh) - no point waiting the full 20 minutes for it.
  grep -q '"trackedDownloadState":"importPending"' <<< "$Q" && { echo "download done, waiting for manual import"; break; }
  sleep 20
done
echo "--- files on disk"; find /srv/tortugarr/media /srv/tortugarr/torrents -type f -printf '%n links  %s  %p\n' 2>/dev/null
echo "--- jellyfin"
net -X POST -H "Authorization: MediaBrowser Token=\"$JK\"" http://jellyfin:8096/Library/Refresh >/dev/null; sleep 20
net -H "Authorization: MediaBrowser Token=\"$JK\"" "http://jellyfin:8096/Items?Recursive=true&IncludeItemTypes=Movie&Fields=Path" | jq -c '.Items[] | {Name, ProductionYear, Path}'
