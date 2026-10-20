#!/bin/bash
# Extra media folders with one type each (lib/extra_libs.sh), driven unattended. Checks that a
# folder keeps its /data/library/N when its type changes, that only movies and tv folders can
# be managed by Radarr/Sonarr, that a removed folder is gone, and that new folders get the next
# free number. Nothing outside a temporary folder is touched.
#   bash tests/test-extra-libs.sh
set -u
APP=$(cd "$(dirname "$0")/.." && pwd)
export TORTUGARR_APP=$APP
. "$APP/lib/common.sh"; . "$APP/lib/detect.sh"; . "$APP/lib/extra_libs.sh"
load_language en
TORTUGARR_LOG=/dev/null; UNATTENDED=1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAILED=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; FAILED=$((FAILED + 1)); fi; }
q() { jq -r "$1" <<< "$EXTRA_LIBS_JSON"; }

# The 2026-10-20 setup: Clips and the XXX and MUSIC folders were typed tv/movies.
EXTRA_LIBS_JSON='[
 {"host_path":"/mnt/e/-=Clips=-/","container_path":"/data/library/1","type":"tv","arr_manage":true},
 {"host_path":"/mnt/e/-=MOVIES=-/","container_path":"/data/library/3","type":"movies","arr_manage":true},
 {"host_path":"/mnt/e/-=XxX=-/","container_path":"/data/library/5","type":"movies","arr_manage":true},
 {"host_path":"/mnt/h/-=MUSIC=-/","container_path":"/data/library/8","type":"movies","arr_manage":true},
 {"host_path":"/mnt/h/-=Serier=-/","container_path":"/data/library/9","type":"tv","arr_manage":true}]'
REDO_LIBS=y; HAS_EXTRA=y
EXTRA_EDIT_TYPE_1=other EXTRA_EDIT_TYPE_2=movies EXTRA_EDIT_MANAGE_2=y EXTRA_EDIT_TYPE_3=adult
EXTRA_EDIT_TYPE_4=music EXTRA_EDIT_TYPE_5=remove
mkdir -p "$TMP/Konserter"; EXTRA_PATH_1=$TMP/Konserter EXTRA_TYPE_1=music
ask_extra_libs 1 >/dev/null 2>&1

check "Clips becomes other, keeps /data/library/1" '[ "$(q ".[] | select(.host_path==\"/mnt/e/-=Clips=-/\") | \"\(.type) \(.container_path)\"")" = "other /data/library/1" ]'
check "other is never managed by Sonarr" '[ "$(q ".[] | select(.type==\"other\") | .arr_manage")" = false ]'
check "movies folder stays managed" '[ "$(q ".[] | select(.host_path==\"/mnt/e/-=MOVIES=-/\") | .arr_manage")" = true ]'
check "XXX becomes adult, not managed" '[ "$(q ".[] | select(.host_path==\"/mnt/e/-=XxX=-/\") | \"\(.type) \(.arr_manage)\"")" = "adult false" ]'
check "MUSIC becomes music, keeps /data/library/8" '[ "$(q ".[] | select(.host_path==\"/mnt/h/-=MUSIC=-/\") | \"\(.type) \(.container_path)\"")" = "music /data/library/8" ]'
check "removed folder is gone" '[ "$(q "[.[] | select(.host_path==\"/mnt/h/-=Serier=-/\")] | length")" = 0 ]'
check "new folder gets the next free number" '[ "$(q ".[] | select(.host_path==\"$TMP/Konserter\") | \"\(.type) \(.container_path)\"")" = "music /data/library/9" ]'

# A fresh install starts from an empty list.
EXTRA_LIBS_JSON=''; mkdir -p "$TMP/Movies"
EXTRA_PATH_1=$TMP/Movies EXTRA_TYPE_1=movies EXTRA_MANAGE_1=y
ask_extra_libs 0 >/dev/null 2>&1
check "fresh install: first folder is /data/library/1" '[ "$(q ".[0] | \"\(.type) \(.container_path) \(.arr_manage)\"")" = "movies /data/library/1 true" ]'

[ $FAILED = 0 ] && echo "all passed" || echo "$FAILED failed"
exit $FAILED
