# shellcheck shell=bash
# The installed stack: state file, .env, compose overrides, engine runner, health.
#
# Installed layout (INSTALL_DIR, default /opt/tortugarr):
#   app/              copy of this installer, so repair/uninstall work offline
#   state.json        every choice made during install + what the installer created
#   secrets.json      your login and the generated API keys (0600)
#   .env              values for docker compose (0600)
#   compose.yml       regenerated on repair/update
#   overrides/        generated overrides + local.yml (yours, never touched)
#   config/           one directory per service (unless CONFIG_DIR is elsewhere)
#   backups/          backup archives
#   logs/             installer logs

STATE_FILE() { echo "$INSTALL_DIR/state.json"; }
SECRETS_FILE() { echo "$INSTALL_DIR/secrets.json"; }

load_versions() {
  # Not exported: Compose lets environment variables override .env, so an exported
  # IMAGE_* here would silently beat a rollback pin written to .env.
  # shellcheck disable=SC1091
  . "$TORTUGARR_APP/versions.env"
}

state_get() { json_get "$(STATE_FILE)" "$1"; }

# Load an existing installation's state into shell variables.
load_state() {
  local f; f=$(STATE_FILE)
  [ -f "$f" ] || die "$(t no_install_found)"
  CONFIG_DIR=$(state_get .config_dir)
  DATA_DIR=$(state_get .data_dir)
  PUID=$(state_get .puid); PGID=$(state_get .pgid)
  TZ_NAME=$(state_get .tz)
  LAN_IP=$(state_get .lan_ip); BIND_IP=$(state_get .bind_ip)
  TORRENT_CLIENT=$(state_get .torrent_client)
  EXT_QBIT_JSON=$(jq -c '.external_qbit // {}' "$f")
  EXT_QBIT_URL=$(jq -r '.external_qbit.url // empty' "$f")
  USENET=$(state_get .usenet); VPN=$(state_get .vpn); HWACCEL=$(state_get .hwaccel)
  PLATFORM=$(state_get .platform)
  DOCKER_MODE=$(state_get .docker_mode); DOCKER_MODE=${DOCKER_MODE:-engine}
  P_JELLYFIN=$(state_get .ports.jellyfin); P_SEERR=$(state_get .ports.seerr)
  P_SONARR=$(state_get .ports.sonarr); P_RADARR=$(state_get .ports.radarr)
  P_PROWLARR=$(state_get .ports.prowlarr); P_TORRENT_WEB=$(state_get .ports.torrent_web)
  P_TORRENT_PEER=$(state_get .ports.torrent_peer); P_SABNZBD=$(state_get .ports.sabnzbd)
  # Installs from before Bazarr was added have no port or languages yet.
  P_BAZARR=$(state_get .ports.bazarr); P_BAZARR=${P_BAZARR:-6767}
  SUB_LANGS=$(jq -r '(.subtitle_languages // ["en"]) | join(",")' "$f")
  METADATA_LANG=$(state_get .metadata_language); METADATA_COUNTRY=$(state_get .metadata_country)
  QUALITY_PROFILE=$(state_get .default_quality_profile)
  SCAN_MINUTES=$(state_get .library_scan_minutes)
  EXTRA_LIBS_JSON=$(jq -c '.extra_libraries // []' "$f")
  NEW_IN_EXTRA=$(jq -r 'if .new_titles_in_extra_only == false then "n" else "y" end' "$f")
  CREATED_JSON=$(jq -c '.created // {}' "$f")
  INSTALLED_VERSION=$(state_get .tortugarr_version)
  local l; l=$(state_get .language); [ -n "$l" ] && [ -z "${LANG_FORCED:-}" ] && load_language "$l"
}

