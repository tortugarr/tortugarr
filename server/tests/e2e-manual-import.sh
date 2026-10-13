#!/bin/bash
# E2E part 2: import the finished download (as "Manual Import" in Radarr does),
# then check the library file is a hardlink and that Jellyfin lists the movie.
S=/opt/tortugarr/secrets.json; RK=$(jq -r .radarr_api_key $S); JK=$(jq -r .jellyfin_api_key $S)
net() { docker run --rm --network tortugarr curlimages/curl -s "$@"; }
MID=$(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq '.[0].id')
DL=$(net -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/queue?pageSize=5" | jq -r '.records[0].downloadId')
FOLDER=$(jq -rn --arg p "$(net -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/queue?pageSize=5" | jq -r '.records[0].outputPath')" '$p|@uri')
FILES=$(net -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/manualimport?folder=$FOLDER&downloadId=$DL&filterExistingFiles=true" \
  | jq -c --argjson m "$MID" --arg dl "$DL" '[.[] | select(.path|endswith(".mp4")) | {path, movieId:$m, quality, languages, releaseGroup:"TORTUGARRTEST", downloadId:$dl}]')
echo "files: $(jq length <<< "$FILES")"
net -H "X-Api-Key: $RK" -H 'Content-Type: application/json' -d "{\"name\":\"ManualImport\",\"files\":$FILES,\"importMode\":\"auto\"}" http://radarr:7878/api/v3/command | jq -c '{name, status}'
sleep 15
echo "--- library file and link count (2 = hardlink shared with the download)"
find /srv/tortugarr/media -type f -printf '%n links  %s bytes  %p\n'
net -X POST -H "Authorization: MediaBrowser Token=\"$JK\"" http://jellyfin:8096/Library/Refresh >/dev/null; sleep 25
echo "--- jellyfin"
net -H "Authorization: MediaBrowser Token=\"$JK\"" "http://jellyfin:8096/Items?Recursive=true&IncludeItemTypes=Movie&Fields=Path" | jq -c '.Items[] | {Name, ProductionYear, Path}'
