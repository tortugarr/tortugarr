#!/bin/bash
# E2E: a request made in Seerr (as the app does) lands in Radarr with the right profile/root.
set -e
S=/opt/tortugarr/secrets.json
U=$(jq -r .admin_user $S); P=$(jq -r .admin_password $S); RK=$(jq -r .radarr_api_key $S)

net() { docker run --rm --network tortugarr curlimages/curl -s "$@"; }
# Log in to Seerr and request Big Buck Bunny (TMDB 10378, public domain).
COOKIE=$(docker run --rm --network tortugarr curlimages/curl -s -i -H 'Content-Type: application/json' \
  -d "{\"username\":\"$U\",\"password\":\"$P\"}" http://seerr:5055/api/v1/auth/jellyfin | grep -i '^set-cookie' | sed 's/^[Ss]et-[Cc]ookie: //; s/;.*//' | tr -d '\r')
echo "seerr login cookie: ${COOKIE:0:20}..."
net -H "Cookie: $COOKIE" -H 'Content-Type: application/json' -d '{"mediaType":"movie","mediaId":10378}' http://seerr:5055/api/v1/request | jq -c '{id, status, media: .media.tmdbId}'
sleep 8
net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq -c '.[] | {title, tmdbId, qualityProfileId, rootFolderPath, monitored}'
