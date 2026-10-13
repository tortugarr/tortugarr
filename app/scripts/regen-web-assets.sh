#!/usr/bin/env bash
# Regenerates web/sqlite3.wasm and web/drift_worker.js from the locked
# package versions. Run after bumping drift or sqlite3.
set -euo pipefail

cd "$(dirname "$0")/.."

SQLITE_VERSION=$(grep -A2 "name: sqlite3$" pubspec.lock | grep version | head -1 | sed 's/.*"\(.*\)"/\1/')
echo "Downloading sqlite3-${SQLITE_VERSION}.wasm"
curl -fsSL "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE_VERSION}/sqlite3.wasm" -o web/sqlite3.wasm

echo "Compiling drift worker"
cat > web/drift_worker.dart <<'DART'
import 'package:drift/wasm.dart';
void main() { WasmDatabase.workerMainForOpen(); }
DART
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js
rm -f web/drift_worker.dart web/drift_worker.js.deps web/drift_worker.js.map

echo "Done. Artifacts:"
ls -la web/sqlite3.wasm web/drift_worker.js
