#!/bin/bash
# Builds the Tortugarr plugin into plugin/dist/Tortugarr_<version>/ (the DLL plus Jellyfin's
# meta.json), which the installer copies into Jellyfin. Needs the .NET 10 SDK; the
# installer itself does not, it uses what is committed in dist/.
set -euo pipefail
cd "$(dirname "$0")"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
command -v dotnet >/dev/null || export PATH="$HOME/.dotnet:$PATH"
[ -e /usr/lib/x86_64-linux-gnu/libicuuc.so ] || export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
VERSION=$(sed -n 's:.*<AssemblyVersion>\(.*\)</AssemblyVersion>.*:\1:p' Jellyfin.Plugin.Tortugarr/Jellyfin.Plugin.Tortugarr.csproj)
dotnet test tests/Tortugarr.Tests --nologo -v quiet
OUT=$(mktemp -d)
# No debug symbols and no build paths in the DLL: it is published, and a path would show the
# builder's home folder and checkout (the PDB path was in it before 2026-10-08).
dotnet publish Jellyfin.Plugin.Tortugarr -c Release -o "$OUT" --nologo -v quiet \
  -p:DebugType=none -p:DebugSymbols=false -p:Deterministic=true -p:ContinuousIntegrationBuild=true \
  '-p:PathMap=$(MSBuildProjectDirectory)=/src'
if strings -a "$OUT/Jellyfin.Plugin.Tortugarr.dll" | grep -qiE "/home/|/root/|/mnt/|[A-Z]:\\\\|$(cd .. && pwd)"; then
  echo "build.sh: the DLL contains a build path - not publishing it:" >&2
  strings -a "$OUT/Jellyfin.Plugin.Tortugarr.dll" | grep -iE "/home/|/root/|/mnt/|[A-Z]:\\\\|$(cd .. && pwd)" >&2
  exit 1
fi
rm -rf dist && mkdir -p "dist/Tortugarr_$VERSION"
cp "$OUT/Jellyfin.Plugin.Tortugarr.dll" "dist/Tortugarr_$VERSION/"
cp assets/logo.png "dist/Tortugarr_$VERSION/logo.png"   # the plugin's picture in Jellyfin
cat > "dist/Tortugarr_$VERSION/meta.json" <<JSON
{
  "category": "General",
  "changelog": "",
  "description": "Server side of the Tortugarr app: searches, downloads and subtitles through Sonarr, Radarr and Bazarr.",
  "guid": "19f30fb1-bb78-444b-a75e-2997883b215c",
  "name": "Tortugarr",
  "overview": "Download Now and subtitles for the Tortugarr app, without keys in the app.",
  "owner": "Tortugarr",
  "targetAbi": "12.0.0.0",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "status": "Active",
  "autoUpdate": false,
  "imagePath": "logo.png",
  "assemblies": []
}
JSON
rm -rf "$OUT"
ls -la "dist/Tortugarr_$VERSION"
