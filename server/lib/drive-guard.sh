#!/bin/bash
# Drive guard for Tortugarr inside WSL2. A systemd timer runs it every minute as root.
#
# Why: after a Windows restart a drive the containers read (/mnt/<letter>) can be missing
# (never mounted, Docker then makes an empty folder in its place) or dead (a 9p mount
# that returns "No such device"). On 2026-11-13 this happened to I: and H: on TVapp.
# Radarr could not see finished downloads, called them failed imports, and the fake
# sweeper deleted two complete films (the sweeper itself is fixed in the plugin).
#
# What it does, per /mnt/<letter> that a running tortugarr-* container binds:
#   1. Drive missing or dead: lazy-unmount, mount it again with drvfs.
#   2. A container that started before the drive was there still sees the empty folder
#      underneath (bind mounts do not follow a later mount). Restart such containers,
#      and every container of a drive that was just remounted.
# It never deletes anything and never touches a drive no container uses.
#
# Usage: drive-guard.sh [--check] [uid] [gid]
#   --check  only report problems (one line each, nothing changed); exit 1 if any.
set -u

check=0
[ "${1:-}" = --check ] && { check=1; shift; }
uid=${1:-1000} gid=${2:-1000}
state=${TORTUGARR_GUARD_STATE:-/run/tortugarr-drive-guard}
problems=0

say() { echo "$*"; }
problem() { problems=$((problems + 1)); say "$*"; }

# A drive is usable when something is mounted there and its root answers within 5 s.
usable() { mountpoint -q "$1" 2>/dev/null && timeout 5 stat -t "$1/." >/dev/null 2>&1; }

# Restart a container at most once per 10 minutes, so a fault a restart does not fix
# cannot turn into a restart loop.
restart_container() {
  local c=$1 why=$2 stamp="$state/restart-$1" now; now=$(date +%s)
  if [ -f "$stamp" ] && [ $((now - $(cat "$stamp"))) -lt 600 ]; then
    say "$c: $why - restarted less than 10 minutes ago, waiting"
    return
  fi
  echo "$now" > "$stamp"
  if docker restart "$c" >/dev/null 2>&1; then say "$c: $why - restarted"; else say "$c: $why - restart FAILED"; fi
}

command -v docker >/dev/null && docker info >/dev/null 2>&1 || exit 0
[ $check = 1 ] || mkdir -p "$state"

# /mnt/<letter> -> lines of "container|destination" for every bind mount below it.
declare -A users=()
for c in $(docker ps --format '{{.Names}}' | grep '^tortugarr-'); do
  while IFS=$'\t' read -r src dst; do
    [[ $src =~ ^(/mnt/[a-z])(/|$) ]] || continue
    users[${BASH_REMATCH[1]}]+="$c|$dst"$'\n'
  done < <(docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{"\t"}}{{.Destination}}{{"\n"}}{{end}}{{end}}' "$c" 2>/dev/null)
done

declare -A to_restart=()
for m in "${!users[@]}"; do
  remounted=0
  if ! usable "$m"; then
    drive="${m#/mnt/}"; drive="${drive^^}:"
    if [ $check = 1 ]; then problem "$m ($drive) is not connected"; continue; fi
    say "$m ($drive) is not connected - connecting it again"
    umount -l "$m" 2>/dev/null
    mkdir -p "$m"
    if mount -t drvfs "$drive" "$m" -o "uid=$uid,gid=$gid" 2>/dev/null && usable "$m"; then
      say "$m ($drive) connected"
      remounted=1
    else
      umount -l "$m" 2>/dev/null
      say "$m ($drive) is still missing (drive not attached in Windows?) - trying again in a minute"
      continue
    fi
  fi
  host_fs=$(stat -f -c %t "$m" 2>/dev/null)
  while IFS='|' read -r c dst; do
    [ -n "$c" ] || continue
    if [ $remounted = 1 ]; then to_restart[$c]="$m was remounted"; continue; fi
    # The container sees the drive when its folder is on the same kind of file system as
    # the drive. When `stat` fails for the folder but works for / the bind is dead; when
    # it fails for both the image has no stat and we cannot tell, so leave it alone.
    seen=$(docker exec "$c" stat -f -c %t "$dst" 2>/dev/null </dev/null)
    if [ -z "$seen" ]; then
      docker exec "$c" stat -f -c %t / >/dev/null 2>&1 </dev/null || continue
    elif [ "$seen" = "$host_fs" ]; then
      continue
    fi
    if [ $check = 1 ]; then problem "$c does not see $m at $dst (started before the drive was connected)"
    else to_restart[$c]="does not see $m at $dst"; fi
  done <<< "${users[$m]}"
done

for c in "${!to_restart[@]}"; do restart_container "$c" "${to_restart[$c]}"; done
[ $check = 1 ] && [ $problems -gt 0 ] && exit 1
exit 0