write_state() {
  local now; now=$(date -u +%FT%TZ)
  local installed_at; installed_at=$(state_get .installed_at 2>/dev/null)
  mkdir -p "$INSTALL_DIR"
  jq -n \
    --arg version "$TORTUGARR_VERSION" --arg installed_at "${installed_at:-$now}" --arg updated_at "$now" \
    --arg platform "$PLATFORM" --arg docker_mode "${DOCKER_MODE:-engine}" --arg install_dir "$INSTALL_DIR" --arg config_dir "$CONFIG_DIR" \
    --arg data_dir "$DATA_DIR" --arg puid "$PUID" --arg pgid "$PGID" --arg tz "$TZ_NAME" \
    --arg lan_ip "$LAN_IP" --arg bind_ip "$BIND_IP" --arg language "$TORTUGARR_LANG" \
    --arg mlang "$METADATA_LANG" --arg mcountry "$METADATA_COUNTRY" \
    --arg client "$TORRENT_CLIENT" --argjson usenet "$( [ "$USENET" = true ] && echo true || echo false)" \
    --argjson vpn "$( [ "$VPN" = true ] && echo true || echo false)" \
    --argjson hwaccel "$( [ "$HWACCEL" = true ] && echo true || echo false)" \
    --argjson pj "$P_JELLYFIN" --argjson ps "$P_SEERR" --argjson pso "$P_SONARR" --argjson pr "$P_RADARR" \
    --argjson pp "$P_PROWLARR" --argjson ptw "$P_TORRENT_WEB" --argjson ptp "$P_TORRENT_PEER" --argjson psab "$P_SABNZBD" --argjson pbz "${P_BAZARR:-6767}" \
    --argjson extra "${EXTRA_LIBS_JSON:-[]}" --argjson newextra "$( [ "${NEW_IN_EXTRA:-y}" = y ] && echo true || echo false)" --arg profile "${QUALITY_PROFILE:-HD-1080p}" \
    --argjson scan "${SCAN_MINUTES:-30}" --arg sublangs "${SUB_LANGS:-en}" \
    --arg prepo "$MOONFIN_PLUGIN_REPO" --arg pguid "$MOONFIN_PLUGIN_GUID" --arg pver "$MOONFIN_PLUGIN_VERSION" --arg pmin "${MOONFIN_PLUGIN_MIN_VERSION:-$MOONFIN_PLUGIN_VERSION}" \
    --argjson created "${CREATED_JSON:-{\}}" --argjson extqb "${EXT_QBIT_JSON:-null}" \
    '{tortugarr_version:$version, installed_at:$installed_at, updated_at:$updated_at, platform:$platform, docker_mode:$docker_mode,
      install_dir:$install_dir, config_dir:$config_dir, data_dir:$data_dir, puid:$puid, pgid:$pgid,
      tz:$tz, lan_ip:$lan_ip, bind_ip:$bind_ip, language:$language,
      metadata_language:$mlang, metadata_country:$mcountry,
      torrent_client:$client, usenet:$usenet, vpn:$vpn, hwaccel:$hwaccel,
      ports:{jellyfin:$pj, seerr:$ps, sonarr:$pso, radarr:$pr, prowlarr:$pp, bazarr:$pbz,
             torrent_web:$ptw, torrent_peer:$ptp, sabnzbd:$psab},
      extra_libraries:$extra, new_titles_in_extra_only:$newextra, default_quality_profile:$profile, library_scan_minutes:$scan,
      subtitle_languages:($sublangs | split(",") | map(select(length > 0))),
      moonfin_plugin:true, moonfin_plugin_repo:$prepo, moonfin_plugin_guid:$pguid,
      moonfin_plugin_version:$pver, moonfin_plugin_min_version:$pmin, created:$created}
      + (if $client == "qbittorrent-ext" then {external_qbit:$extqb} else {} end)' > "$(STATE_FILE).tmp" \
    || die "could not write state.json"
  mv "$(STATE_FILE).tmp" "$(STATE_FILE)"
  chmod 600 "$(STATE_FILE)"
  mkdir -p /etc/tortugarr && echo "$INSTALL_DIR" > /etc/tortugarr/install-dir
}

# Record something the installer created, so uninstall removes exactly that.
record_created() {  # key json-value
  CREATED_JSON=$(jq -c --arg k "$1" --argjson v "$2" '.[$k] = $v' <<< "${CREATED_JSON:-{\}}")
}

