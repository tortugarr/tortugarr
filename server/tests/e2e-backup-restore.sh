#!/bin/bash
# E2E: backup -> damage a setting -> restore -> the setting is back and everything is healthy.
set -u
S=/opt/tortugarr/secrets.json; RK=$(jq -r .radarr_api_key $S)
net() { docker run --rm --network tortugarr curlimages/curl -s "$@"; }
rootfolders() { net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/rootfolder | jq -c '[.[].path]'; }

echo "before: radarr root folders $(rootfolders), movies $(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq length)"
tortugarr backup --yes 2>&1 | grep -E 'ok|xx|!!'
B=$(ls -1t /opt/tortugarr/backups/tortugarr-backup-*.tar.gz | head -1)
echo "backup: $B ($(du -h "$B" | cut -f1)), contents:"
tar -tzf "$B" | awk -F/ 'NF>1{print $2}' | sort -u | tr '\n' ' '; echo

# Damage: delete the movie and the root folder in Radarr.
MID=$(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq '.[0].id')
net -X DELETE -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/movie/$MID?deleteFiles=false" >/dev/null
RID=$(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/rootfolder | jq '.[0].id')
net -X DELETE -H "X-Api-Key: $RK" "http://radarr:7878/api/v3/rootfolder/$RID" >/dev/null
echo "damaged: radarr root folders $(rootfolders), movies $(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq length)"

GO=y tortugarr restore "$B" --yes 2>&1 | grep -E '^(==|  ok|  xx|  !!)' | tail -30
echo "after: radarr root folders $(rootfolders), movies $(net -H "X-Api-Key: $RK" http://radarr:7878/api/v3/movie | jq length)"
ls -d /opt/tortugarr/config.pre-restore-* 2>/dev/null
