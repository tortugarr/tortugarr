#!/usr/bin/env bash
# Tortugarr server installer.
#
#   sudo ./install.sh                 interactive: install, or a menu if already installed
#   sudo tortugarr <command> [options]  after installation
#
# Commands: install | repair | update | reconfigure | backup | restore <file>
#           uninstall | status | doctor | credentials | logs [service] | help
#           info                 the addresses and login again (the password is not shown)
#           support              a support bundle: logs + status, every password/key removed
#           windows [setup|status|remove]   only inside WSL2: the optional Windows helper
#
# Options:  --lang <en|nb|sv|da|de>   interface language
#           --answers <file>          unattended install; see docs/answers.example.env
#           --yes                     accept defaults for every question
#           --install-dir <dir>       default /opt/tortugarr
#           --with-images             backup: also save the container images
#           --latest                  update: newest images instead of the pinned ones
#           --purge                   uninstall: also delete settings (media is never deleted)

set -uo pipefail

TORTUGARR_APP=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
export TORTUGARR_APP

# shellcheck source=lib/common.sh
. "$TORTUGARR_APP/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$TORTUGARR_APP/lib/detect.sh"
# shellcheck source=lib/docker.sh
. "$TORTUGARR_APP/lib/docker.sh"
# shellcheck source=lib/stack.sh
. "$TORTUGARR_APP/lib/stack.sh"
# shellcheck source=lib/windows.sh
. "$TORTUGARR_APP/lib/windows.sh"
# shellcheck source=lib/external_client.sh
. "$TORTUGARR_APP/lib/external_client.sh"
# shellcheck source=lib/extra_libs.sh
. "$TORTUGARR_APP/lib/extra_libs.sh"
# shellcheck source=lib/support.sh
. "$TORTUGARR_APP/lib/support.sh"
# shellcheck source=lib/vpn.sh
. "$TORTUGARR_APP/lib/vpn.sh"

load_versions

# ---------------------------------------------------------------- arguments

ORIG_ARGS=("$@")
COMMAND=""
COMMAND_ARG=""
INSTALL_DIR=""
WITH_IMAGES=0
LATEST=0
PURGE=0
LANG_FORCED=""
ANSWERS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_FORCED=$2; shift ;;
    --lang=*) LANG_FORCED=${1#*=} ;;
    --answers) ANSWERS=$2; UNATTENDED=1; shift ;;
    --answers=*) ANSWERS=${1#*=}; UNATTENDED=1 ;;
    --yes|-y) UNATTENDED=1 ;;
    --install-dir) INSTALL_DIR=$2; shift ;;
    --install-dir=*) INSTALL_DIR=${1#*=} ;;
    --with-images) WITH_IMAGES=1 ;;
    --latest) LATEST=1 ;;
    --purge) PURGE=1 ;;
    -h|--help|help) COMMAND=help ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$COMMAND" ]; then COMMAND=$1; else COMMAND_ARG=$1; fi ;;
  esac
  shift
done

# English until the user picks a language (or --lang / the answers file / the saved state says otherwise).
load_language "${LANG_FORCED:-en}"

if [ -n "$ANSWERS" ]; then
  [ -f "$ANSWERS" ] || { echo "Answers file not found: $ANSWERS" >&2; exit 2; }
  # shellcheck disable=SC1090
  set -a; . "$ANSWERS"; set +a
  [ -n "${TORTUGARR_LANGUAGE:-}" ] && [ -z "$LANG_FORCED" ] && load_language "$TORTUGARR_LANGUAGE"
fi

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    # The settings the installer reads from the environment go along by name: sudo -E is not
    # supported by sudo-rs (Ubuntu 26.04), which warns and drops it (2026-10-21).
    keep=(TORTUGARR_INVOKER="${USER:-}")
    for v in DATA_DIR INSTALL_DIR NO_COLOR UNATTENDED TORTUGARR_FLOATING_IMAGES TORTUGARR_HOME \
             TORTUGARR_LANGUAGE TORTUGARR_LOG TORTUGARR_MAY_CREATE_MEDIA TORTUGARR_ONLY TORTUGARR_PLATFORM; do
      [ -n "${!v+x}" ] && keep+=("$v=${!v}")
    done
    exec sudo env "${keep[@]}" bash "$0" "${ORIG_ARGS[@]}"
  fi
  die "$(t need_root)"
fi

INVOKER=${TORTUGARR_INVOKER:-${SUDO_USER:-}}
EXISTING=$(find_existing_install)
INSTALL_DIR=${INSTALL_DIR:-${EXISTING:-/opt/tortugarr}}
mkdir -p "$INSTALL_DIR/logs" 2>/dev/null && TORTUGARR_LOG="$INSTALL_DIR/logs/tortugarr-$(date +%Y%m%d-%H%M%S).log"
_log "tortugarr $TORTUGARR_VERSION command=${COMMAND:-auto} app=$TORTUGARR_APP install_dir=$INSTALL_DIR"

banner() {
  printf '%s' "$C_RED$C_BOLD"
  cat <<'EOF'
   _____            _
  |_   _|__  _ __| |_ _   _  __ _  __ _ _ __ _ __
    | |/ _ \| '__| __| | | |/ _` |/ _` | '__| '__|
    | | (_) | |  | |_| |_| | (_| | (_| | |  | |
    |_|\___/|_|   \__|\__,_|\__, |\__,_|_|  |_|
                            |___/
EOF
  printf '%s  %s %s\n\n' "$C_RESET$C_DIM" "$(t tagline)" "v$TORTUGARR_VERSION$C_RESET"
}

# ---------------------------------------------------------------- preflight

preflight() {
  header "$(t preflight)"
  local id ver; id=$(os_id); ver=$(os_version)
  case "$id" in
    ubuntu) case "$ver" in 22.04|24.04|26.04) good "$(os_pretty)" ;; *) warning "$(t os_untested "$(os_pretty)")" ;; esac ;;
    debian) warning "$(t os_untested "$(os_pretty)")" ;;
    *) die "$(t os_unsupported "$(os_pretty)")" ;;
  esac
  case "$(arch)" in amd64|arm64) good "$(t arch_ok "$(arch)")" ;; *) die "$(t arch_unsupported "$(arch)")" ;; esac
  if is_wsl; then
    PLATFORM=wsl
    # Tortugarr is Linux-only. WSL2 may work, but networking, port forwarding and keeping
    # the distro running are the user's own job there - say so and let them decide.
    warning "$(t wsl_unsupported)"
    if [ "$UNATTENDED" = 1 ]; then [ "${WSL_OK:-n}" = y ] || die "$(t wsl_unattended)"
    else confirm WSL_OK "$(t q_wsl_continue)" n || die "$(t aborted)"; fi
    has_systemd || die "$(t wsl_systemd_needed)"
  else
    PLATFORM=linux
    has_systemd || warning "$(t no_systemd)"
  fi
  local ram; ram=$(total_ram_gb)
  [ "${ram:-0}" -lt 3 ] && warning "$(t low_ram "$ram")" || good "$(t ram_ok "$ram")"
  internet_ok || die "$(t no_internet)"
  good "$(t internet_ok)"
}