write_secrets_if_missing() {
  local f; f=$(SECRETS_FILE)
  if [ -f "$f" ]; then
    # Keep existing secrets; only fill in an admin user/password that is missing.
    jq --arg u "$ADMIN_USER" --arg p "$ADMIN_PASSWORD" \
      '.admin_user = (.admin_user // $u) | .admin_password = (.admin_password // $p)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    jq -n --arg u "$ADMIN_USER" --arg p "$ADMIN_PASSWORD" '{admin_user:$u, admin_password:$p}' > "$f"
  fi
  # The password of a qBittorrent outside the stack, when it has one (state.json holds the rest).
  if [ -n "${EXT_QBIT_PASSWORD:-}" ]; then
    jq --arg p "$EXT_QBIT_PASSWORD" '.external_qbit_password = $p' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
  chmod 600 "$f"
}

compose_profiles() {
  local p=()
  client_in_stack && p+=("$TORRENT_CLIENT")
  [ "$USENET" = true ] && p+=(sabnzbd)
  [ "$VPN" = true ] && p+=(vpn)
  local IFS=,; echo "${p[*]}"
}

write_overrides() {
  local o="$INSTALL_DIR/overrides"
  mkdir -p "$o"
  rm -f "$o/media.yml" "$o/vpn.yml" "$o/hwaccel.yml"
  local files="compose.yml"
  write_external_client_override "$o" && files="$files:overrides/download-client.yml"

  if [ "$(jq length <<< "${EXTRA_LIBS_JSON:-[]}")" -gt 0 ]; then
    # Jellyfin gets every extra folder read-only; Sonarr/Radarr only the folders
    # of their type that the user wants them to manage, and Bazarr all of those.
    jq -r '
      def mounts($s):
        [ .[] | select($s == "jellyfin"
                       or (.arr_manage and ((.type == "tv" and $s == "sonarr") or ((.type == "movies" or .type == "docs") and $s == "radarr")))
                       or (.arr_manage and $s == "bazarr"))
              | "      - \"\(.host_path):\(.container_path)\(if $s == "jellyfin" then ":ro" else "" end)\"" ];
      "# Generated: existing media folders added during install. Regenerated on repair.",
      "services:",
      ( ["jellyfin", "sonarr", "radarr", "bazarr"][] as $s
        | mounts($s) as $m
        | select($m | length > 0)
        | "  \($s):", "    volumes:", $m[] )
    ' <<< "$EXTRA_LIBS_JSON" > "$o/media.yml"
    files="$files:overrides/media.yml"
  fi

  if [ "$VPN" = true ] && client_in_stack; then
    local web_internal
    case "$TORRENT_CLIENT" in qbittorrent) web_internal=8080 ;; transmission) web_internal=9091 ;; deluge) web_internal=8112 ;; esac
    cat > "$o/vpn.yml" <<EOF
# Generated: the torrent client runs inside gluetun's network namespace, so all of
# its traffic leaves through the VPN and stops if the VPN drops. Provider settings
# are in overrides/vpn.env.
services:
  gluetun:
    profiles: [vpn]
    image: \${IMAGE_GLUETUN}
    container_name: tortugarr-gluetun
    restart: unless-stopped
    cap_add: [NET_ADMIN]
    devices:
      - /dev/net/tun:/dev/net/tun
    # Relative paths in override files resolve against the project dir (INSTALL_DIR).
    env_file: [overrides/vpn.env]
EOF
    # A custom OpenVPN server: the user's own .ovpn file (OPENVPN_CUSTOM_CONFIG).
    [ -f "$INSTALL_DIR/overrides/custom.ovpn" ] && cat >> "$o/vpn.yml" <<EOF
    volumes:
      - ./overrides/custom.ovpn:/gluetun/custom.ovpn:ro
EOF
    cat >> "$o/vpn.yml" <<EOF
    environment:
      TZ: \${TZ}
      FIREWALL_INPUT_PORTS: "$web_internal,\${TORRENT_PEER_PORT}"
      FIREWALL_VPN_INPUT_PORTS: "\${TORRENT_PEER_PORT}"
    ports:
      - \${BIND_IP}:\${TORRENT_WEB_PORT}:$web_internal
      - \${TORRENT_PEER_PORT}:\${TORRENT_PEER_PORT}
      - \${TORRENT_PEER_PORT}:\${TORRENT_PEER_PORT}/udp
  $TORRENT_CLIENT:
    network_mode: "service:gluetun"
    ports: !reset []
    depends_on:
      gluetun:
        condition: service_healthy
