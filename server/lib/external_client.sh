# shellcheck shell=bash
# A qBittorrent that is already installed outside the stack (on the Windows host under WSL,
# on a NAS, ...): TORRENT_CLIENT=qbittorrent-ext. No container is started for it. Radarr and
# Sonarr reach it by address, and read its finished downloads through folders mounted into
# them, with Remote Path Mappings from qBittorrent's paths (H:\Downloads\radarr\) to the
# mounted ones (/data/torrents-ext/1/radarr/).
#
# State: external_qbit = {url, username, mounts: [{remote, host_path, container_path}]}
# Secret: external_qbit_password in secrets.json.

EXT_MOUNT_BASE=/data/torrents-ext

# A torrent client that runs as a container of this stack.
client_in_stack() {
  case "${1:-$TORRENT_CLIENT}" in qbittorrent|transmission|deluge) return 0 ;; *) return 1 ;; esac
}

# H:\Downloads\ or H:/Downloads -> /mnt/h/Downloads (WSL's drvfs mount). Anything else is
# returned unchanged (a Linux path on this machine, or a share mounted at the same path).
ext_host_path_for() {
  local p=$1
  if [[ $p =~ ^([A-Za-z]):[\\/]*(.*)$ ]]; then
    local drive=${BASH_REMATCH[1],,} rest=${BASH_REMATCH[2]//\\//}
    rest=${rest%/}
    if [ -n "$rest" ]; then echo "/mnt/$drive/$rest"; else echo "/mnt/$drive"; fi
  else
    p=${p//\\//}; echo "${p%/}"
  fi
}

# The folder qBittorrent itself uses, written its way, with one trailing separator - the form
# Radarr and Sonarr compare remote paths in.
ext_remote_root() {
  local p=$1 sep=/
  if [[ $p =~ ^[A-Za-z]: ]]; then
    # qBittorrent reports torrent paths on Windows with backslashes, whatever the setting says.
    sep='\'; p=${p//\//\\}
  fi
  p=${p%[\\/]}
  printf '%s%s' "$p" "$sep"
}

# curl against the external qBittorrent, logged in when a user name is set. Uses a cookie jar
# in $EXT_JAR.
ext_qbit_api() {  # path
  curl -fsS -m 10 -b "$EXT_JAR" -c "$EXT_JAR" -H "Referer: $EXT_QBIT_URL" "$EXT_QBIT_URL$1"
}

ext_qbit_login() {
  EXT_JAR=$(mktemp)
  if [ -n "${EXT_QBIT_USER:-}" ]; then
    local r
    r=$(curl -sS -m 10 -c "$EXT_JAR" -H "Referer: $EXT_QBIT_URL" \
          --data-urlencode "username=$EXT_QBIT_USER" --data-urlencode "password=${EXT_QBIT_PASSWORD:-}" \
          "$EXT_QBIT_URL/api/v2/auth/login" 2>/dev/null) || return 2
    [[ $r == *Fails* ]] && return 3
  fi
  ext_qbit_api /api/v2/app/version >/dev/null 2>&1 || return 4
}

# Builds EXT_QBIT_JSON (url, username, mounts) from the running qBittorrent: its default save
# folder and the folders of the radarr and sonarr categories, each mounted once.
ext_qbit_discover() {
  local prefs cats
  prefs=$(ext_qbit_api /api/v2/app/preferences) || return 1
  cats=$(ext_qbit_api /api/v2/torrents/categories) || cats='{}'
  local -a roots=()
  local save; save=$(jq -r '.save_path // empty' <<< "$prefs")
  [ -n "$save" ] && roots+=("$save")
  local c p
  for c in radarr sonarr; do
    p=$(jq -r --arg c "$c" '.[$c].savePath // empty' <<< "$cats")
    [ -z "$p" ] && continue
    # A category folder under the save folder is covered by that mount already.
    local under=0 r np nr
    np=${p//\\//}; np=${np,,}
    for r in "${roots[@]}"; do
      nr=${r//\\//}; nr=${nr,,}; nr=${nr%/}
      [[ $np == "$nr" || $np == "$nr/"* ]] && under=1
    done
    [ $under = 0 ] && roots+=("$p")
  done
  [ ${#roots[@]} -gt 0 ] || return 1
  EXT_ROOTS=("${roots[@]}")
  ext_build_json
}

# Adds a client path to the named array unless a folder with the same place (ignoring case and
# the trailing separator) is in it already.
ext_add_root() {  # array-name client-path
  local -n arr=$1
  local new; new=$(ext_host_path_for "$2"); new=${new,,}
  local r
  for r in "${arr[@]}"; do [ "$(ext_host_path_for "$r" | tr '[:upper:]' '[:lower:]')" = "$new" ] && return 0; done
  arr+=("$2")
}

# EXT_QBIT_JSON from EXT_ROOTS: one mount per download folder, numbered in order.
ext_build_json() {
  local mounts='[]' n=0 r
  for r in "${EXT_ROOTS[@]}"; do
    n=$((n + 1))
    mounts=$(jq -c --arg remote "$(ext_remote_root "$r")" --arg host "$(ext_host_path_for "$r")" \
      --arg ctr "$EXT_MOUNT_BASE/$n" '. + [{remote:$remote, host_path:$host, container_path:$ctr}]' <<< "$mounts")
  done
  EXT_QBIT_JSON=$(jq -nc --arg url "$EXT_QBIT_URL" --arg user "${EXT_QBIT_USER:-}" --argjson m "$mounts" \
    '{url:$url, username:$user, mounts:$m}')
}

# Asks about every other Windows drive as a download folder too. Nothing is used without a yes:
# the default is yes only for a drive chosen last time. Drive C: and drives with less than
# 20 GB free (unless chosen before) are not offered. X:\\Downloads\\radarr and \\sonarr are created
# after the summary is confirmed (write_external_client_override).
ext_offer_more_drives() {
  local before="${EXT_QBIT_PREVIOUS:-{\}}" d free letter used def r
  for d in /mnt/[a-z]; do
    letter=${d#/mnt/}
    [ "$letter" = c ] && continue
    [ -d "$d" ] || continue
    used=0
    for r in "${EXT_ROOTS[@]}"; do [ "$(ext_host_path_for "$r" | cut -d/ -f3)" = "$letter" ] && used=1; done
    [ $used = 1 ] && continue
    def=n
    jq -e --arg p "/mnt/$letter/" 'any(.mounts[]?; (.host_path + "/") | startswith($p))' <<< "$before" >/dev/null 2>&1 && def=y
    free=$(free_gb "$d")
    [ "$def" = y ] || [ "${free:-0}" -ge 20 ] || continue
    if confirm "EXT_DRIVE_${letter^^}" "$(t q_ext_more_drive "${letter^^}" "$free" "${letter^^}:\\Downloads\\radarr + sonarr")" "$def"; then
      EXT_ROOTS+=("${letter^^}:\\Downloads")
    fi
  done
  ext_build_json
}

ask_external_qbit() {
  say "$(t ext_intro)"
  EXT_QBIT_PREVIOUS=${EXT_QBIT_JSON:-{\}}
  local def="${EXT_QBIT_URL:-$(jq -r '.url // empty' <<< "${EXT_QBIT_JSON:-{\}}")}"
  [ -z "$def" ] && def="http://$(detect_lan_ip):8080"
  while :; do
    ask EXT_QBIT_URL "$(t q_ext_url)" "$def"
    EXT_QBIT_URL=${EXT_QBIT_URL%/}
    ask EXT_QBIT_USER "$(t q_ext_user)" "${EXT_QBIT_USER:-$(jq -r '.username // empty' <<< "${EXT_QBIT_JSON:-{\}}")}"
    if [ -n "$EXT_QBIT_USER" ] && [ "$UNATTENDED" != 1 ]; then
      read -r -s -p "$(printf '%s? %s%s: ' "$C_BOLD" "$(t q_ext_password)" "$C_RESET")" EXT_QBIT_PASSWORD </dev/tty; echo
    fi
    local rc=0; ext_qbit_login || rc=$?
    case $rc in
      0) good "$(t ext_connected "$EXT_QBIT_URL")"; break ;;
      2) warning "$(t ext_unreachable "$EXT_QBIT_URL")" ;;
      3) warning "$(t ext_login_refused)" ;;
      *) warning "$(t ext_forbidden)" ;;
    esac
    [ "$UNATTENDED" = 1 ] && die "$(t ext_failed_unattended)"
    def=$EXT_QBIT_URL
  done
  ext_qbit_discover || die "$(t ext_no_paths)"
  is_wsl && ext_offer_more_drives
  local m host
  while read -r m; do
    host=$(jq -r .host_path <<< "$m")
    note "$(t ext_mount "$(jq -r .remote <<< "$m")" "$host" "$(jq -r .container_path <<< "$m")")"
    [ -d "$host" ] || warning "$(t ext_host_missing "$host")"
  done < <(jq -c '.mounts[]' <<< "$EXT_QBIT_JSON")
  say "$(t ext_copy_note)"
}

# Compose override: the external client's folders, read-write for the *arrs that import from
# them. Regenerated on repair.
write_external_client_override() {  # overrides-dir
  local o=$1
  rm -f "$o/download-client.yml"
  [ "$TORRENT_CLIENT" = qbittorrent-ext ] || return 1
  # Download folders on drives the user added: make their radarr and sonarr folders now.
  local host
  while read -r host; do
    [ -n "$host" ] || continue
    mkdir -p "$host/radarr" "$host/sonarr" 2>/dev/null || warning "$(t ext_drive_failed "$host")"
  done < <(jq -r '.mounts[].host_path' <<< "$EXT_QBIT_JSON")
  # Jellyfin gets them read-only: the Tortugarr plugin runs there and picks the folder with the
  # most free space for each download.
  jq -r '
    "# Generated: the folders of the qBittorrent outside the stack. Regenerated on repair.",
    "services:",
    ( ["sonarr", "radarr", "jellyfin"][] as $s
      | "  \($s):", "    volumes:",
        ( .mounts[] | "      - \"\(.host_path):\(.container_path)\(if $s == "jellyfin" then ":ro" else "" end)\"" ) )
  ' <<< "$EXT_QBIT_JSON" > "$o/download-client.yml"
}