# ---------------------------------------------------------------- questions

default_tz() {
  if [ -f /etc/timezone ]; then cat /etc/timezone
  elif command -v timedatectl >/dev/null 2>&1; then timedatectl show -p Timezone --value 2>/dev/null
  else echo UTC; fi
}

pick_port() {  # VAR default label
  local var=$1 def=$2 label=$3 p
  p=${!var:-$def}
  while :; do
    ask "$var" "$(t port_for "$label")" "$p"
    p=${!var}
    [[ $p =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || { warning "$(t port_invalid)"; p=$def; continue; }
    if port_in_use "$p" && ! port_owner_is_tortugarr "$p"; then
      warning "$(t port_busy "$p" "$label")"
      [ "$UNATTENDED" = 1 ] && die "$(t port_busy_unattended "$p")"
      p=$((p + 1)); continue
    fi
    for used in "${USED_PORTS[@]:-}"; do
      [ "$used" = "$p" ] && { warning "$(t port_dup "$p")"; p=$((p + 1)); continue 2; }
    done
    USED_PORTS+=("$p")
    printf -v "$var" '%s' "$p"
    return
  done
}

# The summary, then go or not. A no offers the questions again with every answer
# as the default, so one wrong answer (a drive, a folder type) needs only Enter
# through the rest - nothing has been written yet.
confirm_answers() {  # reconf(0|1) question-key
  while :; do
    show_summary
    confirm GO "$(t "$2")" y && return 0
    [ "$UNATTENDED" = 1 ] && die "$(t aborted)"
    confirm REDO "$(t q_answers_again)" y || die "$(t aborted)"
    ask_questions "$1" 1
  done
}

ask_questions() {
  local reconf=${1:-0} again=${2:-0}
  header "$(t questions)"
  USED_PORTS=()

  if [ "$reconf" = 0 ] && [ "$again" = 0 ] && [ -z "$LANG_FORCED" ] && [ "$UNATTENDED" = 0 ]; then
    choose TORTUGARR_LANGUAGE "Language / Språk / Sprache" "$TORTUGARR_LANG" \
      en "English" nb "Norsk (bokmål)" sv "Svenska" da "Dansk" de "Deutsch"
    load_language "$TORTUGARR_LANGUAGE"
  fi

  say "$(t q_paths_intro)"
  if [ "$reconf" = 0 ]; then
    CONFIG_DIR=${CONFIG_DIR:-$INSTALL_DIR/config}
    ask_valid DATA_DIR "$(t q_data_dir)" "${DATA_DIR:-/srv/tortugarr}" valid_abs_path path_invalid
    DATA_DIR=${DATA_DIR%/}
    local free; free=$(free_gb "$(dirname "$DATA_DIR")")
    note "$(t free_space "$DATA_DIR" "${free:-?}")"
    if is_slow_fs "$DATA_DIR"; then
      warning "$(t slow_fs "$DATA_DIR" "$(fs_type "$DATA_DIR")")"
    fi
  fi

  # Existing media folders, each with one type (lib/extra_libs.sh).
  # A second round keeps the folders already given, to change or add to.
  if [ "$again" = 1 ]; then ask_extra_libs 1; else ask_extra_libs "$reconf"; fi

  say "$(t client_intro)"
  choose TORRENT_CLIENT "$(t q_torrent_client)" "${TORRENT_CLIENT:-qbittorrent}" \
    qbittorrent "qBittorrent  $(t client_qbit_note)" \
    qbittorrent-ext "$(t client_qbit_ext)" \
    transmission "Transmission" \
    deluge "Deluge" \
    none "$(t client_none)"
  [ "$TORRENT_CLIENT" = qbittorrent-ext ] && ask_external_qbit

  local u=false; [ "${USENET:-false}" = true ] && u=y
  if confirm USENET_ANS "$(t q_usenet)" "${u/false/n}"; then USENET=true; else USENET=false; fi

  VPN=${VPN:-false}
  # The VPN container can only carry a client that runs in the stack.
  if client_in_stack; then
    local v=n; [ "$VPN" = true ] && v=y
    if confirm VPN_ANS "$(t q_vpn)" "$v"; then VPN=true; else VPN=false; fi
  else
    VPN=false
  fi
  [ "$VPN" = true ] && ask_vpn

  HWACCEL=false
  if has_dri; then
    confirm HWACCEL_ANS "$(t q_hwaccel)" y && HWACCEL=true
  fi

  LAN_IP=$(detect_lan_ip)
  ask_valid LAN_IP "$(t q_lan_ip)" "${LAN_IP}" valid_host host_invalid
  BIND_IP=${BIND_IP:-0.0.0.0}
  ask_valid TZ_NAME "$(t q_timezone)" "${TZ_NAME:-$(default_tz)}" valid_tz tz_invalid
  choose METADATA_LANG "$(t q_metadata_lang)" "${METADATA_LANG:-en}" \
    en English nb "Norsk" sv "Svenska" da "Dansk" de "Deutsch" fr "Français" es "Español"
  case "$METADATA_LANG" in en) METADATA_COUNTRY=US ;; nb) METADATA_COUNTRY=NO ;; sv) METADATA_COUNTRY=SE ;;
    da) METADATA_COUNTRY=DK ;; de) METADATA_COUNTRY=DE ;; fr) METADATA_COUNTRY=FR ;; es) METADATA_COUNTRY=ES ;; esac
  # Subtitles (Bazarr): English by default, whatever the installer language; more are optional.
  local sub_default=en
  while :; do
    ask SUB_LANGS "$(t q_subtitle_langs)" "${SUB_LANGS:-$sub_default}"
    SUB_LANGS=$(tr -d ' ' <<< "${SUB_LANGS,,}")
    [[ $SUB_LANGS =~ ^[a-z]{2}(,[a-z]{2})*$ ]] && break
    warning "$(t subtitle_langs_invalid)"; SUB_LANGS=$sub_default
    [ "$UNATTENDED" = 1 ] && break
  done
  choose QUALITY_PROFILE "$(t q_quality)" "${QUALITY_PROFILE:-HD-1080p}" \
    "HD-1080p" "1080p ($(t recommended))" "HD - 720p/1080p" "720p / 1080p" "Ultra-HD" "4K" "Any" "$(t quality_any)"

  if [ "$reconf" = 0 ] || confirm CHANGE_PORTS "$(t q_change_ports)" n; then
    say "$(t q_ports_intro)"
    pick_port P_JELLYFIN "${P_JELLYFIN:-8096}" Jellyfin
    pick_port P_SEERR "${P_SEERR:-5055}" Seerr
    pick_port P_SONARR "${P_SONARR:-8989}" Sonarr
    pick_port P_RADARR "${P_RADARR:-7878}" Radarr
    pick_port P_PROWLARR "${P_PROWLARR:-9696}" Prowlarr
    pick_port P_BAZARR "${P_BAZARR:-6767}" Bazarr
    local def_web=8080
    case "$TORRENT_CLIENT" in transmission) def_web=9091 ;; deluge) def_web=8112 ;; esac
    if client_in_stack; then
      pick_port P_TORRENT_WEB "${P_TORRENT_WEB:-$def_web}" "$(client_label "$TORRENT_CLIENT") (web UI)"
      pick_port P_TORRENT_PEER "${P_TORRENT_PEER:-6881}" "$(t peer_port)"
    fi
    [ "$USENET" = true ] && pick_port P_SABNZBD "${P_SABNZBD:-8085}" SABnzbd
  fi
  P_TORRENT_WEB=${P_TORRENT_WEB:-8080}; P_TORRENT_PEER=${P_TORRENT_PEER:-6881}; P_SABNZBD=${P_SABNZBD:-8085}; P_BAZARR=${P_BAZARR:-6767}
  SCAN_MINUTES=${SCAN_MINUTES:-30}

  if [ "$reconf" = 0 ]; then
    # The user picks the login for every service; the installer never makes one up.
    if [ "$UNATTENDED" = 1 ]; then
      valid_username "${ADMIN_USER:-}" && valid_password "${ADMIN_PASSWORD:-}" || die "$(t admin_unattended_missing)"
    else
      say "$(t q_admin_intro)"
      while :; do
        ask ADMIN_USER "$(t q_admin_user)" "${ADMIN_USER:-}"
        valid_username "$ADMIN_USER" && break
        warning "$(t user_invalid)"; ADMIN_USER=""
      done
      ask_password ADMIN_PASSWORD "$(t q_admin_password)"
    fi
  fi

  # Who owns the files. Prefer the user who ran sudo.
  if [ -z "${PUID:-}" ]; then
    if [ -n "$INVOKER" ] && [ "$INVOKER" != root ] && id "$INVOKER" >/dev/null 2>&1; then
      PUID=$(id -u "$INVOKER"); PGID=$(id -g "$INVOKER")
    else
      PUID=1000; PGID=1000
    fi
  fi
}