EOF
    files="$files:overrides/vpn.yml"
  fi

  if [ "$HWACCEL" = true ]; then
    local render_gid; render_gid=$(stat -c %g /dev/dri/renderD128 2>/dev/null || echo 0)
    cat > "$o/hwaccel.yml" <<EOF
# Generated: GPU for Jellyfin hardware transcoding (Intel/AMD via /dev/dri).
services:
  jellyfin:
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - "$render_gid"
EOF
    files="$files:overrides/hwaccel.yml"
  fi

  if [ ! -f "$o/local.yml" ]; then
    cat > "$o/local.yml" <<'EOF'
# Your own changes to the stack go here (extra volumes, environment, ...).
# This file is never overwritten by repair or update. Example:
#
# services:
#   jellyfin:
#     environment:
#       JELLYFIN_CACHE_DIR: /cache
services: {}
EOF
  fi
  files="$files:overrides/local.yml"
  COMPOSE_FILES=$files
}

# One IMAGE_* line per image. Compose uses the FIRST definition of a key in .env,
# so overrides (a rollback, --latest) must replace lines, not be appended.
image_lines() {
  local line key
  declare -A img=()
  local order=()
  while IFS= read -r line; do
    key=${line%%=*}
    [ -z "${img[$key]+x}" ] && order+=("$key")
    img[$key]=${line#*=}
  done < <(grep -E '^IMAGE_[A-Z_]+=' "$TORTUGARR_APP/versions.env")
  if [ "${TORTUGARR_FLOATING_IMAGES:-0}" = 1 ]; then
    # `update --latest`: newest published images instead of the tested pins.
    # The tools image stays pinned - it only runs the installer's own engine.
    for key in "${order[@]}"; do
      [ "$key" = IMAGE_TOOLS ] && continue
      img[$key]=$(sed -E 's#@sha256:[0-9a-f]+$##; s#^([^:]+(:[0-9]+)?/?[^:]*):[^:]+$#\1:latest#' <<< "${img[$key]}")
    done
  fi
  # A rollback after a failed update pins the previous images until the next update.
  if [ -f "$INSTALL_DIR/rollback.env" ]; then
    while IFS= read -r line; do
      key=${line%%=*}
      [ -n "${img[$key]+x}" ] && img[$key]=${line#*=}
    done < <(grep -E '^IMAGE_[A-Z_]+=' "$INSTALL_DIR/rollback.env")
  fi
  for key in "${order[@]}"; do echo "$key=${img[$key]}"; done
}

write_env() {
  load_versions
  local f="$INSTALL_DIR/.env"
  local torrent_pw; torrent_pw=$(jq -r '.admin_password' "$(SECRETS_FILE)")
  local torrent_user; torrent_user=$(jq -r '.admin_user' "$(SECRETS_FILE)")
  {
    echo "# Generated by the Tortugarr installer - regenerated on repair/update."
    echo "# Change settings with: tortugarr reconfigure"
    echo "COMPOSE_PROJECT_NAME=tortugarr"
    echo "COMPOSE_FILE=$COMPOSE_FILES"
    echo "COMPOSE_PROFILES=$(compose_profiles)"
    echo "PUID=$PUID"
    echo "PGID=$PGID"
    echo "TZ=$TZ_NAME"
    echo "LAN_IP=$LAN_IP"
    echo "BIND_IP=$BIND_IP"
    echo "TORTUGARR_CONFIG=$CONFIG_DIR"
    echo "TORTUGARR_DATA=$DATA_DIR"
    echo "JELLYFIN_PORT=$P_JELLYFIN"
    echo "SEERR_PORT=$P_SEERR"
    echo "SONARR_PORT=$P_SONARR"
    echo "RADARR_PORT=$P_RADARR"
    echo "PROWLARR_PORT=$P_PROWLARR"
    echo "BAZARR_PORT=$P_BAZARR"
    echo "TORRENT_WEB_PORT=$P_TORRENT_WEB"
    echo "TORRENT_PEER_PORT=$P_TORRENT_PEER"
    echo "SABNZBD_PORT=$P_SABNZBD"
    # Single quotes: Compose takes $ and # inside literally (the password may contain them).
    echo "TORRENT_USER='$torrent_user'"
    echo "TORRENT_PASSWORD='$torrent_pw'"
    image_lines
  } > "$f"
  chmod 600 "$f"
}

install_app_copy() {
  # Keep a copy of the installer next to the stack so `tortugarr repair` and
  # `tortugarr uninstall` work even if the original download is gone.
  if [ "$(readlink -f "$TORTUGARR_APP")" != "$(readlink -f "$INSTALL_DIR/app")" ]; then
    rm -rf "$INSTALL_DIR/app.new"
    mkdir -p "$INSTALL_DIR/app.new"
    (cd "$TORTUGARR_APP" && tar --exclude=.git --exclude=tests/.work -cf - .) | (cd "$INSTALL_DIR/app.new" && tar -xf -)
    rm -rf "$INSTALL_DIR/app"
    mv "$INSTALL_DIR/app.new" "$INSTALL_DIR/app"
  fi
  cp "$INSTALL_DIR/app/compose/compose.yml" "$INSTALL_DIR/compose.yml"
  ln -sf "$INSTALL_DIR/app/install.sh" /usr/local/bin/tortugarr
  chmod 755 "$INSTALL_DIR/app/install.sh"
}

# docker compose with .env as the only source of its variables: anything with the
# same name in our environment (answers files are exported) would override .env.
dc() {
  (
    cd "$INSTALL_DIR" || exit 1
    local k
    for k in $(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env 2>/dev/null); do
      unset "$k"
    done
    docker compose "$@"
  )
}

# Run the configuration engine in a throwaway container.
engine() {
  load_versions
  local net=tortugarr
  docker network inspect tortugarr >/dev/null 2>&1 || net=none
  docker run --rm --network "$net" \
    -v "$INSTALL_DIR:/tortugarr" -v "$CONFIG_DIR:/cfg" -v "$INSTALL_DIR/app/bootstrap:/app:ro" \
    -e TORTUGARR_ONLY="${TORTUGARR_ONLY:-}" -e DEST="${ENGINE_DEST:-}" -e TORTUGARR_VERSION="$TORTUGARR_VERSION" \
    -e TORTUGARR_CLOSING_BOX="${TORTUGARR_CLOSING_BOX:-}" \
    "$IMAGE_TOOLS" python3 -u /app/tortugarr_bootstrap.py "$@" 2>&1 | tee -a "$TORTUGARR_LOG" | render_engine_output
  return "${PIPESTATUS[0]}"
}

expected_services() {
  local s=(jellyfin sonarr radarr prowlarr bazarr seerr flaresolverr)
  client_in_stack && s+=("$TORRENT_CLIENT")
  [ "$USENET" = true ] && s+=(sabnzbd)
  [ "$VPN" = true ] && client_in_stack && s+=(gluetun)
  echo "${s[@]}"
}

wait_containers() {
  local deadline=$(( $(date +%s) + ${1:-240} )) svc st bad
  while :; do
    bad=""
    for svc in $(expected_services); do
      st=$(docker inspect -f '{{.State.Status}}{{if .State.Health}}/{{.State.Health.Status}}{{end}}' "tortugarr-$svc" 2>/dev/null)
      case "$st" in running|running/healthy) ;; *) bad="$bad $svc($st)" ;; esac
    done
    [ -z "$bad" ] && return 0
    [ "$(date +%s)" -gt "$deadline" ] && { warning "$(t containers_not_ready "$bad")"; return 1; }
    sleep 4
  done
}

