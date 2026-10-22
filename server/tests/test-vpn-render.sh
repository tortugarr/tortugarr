#!/bin/bash
# Render the VPN (gluetun) override for every torrent client and let Compose validate
# it, without starting anything. A real VPN connection needs real provider details.
# Runs from the checkout and needs no installation: an existing one is borrowed when there
# is one, otherwise a minimal made-up install (placeholder login, no real secrets) is used.
set -u
APP=$(cd "$(dirname "$0")/.." && pwd)
export TORTUGARR_APP=$APP
. "$APP/lib/common.sh"; . "$APP/lib/detect.sh"; . "$APP/lib/docker.sh"; . "$APP/lib/stack.sh"; . "$APP/lib/external_client.sh"
load_language en
INSTALL_DIR=$(mktemp -d); TORTUGARR_LOG=/dev/null
if [ -f /opt/tortugarr/state.json ]; then
  cp /opt/tortugarr/state.json /opt/tortugarr/secrets.json "$INSTALL_DIR/"
else
  jq -n --arg dir "$INSTALL_DIR" '{install_dir: $dir, config_dir: ($dir + "/config"),
    data_dir: ($dir + "/data"), puid: "1000", pgid: "1000", tz: "UTC",
    lan_ip: "127.0.0.1", bind_ip: "127.0.0.1", torrent_client: "qbittorrent",
    usenet: false, vpn: true, hwaccel: "none", platform: "linux", language: "en",
    ports: {jellyfin: 8096, seerr: 5055, sonarr: 8989, radarr: 7878, prowlarr: 9696,
      torrent_web: 8080, torrent_peer: 6881, sabnzbd: 8085, bazarr: 6767}}' > "$INSTALL_DIR/state.json"
  printf '{"admin_user":"test","admin_password":"test"}\n' > "$INSTALL_DIR/secrets.json"
fi
cp "$APP/compose/compose.yml" "$INSTALL_DIR/"
load_state
fail=0
mkdir -p "$INSTALL_DIR/overrides"
printf 'VPN_SERVICE_PROVIDER=mullvad\nVPN_TYPE=wireguard\nWIREGUARD_PRIVATE_KEY=test\n' > "$INSTALL_DIR/overrides/vpn.env"
VPN=true
for c in qbittorrent transmission deluge; do
  TORRENT_CLIENT=$c
  write_overrides; write_env
  if out=$(cd "$INSTALL_DIR" && docker compose config 2>&1); then
    nm=$(printf '%s\n' "$out" | awk -v s="  $c:" '$0==s{f=1;next} f&&/^  [a-z]/{f=0} f&&/network_mode/{print $2}')
    ports=$(printf '%s\n' "$out" | awk -v s="  $c:" '$0==s{f=1;next} f&&/^  [a-z]/{f=0} f&&/published:/{n++} END{print n+0}')
    echo "$c: valid, network_mode=$nm, own published ports=$ports"
  else
    echo "$c: INVALID"; printf '%s\n' "$out" | tail -5; fail=1
  fi
done
rm -rf "$INSTALL_DIR"
exit $fail