yes_no() { [ "$1" = true ] && t yes || t no; }
client_label() {
  case $1 in qbittorrent) echo qBittorrent ;; qbittorrent-ext) echo "qBittorrent ($(t client_ext_short) ${EXT_QBIT_URL:-})" ;; transmission) echo Transmission ;; deluge) echo Deluge ;; *) t client_none_short ;; esac
}

show_summary() {
  header "$(t summary)"
  printf '  %-26s %s\n' "$(t s_install_dir)" "$INSTALL_DIR" "$(t s_config_dir)" "$CONFIG_DIR" \
    "$(t s_data_dir)" "$DATA_DIR" "$(t s_client)" "$(client_label "$TORRENT_CLIENT")" "$(t s_usenet)" "$(yes_no "$USENET")" \
    "$(t s_vpn)" "$(yes_no "$VPN")" "$(t s_hwaccel)" "$(yes_no "$HWACCEL")" "$(t s_lan_ip)" "$LAN_IP" "$(t s_owner)" "$PUID:$PGID" \
    "$(t s_ports)" "Jellyfin $P_JELLYFIN, Seerr $P_SEERR, Sonarr $P_SONARR, Radarr $P_RADARR, Prowlarr $P_PROWLARR, Bazarr $P_BAZARR"
  local n; n=$(jq length <<< "${EXTRA_LIBS_JSON:-[]}")
  if [ "$TORRENT_CLIENT" = qbittorrent-ext ]; then
    printf '  %-26s %s\n' "$(t s_ext_downloads)" "$(jq -r '[.mounts[]?.remote] | join(", ")' <<< "${EXT_QBIT_JSON:-{\}}")"
  fi
  [ "$n" -gt 0 ] && jq -r '.[] | "  + \(.host_path) (\(.type))"' <<< "$EXTRA_LIBS_JSON"
  echo
}

# ---------------------------------------------------------------- shared steps

# Registries throttle many parallel layer downloads at times ("error from registry:
# retry-after ..."). Try again after a pause, then one image at a time.
pull_images() {
  pull_stack_images || return 1
  # The installer's own engine runs in this image; fetched here with the rest, quietly, instead
  # of by its first `docker run`, which printed every layer (2026-10-21).
  load_versions
  docker image inspect "$IMAGE_TOOLS" >/dev/null 2>&1 \
    || run docker pull -q "$IMAGE_TOOLS" || { sleep 20; run docker pull -q "$IMAGE_TOOLS"; }
}

