#!/bin/bash
# A VPN of the user's own (provider "custom"): the WireGuard .conf is read into gluetun's
# settings, and an OpenVPN .ovpn is copied next to them. Nothing outside a temporary
# folder is touched, no VPN is started.
#   bash tests/test-vpn-custom.sh
set -u
APP=$(cd "$(dirname "$0")/.." && pwd)
export TORTUGARR_APP=$APP
. "$APP/lib/common.sh"; . "$APP/lib/detect.sh"; . "$APP/lib/vpn.sh"
load_language en
TORTUGARR_LOG=/dev/null; UNATTENDED=1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAILED=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILED=$((FAILED + 1)); fi; }

KEY=$(printf 'a%.0s' {1..43})=
PUB=$(printf 'b%.0s' {1..43})=
cat > "$TMP/wg0.conf" <<CONF
[Interface]
# from the provider's site
PrivateKey = $KEY
Address = 10.2.0.2/32, fd00::2/128
DNS = 10.2.0.1

[Peer]
PublicKey = $PUB
AllowedIPs = 0.0.0.0/0
Endpoint = 185.159.157.1:51820
CONF
env=$(wg_conf_to_env "$TMP/wg0.conf")
check "endpoint read" '[[ $env == *"VPN_ENDPOINT_IP=185.159.157.1"* && $env == *"VPN_ENDPOINT_PORT=51820"* ]]'
check "keys and addresses read" '[[ $env == *"WIREGUARD_PRIVATE_KEY=$KEY"* && $env == *"WIREGUARD_PUBLIC_KEY=$PUB"* && $env == *"WIREGUARD_ADDRESSES=10.2.0.2/32,fd00::2/128"* ]]'
check "no preshared key when the file has none" '[[ $env != *PRESHARED* ]]'

printf '[Interface]\r\nPrivateKey = %s\r\nAddress = 10.0.0.2/32\r\n[Peer]\r\nPublicKey = %s\r\nPresharedKey = %s\r\nEndpoint = 1.2.3.4:443\r\n' "$KEY" "$PUB" "$KEY" > "$TMP/win.conf"
env=$(wg_conf_to_env "$TMP/win.conf")
check "a file saved on Windows (CRLF) works, preshared key kept" '[[ $env == *"VPN_ENDPOINT_PORT=443"* && $env == *"WIREGUARD_PRESHARED_KEY=$KEY"* ]]'

printf '[Interface]\nPrivateKey = %s\n' "$KEY" > "$TMP/half.conf"
check "a file without peer is refused" '! wg_conf_to_env "$TMP/half.conf" >/dev/null'

INSTALL_DIR=$TMP/install
printf 'client\nremote vpn.example 1194\n' > "$TMP/my.ovpn"
VPN_PROVIDER=Custom VPN_TYPE=openvpn VPN_OVPN=$TMP/my.ovpn VPN_USER=""
ask_vpn >/dev/null 2>&1
f=$INSTALL_DIR/overrides/vpn.env
check "custom OpenVPN: the .ovpn is copied" 'cmp -s "$TMP/my.ovpn" "$INSTALL_DIR/overrides/custom.ovpn"'
check "custom OpenVPN: gluetun is pointed at it" 'grep -qx "OPENVPN_CUSTOM_CONFIG=/gluetun/custom.ovpn" "$f" && grep -qx "VPN_SERVICE_PROVIDER=custom" "$f"'
check "custom: no server country asked" '! grep -q SERVER_COUNTRIES "$f"'
check "settings only readable by root" '[ "$(stat -c %a "$f")" = 600 ]'

rm -rf "$INSTALL_DIR"
VPN_PROVIDER=custom VPN_TYPE=wireguard VPN_WG_CONF=$TMP/wg0.conf
ask_vpn >/dev/null 2>&1
check "custom WireGuard: settings from the .conf" 'grep -qx "VPN_ENDPOINT_IP=185.159.157.1" "$INSTALL_DIR/overrides/vpn.env" && [ ! -e "$INSTALL_DIR/overrides/custom.ovpn" ]'

rm -rf "$INSTALL_DIR"
VPN_PROVIDER=nordvpn VPN_TYPE=wireguard VPN_WG_KEY=$KEY VPN_WG_ADDR=10.5.0.2/32 VPN_COUNTRIES=Norway
ask_vpn >/dev/null 2>&1
check "a named provider works as before" 'grep -qx "VPN_SERVICE_PROVIDER=nordvpn" "$INSTALL_DIR/overrides/vpn.env" && grep -qx "SERVER_COUNTRIES=Norway" "$INSTALL_DIR/overrides/vpn.env"'

[ $FAILED = 0 ] && echo "all passed" || echo "$FAILED failed"
exit $FAILED
