# shellcheck shell=bash
# Docker Engine installation and checks (Ubuntu / Debian, native or WSL2).

docker_ok() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
compose_ok() { docker compose version >/dev/null 2>&1; }

compose_version_ok() {
  # `!reset` in override files needs Compose 2.24 or newer.
  local v
  v=$(docker compose version --short 2>/dev/null | sed 's/^v//')
  [ -n "$v" ] || return 1
  [ "$(printf '%s\n2.24.0\n' "$v" | sort -V | head -1)" = 2.24.0 ]
}

# Docker Desktop's integration inside WSL looks like a working engine but is not
# ours to manage; installing a second engine next to it breaks both.
docker_is_desktop() {
  docker info --format '{{.OperatingSystem}}' 2>/dev/null | grep -qi 'docker desktop'
}

install_prereqs() {
  local missing=()
  for c in curl jq ca-certificates gnupg; do
    case $c in
      ca-certificates) [ -d /etc/ssl/certs ] || missing+=("$c") ;;
      *) command -v "$c" >/dev/null 2>&1 || missing+=("$c") ;;
    esac
  done
  command -v ss >/dev/null 2>&1 || missing+=(iproute2)
  command -v rsync >/dev/null 2>&1 || missing+=(rsync)
  [ ${#missing[@]} -eq 0 ] && return 0
  step "$(t installing_packages "${missing[*]}")"
  run apt-get update -qq || die "$(t apt_failed)"
  DEBIAN_FRONTEND=noninteractive run apt-get install -y -qq "${missing[@]}" || die "$(t apt_failed)"
}

install_docker() {
  if docker_ok; then
    if docker_is_desktop; then
      warning "$(t docker_desktop_detected)"
    fi
    compose_ok || die "$(t compose_missing)"
    compose_version_ok || die "$(t compose_too_old "$(docker compose version --short)")"
    good "$(t docker_present "$(docker version --format '{{.Server.Version}}' 2>/dev/null)")"
    return 0
  fi
  if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
    # Installed but not running.
    if has_systemd; then
      run systemctl enable --now docker && docker_ok && { good "$(t docker_started)"; return 0; }
    fi
    die "$(t docker_not_running)"
  fi
  local id; id=$(os_id)
  case "$id" in ubuntu|debian) ;; *) die "$(t docker_unsupported_os "$(os_pretty)")" ;; esac
  step "$(t docker_installing)"
  install -m 0755 -d /etc/apt/keyrings
  run curl -fsSL "https://download.docker.com/linux/$id/gpg" -o /etc/apt/keyrings/docker.asc || die "$(t docker_install_failed)"
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  local codename; codename=$(. /etc/os-release && echo "${VERSION_CODENAME}")
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$id $codename stable" \
    > /etc/apt/sources.list.d/docker.list
  run apt-get update -qq || die "$(t docker_install_failed)"
  DEBIAN_FRONTEND=noninteractive run apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin || die "$(t docker_install_failed)"
  if has_systemd; then
    run systemctl enable --now docker containerd || die "$(t docker_not_running)"
  else
    die "$(t systemd_required)"
  fi
  docker_ok || die "$(t docker_not_running)"
  STATE_DOCKER_INSTALLED_BY_US=1
  good "$(t docker_installed "$(docker version --format '{{.Server.Version}}')")"
}

# Let the invoking (non-root) user use docker without sudo.
add_user_to_docker_group() {
  local u=$1
  [ -z "$u" ] || [ "$u" = root ] && return 0
  id -nG "$u" | grep -qw docker && return 0
  run usermod -aG docker "$u" && STATE_DOCKER_GROUP_ADDED=$u && note "$(t docker_group_added "$u")"
}
