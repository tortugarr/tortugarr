# VPN settings for gluetun, the VPN client the torrent client runs behind.
# gluetun knows most providers by name (nordvpn, mullvad, protonvpn, surfshark, ...).
# "custom" takes the user's own WireGuard .conf or OpenVPN .ovpn file instead, for a
# provider gluetun does not list or a VPN server of their own.

# A path as typed: Windows paths (C:\Users\...\wg0.conf) work in WSL.
vpn_local_path() {
  local p=$1
  p=${p#\"}; p=${p%\"}
  if is_wsl && [[ $p =~ ^[A-Za-z]:([\\/]|$) ]]; then
    p=$(wslpath -u "$p" 2>/dev/null) || p=""
  fi
  printf '%s' "$p"
}

valid_vpn_file() { local p; p=$(vpn_local_path "$1"); [ -n "$p" ] && [ -f "$p" ] && [ -r "$p" ]; }

# Env lines for gluetun's custom WireGuard from a .conf file, as providers and
# WireGuard servers hand it out. Fails (and prints nothing) when a needed field is
# missing. gluetun wants the endpoint as an IP, so a host name is resolved here.
wg_conf_to_env() {
  local f=$1 key val section="" priv="" addr="" pub="" psk="" endpoint=""
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%%#*}; line=${line//$'\r'/}
    [[ $line =~ ^[[:space:]]*\[([A-Za-z]+)\] ]] && { section=${BASH_REMATCH[1],,}; continue; }
    [[ $line =~ ^[[:space:]]*([A-Za-z]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] || continue
    key=${BASH_REMATCH[1],,}; val=${BASH_REMATCH[2]}
    case "$section:$key" in
      interface:privatekey) priv=$val ;;
      interface:address) addr=${val// /} ;;
      peer:publickey) [ -z "$pub" ] && pub=$val ;;
      peer:presharedkey) [ -z "$psk" ] && psk=$val ;;
      peer:endpoint) [ -z "$endpoint" ] && endpoint=$val ;;
    esac
  done < "$f"
  [ -n "$priv" ] && [ -n "$addr" ] && [ -n "$pub" ] && [ -n "$endpoint" ] || return 1
  local host=${endpoint%:*} port=${endpoint##*:}
  host=${host#[}; host=${host%]}
  [[ $port =~ ^[0-9]+$ ]] || return 1
  if ! [[ $host =~ ^[0-9.]+$ || $host == *:* ]]; then
    host=$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}')
    [ -n "$host" ] || return 1
  fi
  echo "VPN_ENDPOINT_IP=$host"
  echo "VPN_ENDPOINT_PORT=$port"
  echo "WIREGUARD_PUBLIC_KEY=$pub"
  echo "WIREGUARD_PRIVATE_KEY=$priv"
  echo "WIREGUARD_ADDRESSES=$addr"
  [ -n "$psk" ] && echo "WIREGUARD_PRESHARED_KEY=$psk"
  return 0
}

ask_vpn() {
  local f="$INSTALL_DIR/overrides/vpn.env"
  mkdir -p "$INSTALL_DIR/overrides"
  # Settings from an earlier install are kept; ones given in this run may be
  # given again when the questions are gone through a second time.
  if [ -f "$f" ] && [ "${VPN_ENV_THIS_RUN:-0}" != 1 ]; then
    note "$(t vpn_env_exists "$f")"
    return
  fi
  VPN_ENV_THIS_RUN=1
  say "$(t vpn_intro)"
  ask_valid VPN_PROVIDER "$(t q_vpn_provider)" "${VPN_PROVIDER:-}" valid_nonempty value_required
  VPN_PROVIDER=$(tr '[:upper:]' '[:lower:]' <<< "$VPN_PROVIDER")
  choose VPN_TYPE "$(t q_vpn_type)" "${VPN_TYPE:-wireguard}" wireguard WireGuard openvpn OpenVPN
  local body
  {
    echo "# gluetun settings - see https://github.com/qdm12/gluetun-wiki for your provider."
    echo "VPN_SERVICE_PROVIDER=$VPN_PROVIDER"
    echo "VPN_TYPE=$VPN_TYPE"
  } > "$f"
  rm -f "$INSTALL_DIR/overrides/custom.ovpn"
  if [ "$VPN_PROVIDER" = custom ] && [ "$VPN_TYPE" = wireguard ]; then
    while :; do
      ask_valid VPN_WG_CONF "$(t q_vpn_wg_conf)" "${VPN_WG_CONF:-}" valid_vpn_file vpn_file_missing
      if body=$(wg_conf_to_env "$(vpn_local_path "$VPN_WG_CONF")"); then
        echo "$body" >> "$f"; break
      fi
      warning "$(t vpn_wg_conf_invalid)"
      unset VPN_WG_CONF
      [ "${UNATTENDED:-0}" = 1 ] && die "$(t vpn_wg_conf_invalid)"
    done
  elif [ "$VPN_PROVIDER" = custom ]; then
    ask_valid VPN_OVPN "$(t q_vpn_ovpn)" "${VPN_OVPN:-}" valid_vpn_file vpn_file_missing
    cp "$(vpn_local_path "$VPN_OVPN")" "$INSTALL_DIR/overrides/custom.ovpn"
    chmod 600 "$INSTALL_DIR/overrides/custom.ovpn"
    echo "OPENVPN_CUSTOM_CONFIG=/gluetun/custom.ovpn" >> "$f"
    ask VPN_USER "$(t q_vpn_user_optional)" "${VPN_USER:-}"
    if [ -n "$VPN_USER" ]; then
      ask_valid VPN_PASS "$(t q_vpn_pass)" "${VPN_PASS:-}" valid_nonempty value_required
      { echo "OPENVPN_USER=$VPN_USER"; echo "OPENVPN_PASSWORD=$VPN_PASS"; } >> "$f"
    fi
  elif [ "$VPN_TYPE" = wireguard ]; then
    ask_valid VPN_WG_KEY "$(t q_vpn_wg_key)" "${VPN_WG_KEY:-}" valid_wg_key wg_key_invalid
    ask_valid VPN_WG_ADDR "$(t q_vpn_wg_addr)" "${VPN_WG_ADDR:-}" valid_wg_addr wg_addr_invalid
    { echo "WIREGUARD_PRIVATE_KEY=$VPN_WG_KEY"; echo "WIREGUARD_ADDRESSES=$VPN_WG_ADDR"; } >> "$f"
  else
    ask_valid VPN_USER "$(t q_vpn_user)" "${VPN_USER:-}" valid_nonempty value_required
    ask_valid VPN_PASS "$(t q_vpn_pass)" "${VPN_PASS:-}" valid_nonempty value_required
    { echo "OPENVPN_USER=$VPN_USER"; echo "OPENVPN_PASSWORD=$VPN_PASS"; } >> "$f"
  fi
  # A custom server is one place; countries pick among a provider's servers.
  if [ "$VPN_PROVIDER" != custom ]; then
    ask VPN_COUNTRIES "$(t q_vpn_countries)" "${VPN_COUNTRIES:-}"
    [ -n "$VPN_COUNTRIES" ] && echo "SERVER_COUNTRIES=$VPN_COUNTRIES" >> "$f"
  fi
  chmod 600 "$f"
  good "$(t vpn_env_written "$f")"
}
