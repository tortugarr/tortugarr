#!/usr/bin/env bash
# Runs tests/windows/crash-test.ps1 with PowerShell 7 for Linux, against a fake Windows.
# Nothing here starts a Windows program: never run this test with powershell.exe on an
# everyday PC (the Windows-side tests belong in a Windows test VM).
# PowerShell for Linux: a tarball unpacked in ~/.local/pwsh (or pwsh on PATH).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
pwsh=$(command -v pwsh || echo "$HOME/.local/pwsh/pwsh")
[ -x "$pwsh" ] || { echo "PowerShell for Linux (pwsh) not found" >&2; exit 2; }
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
"$pwsh" -NoProfile -File "$here/crash-test.ps1" -Helper "$here/../../windows/tortugarr-windows.ps1" -Base "$dir"
