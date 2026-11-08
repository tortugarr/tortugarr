#!/bin/bash
# What Moonfin (upstream) has that Tortugarr does not yet, as a Markdown report: the releases
# since our base, their notes, what changed where, and which files both sides changed (where a
# merge will need care). Read-only: fetches the upstream remote, changes nothing else.
#   scripts/moonfin-upstream-report.sh [report.md]
# Step 1 of docs/MOONFIN-UPSTREAM.md.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:-/dev/stdout}
REMOTE=${MOONFIN_REMOTE:-upstream}
REPO=${MOONFIN_REPO:-Moonfin-Client/Moonfin-Core}
git fetch -q --tags "$REMOTE"
BASE=$(git merge-base HEAD "$REMOTE/main")
# The newest upstream release tag already in Tortugarr, and the ones after it.
mapfile -t TAGS < <(git tag -l --sort=-v:refname | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' || true)
HAVE=""; NEWER=()
for t in "${TAGS[@]}"; do
  # Only Moonfin's own releases (on its main); Tortugarr's v4.20.x tags are not.
  git merge-base --is-ancestor "$t" "$REMOTE/main" 2>/dev/null || continue
  if git merge-base --is-ancestor "$t" HEAD 2>/dev/null; then HAVE=$t; break; fi
  NEWER+=("$t")
done
not_translation() { grep -viE 'weblate|translat|localiz' || true; }
{
  echo "# Moonfin upstream report – $(date +%F)"
  echo
  echo "- Tortugarr: \`$(git rev-parse --short=9 HEAD)\` on branch \`$(git branch --show-current)\`"
  echo "- Moonfin release already in Tortugarr: **${HAVE:-none}**"
  echo "- Shared history ends at \`$(git rev-parse --short=9 "$BASE")\` ($(git log -1 --format=%ad --date=short "$BASE"))"
  echo "- Upstream main: \`$(git rev-parse --short=9 "$REMOTE/main")\` ($(git log -1 --format=%ad --date=short "$REMOTE/main"))"
  total=$(git rev-list --count "$BASE..$REMOTE/main")
  real=$(git log --format=%s "$BASE..$REMOTE/main" | not_translation | wc -l)
  echo "- Upstream commits not in Tortugarr: **$total** ($real without translation-only commits)"
  echo "- Tortugarr commits not in Moonfin: $(git rev-list --count "$BASE..HEAD")"
  echo
  if [ ${#NEWER[@]} -gt 0 ]; then
    echo "## Newer Moonfin releases"
    for t in "${NEWER[@]}"; do
      echo
      echo "### $t ($(git log -1 --format=%ad --date=short "$t"), $(git rev-list --count "HEAD..$t") commits not in Tortugarr)"
      echo
      if command -v gh >/dev/null && notes=$(gh release view "$t" -R "$REPO" --json body -q .body 2>/dev/null); then
        echo "$notes" | sed 's/^#/###/'
      else
        echo "(release notes not available: gh missing or not logged in)"
      fi
    done
    echo
  else
    echo "No Moonfin release newer than ${HAVE:-the base}; only unreleased commits on main."
    echo
  fi
  echo "## Where upstream changed things (files, by top folder; translations left out)"
  echo
  echo '```'
  git diff --name-only "$BASE" "$REMOTE/main" | grep -vE '^lib/l10n/' | awk -F/ '{print ($2=="" ? $1 : $1"/"$2)}' | sort | uniq -c | sort -rn | head -30
  echo '```'
  echo
  echo "## Both sides changed (merge needs care here)"
  echo
  comm -12 <(git diff --name-only "$BASE" HEAD | sort) <(git diff --name-only "$BASE" "$REMOTE/main" | sort) > /tmp/moonfin-both.$$
  echo "$(wc -l < /tmp/moonfin-both.$$) file(s); the largest upstream changes first:"
  echo
  echo '```'
  while read -r f; do printf '%6s  %s\n' "$(git diff --numstat "$BASE" "$REMOTE/main" -- "$f" | awk '{print $1+$2}')" "$f"; done < /tmp/moonfin-both.$$ \
    | sort -rn | grep -vE '  lib/l10n/' | head -40
  echo '```'
  rm -f /tmp/moonfin-both.$$
  echo
  echo "## Dependencies (pubspec.yaml, upstream side)"
  echo
  echo '```diff'
  git diff "$BASE" "$REMOTE/main" -- pubspec.yaml | grep -E '^[+-][^+-]' | head -40 || true
  echo '```'
} > "$OUT"
