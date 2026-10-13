#!/bin/bash
# Render the VPN (gluetun) override for every torrent client and let Compose validate
# it, without starting anything. A real VPN connection needs real provider details.
set -u
APP=/opt/tortugarr/app
export TORTUGARR_APP=$APP
. $APP/lib/common.sh; . $APP/lib/detect.sh; . $APP/lib/docker.sh; . $APP/lib/stack.sh
load_language en
INSTALL_DIR=$(mktemp -d); TORTUGARR_LOG=/dev/null
cp /opt/tortugarr/state.json /opt/tortugarr/secrets.json "$INSTALL_DIR/"
cp $APP/compose/compose.yml "$INSTALL_DIR/"
load_state
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
    echo "$c: INVALID"; printf '%s\n' "$out" | tail -5
  fi
done
rm -rf "$INSTALL_DIR"