pull_stack_images() {
  local attempt svc
  for attempt in 1 2 3; do
    run dc pull -q && return 0
    warning "$(t pull_retry "$attempt")"
    sleep $((attempt * 20))
  done
  for svc in $(dc config --services); do
    run dc pull -q "$svc" || { sleep 30; run dc pull -q "$svc"; } || return 1
  done
}

bring_up() {
  install_app_copy
  write_overrides
  write_env
  step "$(t validating_compose)"
  dc config -q 2>>"$TORTUGARR_LOG" || { dc config -q; die "$(t compose_invalid)"; }
  step "$(t pulling_images)"
  pull_images || die "$(t pull_failed)"
  good "$(t images_ready)"
  step "$(t preseeding)"
  engine preseed || die "$(t preseed_failed)"
  # Optional services that are no longer selected (a switched torrent client,
  # usenet or VPN turned off) belong to an inactive Compose profile, which
  # `--remove-orphans` does not touch - and they would keep holding their ports.
  local svc keep
  for svc in qbittorrent transmission deluge sabnzbd gluetun; do
    keep=0
    for k in $(expected_services); do [ "$k" = "$svc" ] && keep=1; done
    if [ $keep = 0 ] && docker inspect "tortugarr-$svc" >/dev/null 2>&1; then
      run docker rm -f "tortugarr-$svc" && note "$(t service_removed "$svc")"
    fi
  done
  step "$(t starting)"
  run dc up -d --remove-orphans ${1:-} || die "$(t up_failed)"
  # A container whose first start failed (e.g. a port clash) can later show as
  # running with no network at all. Recreate any such container.
  for svc in $(expected_services); do
    local nets mode
    mode=$(docker inspect -f '{{.HostConfig.NetworkMode}}' "tortugarr-$svc" 2>/dev/null) || continue
    [[ $mode == container:* ]] && continue
    nets=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "tortugarr-$svc" 2>/dev/null)
    if [[ " $nets " != *" tortugarr "* ]]; then
      warning "$(t container_no_network "$svc")"
      run dc up -d --force-recreate --no-deps "$svc" || die "$(t up_failed)"
    fi
  done
  wait_containers 300 && good "$(t containers_running)"
}

configure_stack() {
  step "$(t configuring)"
  if engine configure; then
    good "$(t configure_ok)"
  else
    warning "$(t configure_partial)"
    return 1
  fi
}

print_access() {
  header "$(t ready)"
  local lines; lines=$(engine summary 2>/dev/null)
  local notes=()
  while IFS=$'\t' read -r kind a b; do
    case $kind in
      URL)  printf '  %-22s %s\n' "$a" "$C_BOLD$b$C_RESET" ;;
      # The password is the one the user just typed; it is not printed here
      # (sudo tortugarr credentials shows it on request).
      CRED) if [ "$a" = password ]; then printf '  %-22s %s\n' "$a" "$(t password_not_shown)"
            else printf '  %-22s %s\n' "$a" "$C_BOLD$b$C_RESET"; fi ;;
      NOTE) notes+=("$(t "note_$a" "$b")") ;;
    esac
  done <<< "$lines"
  echo
  say "$(t creds_saved "$INSTALL_DIR/secrets.json")"
  # Advice, not a warning: no colour.
  say "$(t tip_fixed_ip "$LAN_IP")"
  say "$(t app_config_saved "$INSTALL_DIR/app-config.json" "$INSTALL_DIR/download_now_secrets.dart")"
  echo
  say "$C_BOLD$(t next_steps)$C_RESET"
  say "  1. $(t next_indexers "http://$LAN_IP:$P_PROWLARR")"
  important "$(t cf_title)" "$(t cf_line1)" "$(t cf_line2)" "$(t cf_line3)"
  [ "$USENET" = true ] && say "  •  $(t next_usenet "http://$LAN_IP:$P_SABNZBD")"
  say "  2. $(t next_seerr "http://$LAN_IP:$P_SEERR")"
  say "  •  $(t next_subtitles "http://$LAN_IP:$P_BAZARR")"
  say "  3. $(t next_app "http://$LAN_IP:$P_JELLYFIN")"
  say "     $(t next_app_quickconnect "http://$LAN_IP:$P_JELLYFIN")"
  say "  •  $(t next_more_folders)"
  local n; for n in "${notes[@]}"; do warning "$n"; done
  say "  •  $(t manage_hint)"
}

# ---------------------------------------------------------------- commands

cmd_install() {
  banner
  if [ -n "$EXISTING" ]; then
    INSTALL_DIR=$EXISTING
    load_state
    warning "$(t already_installed "$INSTALL_DIR" "$INSTALLED_VERSION")"
    installed_menu
    return
  fi
  local orphans; orphans=$(orphan_containers)
  if [ -n "$orphans" ]; then
    warning "$(t orphans_found "$(echo "$orphans" | tr '\n' ' ')")"
    confirm REMOVE_ORPHANS "$(t q_remove_orphans)" y || die "$(t aborted)"
    docker rm -f $orphans >/dev/null 2>&1
  fi
  say "$(t disclaimer_short)"
  preflight
  check_foreign_stack
  install_prereqs
  ask_questions 0
  confirm_answers 0 q_start_install

  header "$(t installing)"
  install_docker
  DOCKER_MODE=engine; docker_is_desktop && DOCKER_MODE=desktop
  add_user_to_docker_group "$INVOKER"
  CREATED_JSON='{}'
  record_created docker_installed "$( [ "${STATE_DOCKER_INSTALLED_BY_US:-0}" = 1 ] && echo true || echo false)"
  record_created docker_group_user "\"${STATE_DOCKER_GROUP_ADDED:-}\""
  record_created data_dir_created "$( [ -d "$DATA_DIR" ] && echo false || echo true)"
  mkdir -p "$INSTALL_DIR"
  write_secrets_if_missing
  write_state
  TORTUGARR_MAY_CREATE_MEDIA=1 ensure_dirs
  bring_up
  configure_stack
  firewall_open
  write_state
  # The Windows side first: inside WSL the LAN ports only answer once it is set up, so the
  # health check after it shows the real state.
  offer_windows_helper
  # print_access closes with the Cloudflare box, so the health check leaves the tip to it.
  TORTUGARR_CLOSING_BOX=1 run_doctor quick
  print_access
}

