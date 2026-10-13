# shellcheck shell=bash
# System detection: OS, WSL, systemd, network, ports, disks, existing installs.

# A WSL kernel alone is not enough: containers and VMs on a WSL host share it.
# The interop handler / distro name only exist inside a real WSL distro.
is_wsl() {
  case "${TORTUGARR_PLATFORM:-}" in wsl) return 0 ;; linux) return 1 ;; esac
  grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null || return 1
  [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -e /proc/sys/fs/binfmt_misc/WSLInterop-late ] || [ -n "${WSL_DISTRO_NAME:-}" ]
}

has_systemd() { [ "$(ps -p 1 -o comm= 2>/dev/null)" = systemd ]; }

os_id()      { . /etc/os-release 2>/dev/null && echo "${ID:-unknown}"; }
os_version() { . /etc/os-release 2>/dev/null && echo "${VERSION_ID:-0}"; }
os_pretty()  { . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}"; }

arch() {
  case "$(uname -m)" in x86_64|amd64) echo amd64 ;; aarch64|arm64) echo arm64 ;; *) uname -m ;; esac
}

# Windows programs by full path: under sudo, PATH (secure_path) has no /mnt/c, so a plain
# `powershell.exe` is not found and every Windows-side check silently did nothing.
WIN_PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
WIN_WSL=/mnt/c/Windows/System32/wsl.exe

# The address other devices on the LAN use to reach this machine.
# Inside WSL2 that is the Windows host's LAN address, not the WSL one.
detect_lan_ip() {
  local ip=""
  if is_wsl && [ -x "$WIN_PS" ]; then
    ip=$("$WIN_PS" -NoProfile -Command \
      "(Get-NetIPConfiguration | Where-Object { \$_.IPv4DefaultGateway -ne \$null -and \$_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1).IPv4Address.IPAddress" \
      2>/dev/null | tr -d '\r' | head -1)
  fi
  if [ -z "$ip" ]; then
    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
  fi
  [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo "${ip:-127.0.0.1}"
}

# 0 when something already listens on the TCP port (on this host or, in WSL, on Windows).
port_in_use() {
  local p=$1
  if command -v ss >/dev/null 2>&1 && ss -Hltn "sport = :$p" 2>/dev/null | grep -q .; then return 0; fi
  if is_wsl && [ -x "$WIN_PS" ]; then
    "$WIN_PS" -NoProfile -Command "if (Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# Which of our own containers owns a port, if any (so repair does not flag its own ports).
port_owner_is_tortugarr() {
  docker ps --filter "label=com.docker.compose.project=tortugarr" --format '{{.Ports}}' 2>/dev/null | grep -q ":$1->"
}

free_gb() { df -Pk "$1" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}'; }

# Filesystem type of the directory (or its nearest existing parent).
fs_type() {
  local d=$1
  while [ ! -e "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
  stat -f -c %T "$d" 2>/dev/null
}

# Network/9p filesystems: no inotify and no hardlinks across the boundary.
is_slow_fs() {
  case "$(fs_type "$1")" in 9p|v9fs|cifs|smb2|smb3|nfs|fuseblk|fuse*) return 0 ;; *) return 1 ;; esac
}

total_ram_gb() { awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo; }

has_dri() { [ -d /dev/dri ] && ls /dev/dri/renderD* >/dev/null 2>&1; }

# Where the state of an existing installation lives, or empty.
find_existing_install() {
  local p
  if [ -f /etc/tortugarr/install-dir ]; then
    p=$(cat /etc/tortugarr/install-dir)
    [ -f "$p/state.json" ] && { echo "$p"; return; }
  fi
  for p in /opt/tortugarr "${TORTUGARR_HOME:-}"; do
    [ -n "$p" ] && [ -f "$p/state.json" ] && { echo "$p"; return; }
  done
}

# Containers of a tortugarr project that exist even though no state file does
# (a half-finished install or a deleted install directory).
orphan_containers() {
  docker ps -a --filter "label=com.docker.compose.project=tortugarr" --format '{{.Names}}' 2>/dev/null
}

# Media servers and download tools that belong to someone else's setup. The installer
# never reuses or changes them; it only has to know they are there, so it can stay
# off their ports and tell the user. One line per finding: "where<TAB>what".
FOREIGN_PATTERN='jellyfin|emby|plex|sonarr|radarr|lidarr|readarr|prowlarr|jackett|overseerr|jellyseerr|seerr|bazarr|qbittorrent|transmission|deluge|sabnzbd|nzbget'

foreign_containers() {
  command -v docker >/dev/null 2>&1 || return 0
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Label "com.docker.compose.project"}}\t{{.Ports}}' 2>/dev/null |
    awk -F'\t' -v pat="$FOREIGN_PATTERN" 'tolower($2) ~ pat && $3 != "tortugarr" {
      printf "docker\t%s (%s) %s\n", $1, $2, $4 }'
}

# Programs installed straight on this Linux system (processes running inside a
# container are covered by foreign_containers).
foreign_processes() {
  local pid comm
  for pid in $(pgrep -i "$FOREIGN_PATTERN" 2>/dev/null); do
    grep -qE 'docker|containerd|kubepods' "/proc/$pid/cgroup" 2>/dev/null && continue
    comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
    printf 'linux\t%s (pid %s)\n' "$comm" "$pid"
  done | sort -u -t$'\t' -k2,2
}

# On WSL: programs and services on the Windows side, and other running WSL distros.
# All WSL2 distros share one network, so a stack in another distro holds the same
# ports as one here.
foreign_windows() {
  is_wsl || return 0
  if [ -x "$WIN_PS" ]; then
    "$WIN_PS" -NoProfile -Command "
      \$p = '$FOREIGN_PATTERN'
      Get-Process -ErrorAction SilentlyContinue | Where-Object { \$_.ProcessName -match \$p } |
        Sort-Object ProcessName -Unique | ForEach-Object { 'windows' + [char]9 + \$_.ProcessName + ' (program)' }
      Get-Service -ErrorAction SilentlyContinue | Where-Object { \$_.Status -eq 'Running' -and \$_.Name -match \$p } |
        ForEach-Object { 'windows' + [char]9 + \$_.Name + ' (service)' }" 2>/dev/null | tr -d '\r'
  fi
  if [ -x "$WIN_WSL" ]; then
    "$WIN_WSL" -l --running -q 2>/dev/null | tr -d '\r\0' | grep -v '^\s*$' |
      grep -vxF "$(wsl_distro_name)" | grep -viE '^docker-desktop' |
      sed 's/^/wsl\t/; s/$/ (another running WSL distro - shares this network)/'
  fi
}

foreign_stack() { foreign_containers; foreign_processes; foreign_windows; }

# Works before curl is installed: a plain TCP connect to the Docker registry.
internet_ok() {
  if command -v curl >/dev/null 2>&1; then
    local code; code=$(curl -sS -m 10 -o /dev/null -w '%{http_code}' https://registry-1.docker.io/v2/ 2>/dev/null)
    case "$code" in 200|401) return 0 ;; esac
  fi
  timeout 10 bash -c '</dev/tcp/registry-1.docker.io/443' 2>/dev/null
}
