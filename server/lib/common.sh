# shellcheck shell=bash
# Shared helpers: output, logging, translation, prompts.

# ---------------------------------------------------------------- output

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
  C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

TORTUGARR_LOG=${TORTUGARR_LOG:-/tmp/tortugarr-install.log}

_log() { { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$TORTUGARR_LOG"; } 2>/dev/null || true; }

say()     { printf '%s\n' "$*"; _log "$*"; }
header()  { printf '\n%s== %s ==%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"; _log "== $*"; }
step()    { printf '%s->%s %s\n' "$C_BLUE" "$C_RESET" "$*"; _log "-> $*"; }
good()    { printf '%s  ok%s  %s\n' "$C_GREEN" "$C_RESET" "$*"; _log "ok $*"; }
note()    { printf '%s  ..%s  %s\n' "$C_DIM" "$C_RESET" "$*"; _log ".. $*"; }
warning() { printf '%s  !!%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; _log "WARN $*"; }
error()   { printf '%s  xx%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; _log "ERROR $*"; }
die()     { error "$*"; say "$(t log_hint "$TORTUGARR_LOG")"; exit 1; }

# important "title" "line" ... - a framed block in its own colour, for what must not be
# missed among the other lines (2026-10-21: the FlareSolverr tag for 1337x).
important() {
  local title=$1 line; shift
  printf '\n%s  ┏━ %s %s\n' "$C_BOLD$C_CYAN" "$title" "$C_RESET"
  for line in "$@"; do printf '%s  ┃%s %s\n' "$C_BOLD$C_CYAN" "$C_RESET$C_BOLD" "$line$C_RESET"; done
  printf '%s  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$C_BOLD$C_CYAN" "$C_RESET"
  _log "IMPORTANT $title: $*"
}

# Run a command, log its output, and show it only when it fails.
run() {
  _log "\$ $*"
  local out rc
  out=$("$@" 2>&1); rc=$?
  { printf '%s\n' "$out" >> "$TORTUGARR_LOG"; } 2>/dev/null || true
  if [ $rc -ne 0 ]; then
    printf '%s\n' "$out" | tail -20 >&2
  fi
  return $rc
}

# Render the TAB-separated lines the bootstrap engine prints.
render_engine_output() {
  local rc=0 level msg
  while IFS=$'\t' read -r level msg; do
    case "$level" in
      OK)   good "$msg" ;;
      INFO) note "$msg" ;;
      WARN) warning "$msg" ;;
      IMPORTANT) printf '%s  >>  %s%s\n' "$C_BOLD$C_CYAN" "$msg" "$C_RESET"; _log "IMPORTANT $msg" ;;
      FAIL) error "$msg"; rc=1 ;;
      URL|CRED|NOTE) printf '%s\t%s\n' "$level" "$msg" ;;
      *)    [ -n "$level$msg" ] && note "$level $msg" ;;
    esac
  done
  return $rc
}

# ---------------------------------------------------------------- translation
#
# Every user-facing string lives in i18n/<lang>.sh as MSG[key]="...". English is
# always loaded first, so a missing translation falls back to English instead of
# printing a key.

declare -gA MSG=()
TORTUGARR_LANGS=(en nb sv da de)

load_language() {
  local lang=${1:-en}
  MSG=()
  # shellcheck disable=SC1090,SC1091
  source "$TORTUGARR_APP/i18n/en.sh"
  if [ "$lang" != "en" ] && [ -f "$TORTUGARR_APP/i18n/$lang.sh" ]; then
    # shellcheck disable=SC1090
    source "$TORTUGARR_APP/i18n/$lang.sh"
  fi
  TORTUGARR_LANG=$lang
}

t() {
  local key=$1; shift
  local fmt=${MSG[$key]:-$key}
  # shellcheck disable=SC2059
  printf "$fmt" "$@"
}

# ---------------------------------------------------------------- prompts
#
# In unattended mode (--answers FILE or --yes) every prompt takes its answer from
# the variable named in its first argument, falling back to the default.