# Someone else's media server or *arr on this machine: say so and let the user decide.
# Nothing found is never touched; pick_port keeps the new stack off their ports.
check_foreign_stack() {
  local found; found=$(foreign_stack)
  [ -z "$found" ] && return 0
  warning "$(t foreign_found)"
  while IFS=$'\t' read -r where what; do say "     - [$where] $what"; done <<< "$found"
  say "  $(t foreign_hands_off)"
  _log "foreign stack: $(echo "$found" | tr '\t\n' ' ;')"
  if [ "$UNATTENDED" = 1 ] && [ "${FOREIGN_OK:-n}" != y ]; then die "$(t foreign_unattended)"; fi
  confirm FOREIGN_OK "$(t q_foreign_continue)" n || die "$(t aborted)"
}

installed_menu() {
  local action
  # The Windows helper only appears inside WSL2.
  local win=()
  is_wsl && win=(windows "$(t m_windows)")
  choose action "$(t q_what_now)" repair \
    repair "$(t m_repair)" update "$(t m_update)" reconfigure "$(t m_reconfigure)" \
    backup "$(t m_backup)" restore "$(t m_restore)" status "$(t m_status)" doctor "$(t m_doctor)" \
    info "$(t m_info)" support "$(t m_support)" "${win[@]}" \
    uninstall "$(t m_uninstall)" quit "$(t m_quit)"
  case $action in
    repair) cmd_repair ;; update) cmd_update ;; reconfigure) cmd_reconfigure ;;
    backup) cmd_backup ;; restore) ask COMMAND_ARG "$(t q_restore_file)" "$(ls -1t "$INSTALL_DIR"/backups/*.tar.gz 2>/dev/null | head -1)"; cmd_restore ;;
    status) cmd_status ;; doctor) cmd_doctor ;; info) cmd_info ;; support) cmd_support ;;
    windows) COMMAND_ARG=setup; cmd_windows ;; uninstall) cmd_uninstall ;; *) exit 0 ;;
  esac
}

cmd_repair() {
  require_install
  header "$(t repairing)"
  install_prereqs
  install_docker
  local orphan_state; orphan_state=$(dc ps -a --format '{{.Name}}' 2>/dev/null | wc -l)
  note "$(t repair_containers_found "$orphan_state")"
  [ -f "$(SECRETS_FILE)" ] || die "$(t secrets_missing "$(SECRETS_FILE)")"
  ensure_dirs
  local stale; stale=$(stale_mounts)
  [ -n "$stale" ] && warning "$(t stale_mounts "$stale")"
  bring_up --force-recreate
  configure_stack
  firewall_open
  write_state
  run_doctor
}

cmd_reconfigure() {
  require_install
  # load_state filled in the current values; an answers file overrides them.
  if [ -n "$ANSWERS" ]; then
    # shellcheck disable=SC1090
    set -a; . "$ANSWERS"; set +a
  fi
  header "$(t reconfiguring)"
  ask_questions 1
  confirm_answers 1 q_apply
  step "$(t backup_first)"
  local b; b=$(make_backup quiet) && note "$(t backup_created "$b")"
  write_state
  ensure_dirs
  bring_up
  configure_stack
  firewall_open
  write_state
  # Ports may have changed: the Windows side follows (only when it was set up before) - before
  # the health check, so that checks the new forwarding.
  win_helper_set_up && offer_windows_helper
  # print_access closes with the Cloudflare box, so the health check leaves the tip to it.
  TORTUGARR_CLOSING_BOX=1 run_doctor quick
  print_access
}

cmd_update() {
  require_install
  header "$(t updating "$INSTALLED_VERSION" "$TORTUGARR_VERSION")"
  install_docker
  step "$(t backup_first)"
  local b; b=$(make_backup quiet) || die "$(t backup_failed)"
  good "$(t backup_created "$b")"
  # Remember exactly what runs now, so a failed update can go back.
  local svc id rb="$INSTALL_DIR/rollback.env.candidate"
  : > "$rb"
  for svc in $(expected_services); do
    id=$(docker inspect -f '{{.Image}}' "tortugarr-$svc" 2>/dev/null) || continue
    docker image tag "$id" "tortugarr-rollback/$svc:previous" >/dev/null 2>&1
    echo "IMAGE_${svc^^}=tortugarr-rollback/$svc:previous" >> "$rb"
  done
  rm -f "$INSTALL_DIR/rollback.env"
  if [ "$LATEST" = 1 ]; then
    warning "$(t update_latest_warning)"
    export TORTUGARR_FLOATING_IMAGES=1
  fi
  bring_up
  configure_stack
  if run_doctor quick; then
    good "$(t update_ok "$TORTUGARR_VERSION")"
    rm -f "$rb"
    write_state
  else
    warning "$(t update_problems)"
    if confirm ROLLBACK "$(t q_rollback)" y; then
      mv "$rb" "$INSTALL_DIR/rollback.env"
      write_env
      run dc up -d --remove-orphans
      # Only claim success when the previous images really run again.
      if wait_containers 240 && run_doctor skip-api >/dev/null 2>&1; then
        good "$(t rolled_back)"
      else
        error "$(t rollback_failed)"
        return 1
      fi
    fi
  fi
}

