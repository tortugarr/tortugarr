# shellcheck shell=bash
# Media folders the user already has, added next to Tortugarr's own media folder. Each folder
# has exactly one type, and the type decides who sees it (lib/stack.sh, write_overrides):
#
#   movies  Radarr (when it may manage the folder) + Jellyfin "Movies"
#   docs    Radarr (when it may manage the folder) + Jellyfin "Documentaries"; only movies
#           TMDB lists as documentaries go there, and no other movie does
#   tv      Sonarr (when it may manage the folder) + Jellyfin "TV Shows"
#   adult   the Tortugarr plugin's hidden adult library only
#   music   Jellyfin "Music Videos" (concerts, music videos) only
#   other   Jellyfin "Home Videos" (clips and the like) only
#
# State: extra_libraries = [{host_path, container_path, type, arr_manage}]. container_path
# (/data/library/N) never changes for a folder, so Jellyfin, Radarr and Sonarr keep what they
# registered there when its type changes.

EXTRA_TYPES=(movies docs tv adult music other)

extra_type_label() {
  case $1 in
    movies) t extra_type_movies ;; docs) t extra_type_docs ;; tv) t extra_type_tv ;; adult) t extra_type_adult ;;
    music) t extra_type_music ;; other) t extra_type_other ;; *) echo "$1" ;;
  esac
}

# choose_extra_type VAR default [with-remove]
choose_extra_type() {
  local var=$1 def=$2 ty
  local -a opts=()
  for ty in "${EXTRA_TYPES[@]}"; do opts+=("$ty" "$(extra_type_label "$ty")"); done
  [ "${3:-}" = with-remove ] && opts+=(remove "$(t extra_type_remove)")
  choose "$var" "$(t q_extra_type)" "$def" "${opts[@]}"
}

# The type a folder most likely has: one named for documentaries is that, else [default].
guess_extra_type() {  # path default
  local name=${1,,}
  if [ "$2" = movies ] && [[ $name == *dokument* || $name == *document* ]]; then echo docs; else echo "$2"; fi
}

list_extra_libs() {
  jq -r '.[] | "\(.host_path)\t\(.type)"' <<< "${EXTRA_LIBS_JSON:-[]}" | while IFS=$'\t' read -r path ty; do
    printf '   %-40s %s\n' "$path" "$(extra_type_label "$ty")"
  done
}

# Whether Radarr/Sonarr may rename and add to a folder of this type.
ask_extra_manage() {  # VAR type default(y|n)
  local var=$1 ty=$2
  case $ty in movies|docs|tv) confirm "$var" "$(t q_extra_manage)" "$3" ;; *) return 1 ;; esac
}

edit_extra_libs() {
  local out='[]' i=0 entry path ty manage def_manage
  while read -r entry; do
    i=$((i + 1))
    path=$(jq -r .host_path <<< "$entry")
    say "$(t extra_lib_edit "$path")"
    # A movie folder of documentaries from before the type existed is offered as one.
    choose_extra_type "EXTRA_EDIT_TYPE_$i" "$(guess_extra_type "$path" "$(jq -r .type <<< "$entry")")" with-remove
    ty=$(eval echo "\${EXTRA_EDIT_TYPE_$i}")
    [ "$ty" = remove ] && { note "$(t extra_lib_removed "$path")"; continue; }
    def_manage=n; [ "$(jq -r .arr_manage <<< "$entry")" = true ] && def_manage=y
    manage=false; ask_extra_manage "EXTRA_EDIT_MANAGE_$i" "$ty" "$def_manage" && manage=true
    out=$(jq -c --argjson e "$entry" --arg t "$ty" --argjson m "$manage" \
      '. + [$e + {type:$t, arr_manage:$m}]' <<< "$out")
  done < <(jq -c '.[]' <<< "${EXTRA_LIBS_JSON:-[]}")
  EXTRA_LIBS_JSON=$out
}

add_extra_libs() {
  # New folders get the next free number; existing ones keep theirs.
  local n; n=$(jq '[.[].container_path | capture("(?<n>[0-9]+)$").n | tonumber] | max // 0' <<< "${EXTRA_LIBS_JSON:-[]}")
  local k=0 path ty manage
  while :; do
    k=$((k + 1))
    ask "EXTRA_PATH_$k" "$(t q_extra_path "$k")" ""
    path=$(eval echo "\${EXTRA_PATH_$k}")
    [ -z "$path" ] && break
    # On WSL people type Windows paths (E:\Movies); use the same folder as WSL sees it.
    if is_wsl && [[ $path =~ ^[A-Za-z]:([\\/]|$) ]]; then
      local win=$path
      path=$(wslpath -u "$win" 2>/dev/null) || path=""
      [ -n "$path" ] && note "$(t win_path_converted "$win" "$path")"
      [ -z "$path" ] && path=$win
    fi
    if [ ! -d "$path" ]; then warning "$(t not_a_dir "$path")"; k=$((k - 1)); [ "$UNATTENDED" = 1 ] && break; continue; fi
    if jq -e --arg h "$path" 'any(.[]; .host_path == $h)' <<< "${EXTRA_LIBS_JSON:-[]}" >/dev/null; then
      warning "$(t extra_lib_already "$path")"; k=$((k - 1)); [ "$UNATTENDED" = 1 ] && break; continue
    fi
    choose_extra_type "EXTRA_TYPE_$k" "$(guess_extra_type "$path" movies)"
    ty=$(eval echo "\${EXTRA_TYPE_$k}")
    manage=false; ask_extra_manage "EXTRA_MANAGE_$k" "$ty" n && manage=true
    n=$((n + 1))
    EXTRA_LIBS_JSON=$(jq -c --arg h "$path" --arg c "/data/library/$n" --arg t "$ty" --argjson m "$manage" \
      '. + [{host_path:$h, container_path:$c, type:$t, arr_manage:$m}]' <<< "${EXTRA_LIBS_JSON:-[]}")
    [ "$UNATTENDED" = 1 ] && continue
    confirm MORE_LIBS "$(t q_extra_more)" n || break
  done
}

# With movie or series folders Radarr/Sonarr may add to: do new titles go only there?
ask_new_in_extra() {
  jq -e 'any(.[]; .arr_manage and (.type == "movies" or .type == "docs" or .type == "tv"))' <<< "${EXTRA_LIBS_JSON:-[]}" >/dev/null || return 0
  confirm NEW_IN_EXTRA "$(t q_new_in_extra "${DATA_DIR:-/srv/tortugarr}/media")" "${NEW_IN_EXTRA:-y}" || NEW_IN_EXTRA=n
}

# The extra-folder part of the installer's questions.
ask_extra_libs() {  # reconf(0|1)
  if [ "$1" = 1 ] && [ "$(jq length <<< "${EXTRA_LIBS_JSON:-[]}")" -gt 0 ]; then
    say "$(t extra_libs_now)"
    list_extra_libs
    if confirm REDO_LIBS "$(t q_change_extra_libs)" n; then
      edit_extra_libs
      confirm HAS_EXTRA "$(t q_extra_libs_more)" n && add_extra_libs
    fi
  elif [ "$1" = 0 ] || confirm REDO_LIBS "$(t q_change_extra_libs)" n; then
    [ "$1" = 0 ] && EXTRA_LIBS_JSON='[]'
    confirm HAS_EXTRA "$(t q_extra_libs)" n && add_extra_libs
  fi
  ask_new_in_extra
}