UNATTENDED=${UNATTENDED:-0}

# Answers are typed with line editing (readline): the arrow keys move through the text, and
# arrow up brings back earlier answers. They are kept in memory only (no history file), and
# secret answers stay out. History is on only while a line is read, so the script's own
# commands never end up in it.
_ANSWERS=()

# Colour codes in a readline prompt are wrapped, or editing puts the cursor in the wrong place.
_rl() { [ -z "$1" ] || printf '\001%s\002' "$1"; }

# read_answer VAR "prompt" NAME - one line from the terminal; NAME decides if it is remembered.
read_answer() {
  local __var=$1 __prompt=$2 __name=${3:-} __ans __a HISTFILE=
  set -o history
  history -c
  for __a in "${_ANSWERS[@]}"; do history -s -- "$__a"; done
  if ! read -e -r -p "$__prompt" __ans </dev/tty; then
    set +o history
    return 1 # no terminal any more (closed input): as a plain read failed
  fi
  set +o history
  if [ -n "$__ans" ] && ! [[ ${__name^^} =~ PASS|KEY|SECRET|TOKEN ]]; then
    _ANSWERS+=("$__ans")
  fi
  printf -v "$__var" '%s' "$__ans"
}

# ask VAR "question" "default"
ask() {
  local var=$1 q=$2 def=${3:-} ans
  if [ "$UNATTENDED" = 1 ]; then
    ans=${!var:-$def}
    note "$q: $ans"
  else
    if [ -n "$def" ]; then
      read_answer ans "$(printf '%s? %s%s [%s]: ' "$(_rl "$C_BOLD")" "$q" "$(_rl "$C_RESET")" "$def")" "$var"
    else
      read_answer ans "$(printf '%s? %s%s: ' "$(_rl "$C_BOLD")" "$q" "$(_rl "$C_RESET")")" "$var"
    fi
    ans=${ans:-$def}
  fi
  printf -v "$var" '%s' "$ans"
  _log "answer $var=$( [[ $var == *PASS* ]] && echo '***' || echo "$ans")"
}

# confirm VAR "question" default(y|n) -> returns 0 for yes
confirm() {
  local var=$1 q=$2 def=${3:-y} ans
  if [ "$UNATTENDED" = 1 ]; then
    ans=${!var:-$def}
  else
    local hint="[Y/n]"; [ "$def" = n ] && hint="[y/N]"
    read_answer ans "$(printf '%s? %s%s %s: ' "$(_rl "$C_BOLD")" "$q" "$(_rl "$C_RESET")" "$hint")" "$var"
    ans=${ans:-$def}
  fi
  while :; do
    case "${ans,,}" in
      y|yes|j|ja|1|true) printf -v "$var" y; return 0 ;;
      n|no|nei|nej|nein|0|false) printf -v "$var" n; return 1 ;;
    esac
    # Anything else used to count as "no" without a word; ask again instead.
    [ "$UNATTENDED" = 1 ] && die "$(t answer_not_yes_no "$var" "$ans")"
    warning "$(t answer_yes_no)"
    read_answer ans "$(printf '%s? %s%s %s: ' "$(_rl "$C_BOLD")" "$q" "$(_rl "$C_RESET")" "$hint")" "$var"
    ans=${ans:-$def}
  done
}