published_ports() {
  local p=("$P_JELLYFIN" "$P_SEERR" "$P_SONARR" "$P_RADARR" "$P_PROWLARR" "$P_BAZARR")
  client_in_stack && p+=("$P_TORRENT_WEB")
  [ "$USENET" = true ] && p+=("$P_SABNZBD")
  echo "${p[@]}"
}

# Open the published ports in ufw when it is active (native Linux only).
firewall_open() {
  command -v ufw >/dev/null 2>&1 || return 0
  ufw status 2>/dev/null | grep -q '^Status: active' || return 0
  local p opened=()
  for p in $(published_ports) "$P_TORRENT_PEER"; do
    run ufw allow "$p" comment tortugarr >/dev/null && opened+=("$p")
  done
  record_created ufw_ports "$(printf '%s\n' "${opened[@]}" | jq -R . | jq -sc .)"
  good "$(t ufw_opened "${opened[*]}")"
}

firewall_close() {
  command -v ufw >/dev/null 2>&1 || return 0
  local p
  for p in $(jq -r '.ufw_ports[]? // empty' <<< "${CREATED_JSON:-{\}}"); do
    run ufw delete allow "$p" >/dev/null || true
  done
}

ensure_dirs() {
  local d f fresh=" "
  # On an existing install a missing media folder means its disk is not mounted. Creating it
  # would put an empty folder (and a keep file, below) on the system disk, and Jellyfin would
  # then drop the whole library from its database. Only install and restore create them.
  if [ "${TORTUGARR_MAY_CREATE_MEDIA:-0}" != 1 ]; then
    for d in movies tv; do
      [ -d "$DATA_DIR/media/$d" ] || die "$(t media_dir_missing "$DATA_DIR/media/$d")"
    done
  fi
  for d in movies tv adult; do [ -d "$DATA_DIR/media/$d" ] || fresh+="$d "; done
  for d in "$CONFIG_DIR" "$DATA_DIR/media/movies" "$DATA_DIR/media/tv" "$DATA_DIR/media/adult" \
           "$DATA_DIR/torrents/movies" "$DATA_DIR/torrents/tv" "$DATA_DIR/torrents/prowlarr" \
           "$DATA_DIR/usenet/complete/tv" "$DATA_DIR/usenet/complete/movies" "$DATA_DIR/usenet/complete/prowlarr" \
           "$DATA_DIR/usenet/incomplete" \
           "$INSTALL_DIR/backups" "$INSTALL_DIR/logs"; do
    mkdir -p "$d"
  done
  # Jellyfin skips a library folder that is empty ("inaccessible or empty") in every scan, so the
  # last title deleted from a library would stay in Jellyfin for good. A hidden file keeps these
  # folders non-empty; Jellyfin and the *arrs ignore dotfiles. (Not ".ignore": Jellyfin would
  # then skip the whole folder.)
  # It is only written into a folder made just now or one that already holds something, so it
  # lands on the media disk itself; an empty folder made earlier may be a bare mount point
  # (disk not mounted) and keeps Jellyfin's "empty folder" protection.
  for d in movies tv adult; do
    f="$DATA_DIR/media/$d"
    [ -e "$f/.tortugarr-keep" ] && continue
    if [[ $fresh == *" $d "* ]] || [ -n "$(ls -A "$f" 2>/dev/null)" ]; then
      echo "Keeps this folder from looking empty to Jellyfin. Leave it here." > "$f/.tortugarr-keep"
      chown "$PUID:$PGID" "$f/.tortugarr-keep" 2>/dev/null || true
    else
      warning "$(t media_dir_empty "$f")"
    fi
  done
  chown "$PUID:$PGID" "$DATA_DIR" "$DATA_DIR"/{media,torrents,usenet} "$DATA_DIR"/media/{movies,tv,adult} \
    "$DATA_DIR"/torrents/{movies,tv,prowlarr} "$DATA_DIR"/usenet/{complete,incomplete} \
    "$DATA_DIR"/usenet/complete/{tv,movies,prowlarr} 2>/dev/null || true
  chmod 775 "$DATA_DIR" "$DATA_DIR"/{media,torrents,usenet} 2>/dev/null || true
  chown "$PUID:$PGID" "$CONFIG_DIR"
  chmod 700 "$INSTALL_DIR/backups"
}

# Container bind mounts pin the directory inode. If a config directory was
# replaced on disk while its container ran, the container keeps reading the
# deleted one. This probe catches it.
stale_mounts() {
  local svc dir target stale=() probe=".tortugarr-probe-$$"
  for svc in $(expected_services); do
    case $svc in flaresolverr|gluetun) continue ;; seerr) dir=seerr; target=/app/config ;; *) dir=$svc; target=/config ;; esac
    [ -d "$CONFIG_DIR/$dir" ] || continue
    docker inspect "tortugarr-$svc" >/dev/null 2>&1 || continue
    touch "$CONFIG_DIR/$dir/$probe" 2>/dev/null || continue
    docker exec "tortugarr-$svc" ls "$target/$probe" >/dev/null 2>&1 || stale+=("$svc")
    rm -f "$CONFIG_DIR/$dir/$probe"
  done
  echo "${stale[@]}"
}