# Build a backup archive of every setting. Media files are never included.
make_backup() {
  local quiet=${1:-}
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  local work="$INSTALL_DIR/backups/.work-$ts" name="tortugarr-backup-$ts"
  local out="$INSTALL_DIR/backups/$name.tar.gz"
  mkdir -p "$work/$name"
  local w="$work/$name"
  [ -z "$quiet" ] && step "$(t backup_configs)" >&2
  rsync -a --exclude 'jellyfin-cache/' --exclude '*/cache/' --exclude '*/Cache/' --exclude '*/logs/' \
    --exclude 'jellyfin/log/' --exclude '*/transcodes/' --exclude 'logs.db*' --exclude '*.db-wal' --exclude '*.db-shm' \
    --exclude '*.pid' --exclude 'ipc-socket' "$CONFIG_DIR/" "$w/config/" 2>>"$TORTUGARR_LOG"
  [ -z "$quiet" ] && step "$(t backup_dbs)" >&2
  ENGINE_DEST=/tortugarr/backups/.work-$ts/$name/db engine backup-db >/dev/null || { [ -z "$quiet" ] && warning "$(t backup_db_warn)" >&2; }
  if [ -d "$w/db" ]; then (cd "$w/db" && find . -type f | while read -r f; do cp -f "$f" "$w/config/$f"; done); rm -rf "$w/db"; fi
  cp -a "$INSTALL_DIR/state.json" "$INSTALL_DIR/secrets.json" "$INSTALL_DIR/.env" "$w/"
  cp -a "$INSTALL_DIR/overrides" "$w/"
  [ -f "$INSTALL_DIR/app-config.json" ] && cp -a "$INSTALL_DIR/app-config.json" "$w/"
  # Exact image identity: digest + local image id per service.
  local svc img id dig
  for svc in $(expected_services); do
    img=$(docker inspect -f '{{.Config.Image}}' "tortugarr-$svc" 2>/dev/null) || continue
    id=$(docker inspect -f '{{.Image}}' "tortugarr-$svc")
    dig=$(docker image inspect -f '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' "$id" 2>/dev/null)
    printf '%s\t%s\t%s\t%s\n' "$svc" "$img" "$dig" "$id" >> "$w/images.tsv"
  done
  if [ "$WITH_IMAGES" = 1 ]; then
    [ -z "$quiet" ] && step "$(t backup_images)" >&2
    mkdir -p "$w/images"
    cut -f4 "$w/images.tsv" | sort -u | while read -r id; do
      docker save "$id" -o "$w/images/${id#sha256:}.tar" 2>>"$TORTUGARR_LOG"
    done
  fi
  jq -n --arg v "$TORTUGARR_VERSION" --arg ts "$ts" --arg host "$(hostname)" --argjson img "$WITH_IMAGES" \
    '{tortugarr_version:$v, created:$ts, host:$host, includes_images:($img==1), media_included:false}' > "$w/manifest.json"
  (cd "$w" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
  tar -C "$work" -czf "$out" "$name" 2>>"$TORTUGARR_LOG" || { rm -rf "$work"; return 1; }
  chmod 600 "$out"
  rm -rf "$work"
  # Keep the newest 10 archives.
  ls -1t "$INSTALL_DIR"/backups/tortugarr-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
  echo "$out"
}

cmd_backup() {
  require_install
  header "$(t backing_up)"
  local out; out=$(make_backup) || die "$(t backup_failed)"
  good "$(t backup_created "$out") ($(du -h "$out" | cut -f1))"
  say "$(t backup_note)"
}

cmd_restore() {
  local file=${COMMAND_ARG:-}
  [ -n "$file" ] && [ -f "$file" ] || die "$(t restore_need_file)"
  header "$(t restoring "$file")"
  local work; work=$(mktemp -d)
  tar -C "$work" -xzf "$file" || die "$(t restore_bad_archive)"
  local root; root=$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -1)
  (cd "$root" && sha256sum -c --quiet SHA256SUMS) || die "$(t restore_checksum)"
  good "$(t restore_verified)"
  jq -r '"  \(.created)  host=\(.host)  version=\(.tortugarr_version)  images=\(.includes_images)"' "$root/manifest.json"

  if [ -z "$EXISTING" ]; then
    # Restoring onto a machine without Tortugarr: rebuild from the backup's own state.
    preflight
    install_prereqs
    install_docker
    INSTALL_DIR=$(jq -r .install_dir "$root/state.json")
    mkdir -p "$INSTALL_DIR"
    cp "$root/state.json" "$root/secrets.json" "$INSTALL_DIR/"
    load_state
    ask DATA_DIR "$(t q_data_dir)" "$DATA_DIR"
    LAN_IP=$(detect_lan_ip)
  else
    INSTALL_DIR=$EXISTING
    load_state
  fi
  confirm GO "$(t q_restore_confirm "$CONFIG_DIR")" n || die "$(t aborted)"

  [ -f "$INSTALL_DIR/compose.yml" ] && run dc down --remove-orphans
  if [ -d "$CONFIG_DIR" ] && [ -n "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
    local keep; keep="$CONFIG_DIR.pre-restore-$(date +%Y%m%d-%H%M%S)"
    mv "$CONFIG_DIR" "$keep" && note "$(t restore_old_kept "$keep")"
  fi
  mkdir -p "$CONFIG_DIR"
  rsync -a "$root/config/" "$CONFIG_DIR/"
  cp -f "$root/state.json" "$root/secrets.json" "$INSTALL_DIR/"
  rm -rf "$INSTALL_DIR/overrides"; cp -a "$root/overrides" "$INSTALL_DIR/"
  if [ -d "$root/images" ]; then
    step "$(t restore_loading_images)"
    for f in "$root"/images/*.tar; do run docker load -i "$f"; done
    # Pin the exact restored images.
    : > "$INSTALL_DIR/rollback.env"
    while IFS=$'\t' read -r svc img dig id; do
      docker image tag "$id" "tortugarr-restored/$svc:backup" && echo "IMAGE_${svc^^}=tortugarr-restored/$svc:backup" >> "$INSTALL_DIR/rollback.env"
    done < "$root/images.tsv"
  fi
  rm -rf "$work"
  load_state
  local new_ip; new_ip=$(detect_lan_ip)
  if [ "$new_ip" != "$LAN_IP" ]; then
    warning "$(t restore_ip_changed "$LAN_IP" "$new_ip")"
    confirm USE_NEW_IP "$(t q_use_new_ip "$new_ip")" y && LAN_IP=$new_ip
  fi
  CREATED_JSON=${CREATED_JSON:-{\}}
  write_state
  TORTUGARR_MAY_CREATE_MEDIA=1 ensure_dirs
  bring_up --force-recreate
  # The restored settings are authoritative; configure only re-aligns addresses.
  configure_stack
  firewall_open
  write_state
  run_doctor
  good "$(t restore_done)"
}

cmd_uninstall() {
  require_install
  header "$(t uninstalling)"
  say "$(t uninstall_will_remove)"
  say "  - $(t u_containers)"
  say "  - $(t u_network)"
  jq -e '.ufw_ports | length > 0' <<< "$CREATED_JSON" >/dev/null 2>&1 && say "  - $(t u_ufw)"
  say "  - /usr/local/bin/tortugarr, /etc/tortugarr"
  is_wsl && win_helper_present && say "  - $(t u_windows)"
  say "$(t uninstall_never "$DATA_DIR")"
  echo
  local wipe=n
  if [ "$PURGE" = 1 ]; then wipe=y
  else confirm WIPE_SETTINGS "$(t q_wipe_settings "$CONFIG_DIR")" n && wipe=y; fi
  if confirm TAKE_BACKUP "$(t q_backup_first)" y; then
    local b; b=$(make_backup) && good "$(t backup_created "$b")"
    # Backups survive the uninstall even when settings are wiped.
    mkdir -p /var/backups/tortugarr && cp "$b" /var/backups/tortugarr/ && note "$(t backup_copied /var/backups/tortugarr)"
  fi
  local rm_images=n
  confirm RM_IMAGES "$(t q_remove_images)" n && rm_images=y
  confirm GO "$(t q_uninstall_confirm)" n || die "$(t aborted)"

  step "$(t stopping)"
  local images; images=$(dc config --images 2>/dev/null)
  run dc down --remove-orphans --timeout 30
  docker network rm tortugarr >/dev/null 2>&1 || true
  if [ "$rm_images" = y ]; then
    for i in $images $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^tortugarr-(rollback|restored)/'); do
      docker image rm "$i" >/dev/null 2>&1 || true
    done
    docker image rm "$IMAGE_TOOLS" >/dev/null 2>&1 || true
    # Older versions of the same images that lost their tag to a newer pull (update, or
    # --latest) stayed behind as <none> (2026-10-21: four on TVapp after an uninstall).
    local repos; repos=$(printf '%s\n' $images "$IMAGE_TOOLS" | sed -E 's/@sha256:[0-9a-f]+$//; s/:[^:/]+$//' | sort -u)
    docker images --format '{{.Repository}} {{.Tag}} {{.ID}}' | while read -r repo tag id; do
      [ "$tag" = "<none>" ] && grep -qxF "$repo" <<< "$repos" && docker image rm "$id" >/dev/null 2>&1
    done || true
    good "$(t images_removed)"
  fi
  firewall_close
  remove_windows_helper
  rm -f /usr/local/bin/tortugarr
  rm -rf /etc/tortugarr
  if [ "$wipe" = y ]; then
    # The log lives in the install dir; keep it where the backups are kept.
    mkdir -p /var/backups/tortugarr
    cp "$TORTUGARR_LOG" /var/backups/tortugarr/ 2>/dev/null && TORTUGARR_LOG=/var/backups/tortugarr/$(basename "$TORTUGARR_LOG")
    # Every backup goes along, not only the one just taken: on 2026-10-21 a backup
    # made with `tortugarr backup` minutes before was deleted with the settings.
    local kept=0 f
    for f in "$INSTALL_DIR"/backups/tortugarr-backup-*.tar.gz; do
      [ -f "$f" ] || continue
      [ -f "/var/backups/tortugarr/$(basename "$f")" ] || mv "$f" /var/backups/tortugarr/
      kept=$((kept + 1))
    done
    [ "$kept" -gt 0 ] && note "$(t backups_moved "$kept" /var/backups/tortugarr)"
    rm -rf "$CONFIG_DIR"
    rm -rf "$INSTALL_DIR"
    good "$(t settings_removed)"
  else
    rm -rf "$INSTALL_DIR/app" "$INSTALL_DIR/compose.yml"
    # Keep a way back: state/secrets/config/backups stay, and so does a copy of
    # the installer so `install.sh restore` or a reinstall can pick them up.
    good "$(t settings_kept "$INSTALL_DIR")"
  fi
  local dgu; dgu=$(jq -r '.docker_group_user // empty' <<< "$CREATED_JSON")
  [ -n "$dgu" ] && gpasswd -d "$dgu" docker >/dev/null 2>&1 && note "$(t docker_group_removed "$dgu")"
  if [ "$(jq -r '.docker_installed // false' <<< "$CREATED_JSON")" = true ]; then
    if confirm RM_DOCKER "$(t q_remove_docker)" n; then
      run apt-get purge -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
      good "$(t docker_removed)"
    fi
  fi
  good "$(t uninstall_done "$DATA_DIR")"
}

cmd_status() {
  require_install
  header "$(t status)"
  printf '  %-12s %s\n' "$(t s_version)" "$INSTALLED_VERSION" "$(t s_install_dir)" "$INSTALL_DIR" "$(t s_data_dir)" "$DATA_DIR"
  echo
  dc ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
  echo
  engine summary 2>/dev/null | while IFS=$'\t' read -r kind a b; do
    case $kind in
      URL) printf '  %-22s %s\n' "$a" "$b" ;;
      NOTE) warning "$(t "note_$a" "$b")" ;;
    esac
  done
}

cmd_credentials() {
  require_install
  engine summary 2>/dev/null | while IFS=$'\t' read -r kind a b; do printf '  %-22s %s\n' "$a" "$b"; done
  say "$(t app_config_saved "$INSTALL_DIR/app-config.json" "$INSTALL_DIR/download_now_secrets.dart")"
}

cmd_logs() {
  require_install
  dc logs --tail 200 ${COMMAND_ARG:+"$COMMAND_ARG"}
}

require_install() {
  [ -n "$EXISTING" ] || die "$(t no_install_found)"
  INSTALL_DIR=$EXISTING
  load_state
}

# ---------------------------------------------------------------- doctor

run_doctor() {
  local mode=${1:-full} fails=0 warns=0
  header "$(t doctor)"
  docker_ok && good "$(t d_docker_ok)" || { error "$(t d_docker_down)"; return 1; }
  local svc st restarts
  for svc in $(expected_services); do
    st=$(docker inspect -f '{{.State.Status}}{{if .State.Health}}/{{.State.Health.Status}}{{end}}' "tortugarr-$svc" 2>/dev/null || echo missing)
    restarts=$(docker inspect -f '{{.RestartCount}}' "tortugarr-$svc" 2>/dev/null || echo 0)
    case $st in
      running|running/healthy) good "$svc: $st" ;;
      *) error "$(t d_container_bad "$svc" "$st" "$svc")"; fails=$((fails + 1)) ;;
    esac
    [ "${restarts:-0}" -gt 3 ] && { warning "$(t d_restarts "$svc" "$restarts")"; warns=$((warns + 1)); }
  done
  local stale; stale=$(stale_mounts)
  [ -n "$stale" ] && { error "$(t stale_mounts "$stale")"; fails=$((fails + 1)); }
  local p code local_only=()
  for p in $(published_ports); do
    code=$(curl -s -o /dev/null -m 6 -w '%{http_code}' "http://$LAN_IP:$p/" 2>/dev/null)
    if [ "$code" = 000 ]; then
      code=$(curl -s -o /dev/null -m 6 -w '%{http_code}' "http://127.0.0.1:$p/" 2>/dev/null)
      if [ "$code" != 000 ]; then
        local_only+=("$p")
      else
        error "$(t d_port_dead "$p")"; fails=$((fails + 1))
      fi
    else
      good "$(t d_port_ok "$LAN_IP:$p" "$code")"
    fi
  done
  if [ ${#local_only[@]} -gt 0 ]; then
    # In WSL without the Windows side this is expected: one line, not one per port.
    if is_wsl && ! win_helper_set_up; then
      warning "$(t d_ports_wsl_unforwarded "$(IFS=,; echo "${local_only[*]}")" "$LAN_IP")"; warns=$((warns + 1))
    else
      for p in "${local_only[@]}"; do warning "$(t d_port_local_only "$p" "$LAN_IP")"; warns=$((warns + 1)); done
    fi
  fi
  local cur_ip; cur_ip=$(detect_lan_ip)
  [ "$cur_ip" != "$LAN_IP" ] && { warning "$(t d_ip_changed "$LAN_IP" "$cur_ip")"; warns=$((warns + 1)); }
  local d free pct
  for d in "$DATA_DIR" "$CONFIG_DIR"; do
    pct=$(df -P "$d" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    free=$(free_gb "$d")
    if [ "${pct:-0}" -ge 98 ]; then error "$(t d_disk_full "$d" "$pct" "$free")"; fails=$((fails + 1))
    elif [ "${pct:-0}" -ge 90 ]; then warning "$(t d_disk_low "$d" "$pct" "$free")"; warns=$((warns + 1))
    else good "$(t d_disk_ok "$d" "$free")"; fi
  done
  if [ "$TORRENT_CLIENT" = qbittorrent-ext ]; then
    # Downloads land on the user's own qBittorrent's drive: imports are copies, so free space
    # there is what decides whether the next download fits.
    local host
    while read -r host; do
      [ -n "$host" ] || continue
      if [ -d "$host" ]; then
        pct=$(df -P "$host" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
        free=$(free_gb "$host")
        if [ "${pct:-0}" -ge 95 ]; then warning "$(t d_ext_space_low "$host" "$free")"; warns=$((warns + 1))
        else good "$(t d_ext_space_ok "$host" "$free")"; fi
      else
        error "$(t ext_host_missing "$host")"; fails=$((fails + 1))
      fi
    done < <(jq -r '.mounts[]?.host_path' <<< "${EXT_QBIT_JSON:-{\}}")
  else
    # Hardlinks between downloads and library let imports be instant and use no extra space.
    local a="$DATA_DIR/torrents/.tortugarr-link-test" b="$DATA_DIR/media/.tortugarr-link-test"
    if touch "$a" 2>/dev/null && ln "$a" "$b" 2>/dev/null; then good "$(t d_hardlinks_ok)"
    else warning "$(t d_hardlinks_no)"; warns=$((warns + 1)); fi
    rm -f "$a" "$b"
  fi
  if [ "$mode" != skip-api ]; then
    engine doctor || fails=$((fails + 1))
  fi
  echo
  if [ $fails -gt 0 ]; then
    error "$(t d_result_fail "$fails" "$warns")"
    say "$(t d_try_repair)"
    return 1
  fi
  [ $warns -gt 0 ] && warning "$(t d_result_warn "$warns")" || good "$(t d_result_ok)"
  return 0
}

cmd_doctor() { require_install; run_doctor; windows_helper_status; }

# The end screen again: addresses, user name, what is left to do (the password is not shown).
cmd_info() { require_install; print_access; }

# The optional Windows helper, inside WSL2 only.
cmd_windows() {
  require_install
  is_wsl || die "$(t win_only_wsl)"
  case "${COMMAND_ARG:-setup}" in
    setup) offer_windows_helper ;;
    status) windows_helper_status ;;
    remove) remove_windows_helper ;;
    *) die "$(t win_usage)" ;;
  esac
}

cmd_help() {
  sed -n '2,20p' "$TORTUGARR_APP/install.sh" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------- dispatch

case "${COMMAND:-}" in
  ""|install) cmd_install ;;
  repair) cmd_repair ;;
  update) cmd_update ;;
  reconfigure) cmd_reconfigure ;;
  backup) cmd_backup ;;
  restore) cmd_restore ;;
  uninstall|remove) cmd_uninstall ;;
  status) cmd_status ;;
  doctor) cmd_doctor ;;
  windows) cmd_windows ;;
  info) cmd_info ;;
  support) cmd_support ;;
  credentials) cmd_credentials ;;
  logs) cmd_logs ;;
  help) cmd_help ;;
  *) error "Unknown command: $COMMAND"; cmd_help; exit 2 ;;
esac