# choose VAR "question" default option1 "label1" option2 "label2" ...
choose() {
  local var=$1 q=$2 def=$3; shift 3
  local -a keys=() labels=()
  while [ $# -gt 0 ]; do keys+=("$1"); labels+=("$2"); shift 2; done
  if [ "$UNATTENDED" = 1 ]; then
    local v=${!var:-$def} k
    for k in "${keys[@]}"; do [ "$k" = "$v" ] && { printf -v "$var" '%s' "$v"; note "$q: $v"; return; }; done
    die "$(t choice_invalid_unattended "$var" "$v" "${keys[*]}")"
  fi
  say "${C_BOLD}? $q${C_RESET}"
  local i defn=1
  for i in "${!keys[@]}"; do
    [ "${keys[$i]}" = "$def" ] && defn=$((i + 1))
    printf '   %d) %s\n' $((i + 1)) "${labels[$i]}"
  done
  local ans
  while :; do
    read_answer ans "   [$defn]: " "$var"
    ans=${ans:-$defn}
    if [[ $ans =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le ${#keys[@]} ]; then
      printf -v "$var" '%s' "${keys[$((ans - 1))]}"; _log "answer $var=${keys[$((ans - 1))]}"; return
    fi
  done
}

# Login names that work in every service (Jellyfin, Seerr, the *arrs, the download clients).
valid_username() { [[ $1 =~ ^[A-Za-z0-9._-]{3,32}$ ]]; }
# The password also goes into the stack's .env file (single-quoted there), so no
# whitespace, quotes or backslashes - everything else is fine.
valid_password() { [ ${#1} -ge 8 ] && [[ ! $1 =~ [[:space:]\'\"\\] ]]; }

# ask_valid VAR "question" default check message-key - asks again until "check <answer>" passes.
ask_valid() {
  local var=$1 q=$2 def=$3 check=$4 msg=$5
  while :; do
    ask "$var" "$q" "$def"
    "$check" "${!var}" && return 0
    [ "$UNATTENDED" = 1 ] && die "$(t value_invalid_unattended "$var" "${!var}")"
    warning "$(t "$msg" "${!var}")"
    def=$3
  done
}

# An address other devices can use: an IPv4 address, or a host name with a domain
# (server.local, nas.lan) - a bare word like "n" or "yes" is not accepted.
valid_host() {
  local h=$1 o
  if [[ $h =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    for o in "${BASH_REMATCH[@]:1}"; do [ "$o" -le 255 ] || return 1; done
    return 0
  fi
  [ ${#h} -le 253 ] && [[ $h == *.* ]] && [[ $h =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z][A-Za-z0-9-]{0,61}[A-Za-z0-9]$ ]]
}

# A real time zone (Europe/Oslo, UTC), checked against the system's zone database.
valid_tz() {
  [[ $1 =~ ^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+)*$ ]] || return 1
  if [ -d /usr/share/zoneinfo ]; then [ -f "/usr/share/zoneinfo/$1" ]; else [[ $1 == */* || $1 == UTC ]]; fi
}

# An absolute folder path without spaces or quotes (it goes into the Compose files).
valid_abs_path() { [[ $1 == /* ]] && [[ ! $1 =~ [[:space:]\'\"\\] ]] && [ "$1" != / ]; }

valid_nonempty() { [ -n "${1// /}" ]; }

# A WireGuard private key (44 base64 characters) and its address(es) in CIDR form.
valid_wg_key() { [[ $1 =~ ^[A-Za-z0-9+/]{43}=$ ]]; }
valid_wg_addr() { [[ $1 =~ ^[0-9a-fA-F:.]+/[0-9]{1,3}(,[0-9a-fA-F:.]+/[0-9]{1,3})*$ ]]; }

# ask_password VAR "question" - required, typed twice, never shown
ask_password() {
  local var=$1 q=$2 ans ans2
  say "$(t q_admin_password_hint)"
  while :; do
    read -r -s -p "$(printf '%s? %s%s: ' "$C_BOLD" "$q" "$C_RESET")" ans </dev/tty; echo
    if [ -z "$ans" ]; then warning "$(t pw_required)"; continue; fi
    if [ ${#ans} -lt 8 ]; then warning "$(t pw_too_short)"; continue; fi
    if ! valid_password "$ans"; then warning "$(t pw_bad_chars)"; continue; fi
    read -r -s -p "$(printf '%s? %s%s: ' "$C_BOLD" "$(t pw_repeat)" "$C_RESET")" ans2 </dev/tty; echo
    [ "$ans" = "$ans2" ] && break
    warning "$(t pw_mismatch)"
  done
  printf -v "$var" '%s' "$ans"
}

# ---------------------------------------------------------------- json via jq

json_get() { jq -r "$2 // empty" "$1" 2>/dev/null; }
