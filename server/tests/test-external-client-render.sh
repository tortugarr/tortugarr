#!/bin/bash
# The qBittorrent-outside-the-stack choice (TORRENT_CLIENT=qbittorrent-ext): render the stack
# from the repository with a made-up install and let Compose validate it, without starting
# anything. Checks that no qBittorrent container is started, that Radarr and Sonarr get the
# client's download folder, and that no torrent ports are published for it.
#   bash tests/test-external-client-render.sh
set -u
APP=$(cd "$(dirname "$0")/.." && pwd)
export TORTUGARR_APP=$APP
. "$APP/lib/common.sh"; . "$APP/lib/detect.sh"; . "$APP/lib/docker.sh"; . "$APP/lib/stack.sh"; . "$APP/lib/external_client.sh"
load_language en
INSTALL_DIR=$(mktemp -d); TORTUGARR_LOG=/dev/null
trap 'rm -rf "$INSTALL_DIR"' EXIT
mkdir -p "$INSTALL_DIR/overrides"
cp "$APP/compose/compose.yml" "$INSTALL_DIR/"
. "$APP/versions.env"

FAILED=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILED=$((FAILED + 1)); fi; }

CONFIG_DIR=$INSTALL_DIR/config; DATA_DIR=$INSTALL_DIR/data; PUID=1000; PGID=1000; TZ_NAME=UTC
LAN_IP=192.168.1.15; BIND_IP=0.0.0.0; USENET=false; VPN=false; HWACCEL=false; PLATFORM=wsl
P_JELLYFIN=8096; P_SEERR=5055; P_SONARR=8989; P_RADARR=7878; P_PROWLARR=9696; P_BAZARR=6767
P_TORRENT_WEB=8080; P_TORRENT_PEER=6881; P_SABNZBD=8085; EXTRA_LIBS_JSON='[]'
ADMIN_USER=captain; ADMIN_PASSWORD=parrot-1234
TORRENT_CLIENT=qbittorrent-ext
EXT_QBIT_URL=http://192.168.1.15:8070
EXT_QBIT_JSON='{"url":"http://192.168.1.15:8070","username":"","mounts":[{"remote":"H:\\Downloads\\","host_path":"/mnt/h/Downloads","container_path":"/data/torrents-ext/1"}]}'

write_secrets_if_missing; write_overrides; write_env
check "download-client override written" '[ -f "$INSTALL_DIR/overrides/download-client.yml" ]'
check "no torrent client in the Compose profiles" '[[ ",$(compose_profiles)," != *,qbittorrent,* ]]'

if out=$(cd "$INSTALL_DIR" && COMPOSE_PROFILES=$(compose_profiles) docker compose config 2>&1); then
  echo "ok   compose config is valid"
  check "no qBittorrent container" '! grep -q "container_name: tortugarr-qbittorrent" <<< "$out"'
  for s in radarr sonarr; do
    block=$(awk -v s="  $s:" '$0==s{f=1;next} f&&/^  [a-z]/{f=0} f' <<< "$out")
    check "$s mounts the client's download folder" 'grep -q "source: /mnt/h/Downloads" <<< "$block" && grep -q "target: /data/torrents-ext/1" <<< "$block"'
  done
  check "torrent peer port not published" '! grep -q "published: \"6881\"" <<< "$out"'
else
  echo "FAIL compose config"; tail -5 <<< "$out"; FAILED=$((FAILED + 1))
fi

# A client inside the stack still gets its container and no external mounts.
TORRENT_CLIENT=qbittorrent
write_overrides
check "in-stack qBittorrent: no download-client override" '[ ! -f "$INSTALL_DIR/overrides/download-client.yml" ]'
check "in-stack qBittorrent: in the Compose profiles" '[[ ",$(compose_profiles)," == *,qbittorrent,* ]]'

[ $FAILED = 0 ] && echo "all passed" || echo "$FAILED failed"
exit $FAILED
