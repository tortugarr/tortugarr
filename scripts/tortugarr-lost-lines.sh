#!/bin/bash
# After a Moonfin merge: the lines Tortugarr had added (since the shared base) that are no longer
# in the working tree, per file. A file taken whole from Moonfin silently drops Tortugarr's
# changes in it (2026-11-08: the subtitle-language filter in track_choices.dart went that way).
# Read each listed file; a rewrite that keeps the behaviour is fine, a real loss is put back.
#   scripts/tortugarr-lost-lines.sh <tortugarr-commit-before-merge> [moonfin-base]
# Step 4 of docs/MOONFIN-UPSTREAM.md.
set -euo pipefail
cd "$(dirname "$0")/.."
OURS=${1:?the Tortugarr commit before the merge (the first parent of the merge: HEAD^1)}
BASE=${2:-}
if [ -z "$BASE" ]; then
  BASE=$(git merge-base "$OURS" "${MOONFIN_REMOTE:-upstream}/main")
fi
python3 - "$BASE" "$OURS" <<'PY'
import subprocess, sys
base_ref, ours_ref = sys.argv[1], sys.argv[2]
def show(ref, f):
    try:
        return subprocess.check_output(['git', 'show', f'{ref}:{f}'], stderr=subprocess.DEVNULL).decode('utf-8', 'ignore').splitlines()
    except subprocess.CalledProcessError:
        return []
files = subprocess.check_output(['git', 'diff', '--name-only', base_ref, ours_ref]).decode().split()
report = []
for f in files:
    if f.startswith(('lib/l10n/', 'server/', 'test/')):
        continue
    ours = show(ours_ref, f)
    base = set(show(base_ref, f))
    try:
        now = set(open(f, encoding='utf-8', errors='ignore').read().splitlines())
    except FileNotFoundError:
        report.append((10**6, f, ['<file gone after the merge>']))
        continue
    added = [l for l in ours if l not in base and len(l.strip()) > 12 and not l.strip().startswith('//')]
    lost = [l for l in added if l not in now]
    if lost:
        report.append((len(lost), f, lost[:3]))
for n, f, ex in sorted(report, reverse=True):
    print(f'{n:6}  {f}')
    for e in ex:
        print(f'          {e.strip()[:120]}')
print(f'{len(report)} file(s) with Tortugarr lines missing; check each one.')
PY
