#!/usr/bin/env bash
# Public Tortugarr Android APK (TV, or phone/tablet with --mobile): no server
# addresses, keys or Firebase.
#
# Builds from a clean git worktree of the public-build branch (or the given
# commit), never from the private working copy, so the git-ignored
# download_now_secrets.dart (the author's server keys) cannot end up in the APK. The worktree gets the empty template
# instead, the app is built with TORTUGARR_PUBLIC=true, and the finished APK is
# scanned for every value in the private secrets file before it is kept.
#
#   ./build-android-tv-public.sh [--mobile] [branch-or-commit]   (default: public-build)
set -euo pipefail

FLAVOR="androidTv-public"
NAME="tv"
# Turns on "Check for updates" against the tortugarr/tortugarr releases.
CHANNEL="android_tv_apk"
if [ "${1:-}" = "--mobile" ]; then
  FLAVOR="mobile-public"
  NAME="mobile"
  CHANNEL="apk"
  shift
fi

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --path-format=absolute --git-common-dir)/.."
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
REF="${1:-public-build}"
WORK="${PUBLIC_BUILD_DIR:-$HOME/workspace/tortugarr-public-build}"
OUT_DIR="${PUBLIC_APK_DIR:-$HOME/workspace/tortugarr-apks}"
SECRETS_REL="lib/data/services/download/download_now_secrets.dart"
TEMPLATE_REL="lib/data/services/download/download_now_secrets.example.dart"

commit="$(git -C "$REPO_ROOT" rev-parse --short "$REF")"
echo "Public $NAME build of $commit in $WORK"

if [ -d "$WORK/.git" ] || [ -f "$WORK/.git" ]; then
  # Uncommitted work is never overwritten: commit it first.
  if [ -n "$(git -C "$WORK" status --porcelain --untracked-files=no)" ]; then
    echo "worktree $WORK has uncommitted changes; commit them first" >&2
    exit 1
  fi
  git -C "$WORK" checkout --quiet "$REF"
else
  git -C "$REPO_ROOT" worktree add "$WORK" "$REF"
fi

# The only secrets file this build may see is the empty template.
cp "$WORK/$TEMPLATE_REL" "$WORK/$SECRETS_REL"

cd "$WORK"
flutter pub get
flutter build apk --release --flavor "$FLAVOR" \
  --dart-define=TORTUGARR_PUBLIC=true \
  --dart-define=DISTRIBUTION_CHANNEL="$CHANNEL"

apk="build/app/outputs/flutter-apk/app-${FLAVOR,,}-release.apk"
if [ ! -f "$apk" ]; then
  echo "no public release APK found under build/app/outputs/flutter-apk" >&2
  exit 1
fi

# Every non-empty value of the private secrets file must be absent from the APK
# (all entries, native libraries included). Values are never printed.
python3 - "$apk" "$REPO_ROOT/$SECRETS_REL" <<'PY'
import re, sys, zipfile
apk, secrets = sys.argv[1], sys.argv[2]
try:
    src = open(secrets, encoding="utf-8").read()
except FileNotFoundError:
    src = ""
values = [v for v in re.findall(r"=\s*'([^']*)'", src) if len(v) >= 4]
hosts = {m for v in values for m in re.findall(r"//([^/:]+)", v)}
needles = sorted({v.encode() for v in values} | {h.encode() for h in hosts})
hits = []
with zipfile.ZipFile(apk) as z:
    for name in z.namelist():
        data = z.read(name)
        for i, n in enumerate(needles):
            if n in data:
                hits.append((name, i))
if hits:
    for name, i in hits:
        print(f"LEAK: private value #{i} found in {name}", file=sys.stderr)
    sys.exit(1)
print(f"secret scan: {len(needles)} private values checked, none in the APK")
PY

mkdir -p "$OUT_DIR"
dest="$OUT_DIR/tortugarr-$NAME-public-$commit.apk"
cp "$apk" "$dest"
echo "OK: $dest"
