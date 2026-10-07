#!/bin/bash
# Fetches the libretro cores bundled into the macOS app. Each core is downloaded
# for arm64 and x86_64, combined into a universal binary, and wrapped in a
# versioned macOS framework so Xcode embeds and code-signs it. The PPSSPP assets
# the PSP core needs at runtime are fetched too. Run before building the macOS
# app for distribution. The outputs are not committed.
#
# Usage: macos/game_host/fetch_cores.sh
set -euo pipefail

cores=(
  fceumm snes9x gambatte mgba genesis_plus_gx pcsx_rearmed
  mupen64plus_next ppsspp melonds mednafen_pce_fast stella prosystem
  handy mednafen_wswan mednafen_ngp mednafen_vb
)

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/cores"
base="https://buildbot.libretro.com/nightly/apple/osx"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$out"

for core in "${cores[@]}"; do
  name="${core}_libretro"
  echo "==> $name"
  arm="$work/${name}.arm64.dylib"
  intel="$work/${name}.x86_64.dylib"

  curl -fsSL "$base/arm64/latest/${name}.dylib.zip" -o "$work/arm.zip" &&
    unzip -o -q "$work/arm.zip" -d "$work" && mv "$work/${name}.dylib" "$arm" ||
    { echo "    skip: no arm64 build"; continue; }

  if curl -fsSL "$base/x86_64/latest/${name}.dylib.zip" -o "$work/intel.zip" &&
    unzip -o -q "$work/intel.zip" -d "$work"; then
    mv "$work/${name}.dylib" "$intel"
  else
    intel=""
  fi

  # Versioned macOS framework: binary and Info.plist under Versions/A, with the
  # flat symlinks macOS expects so codesign and notarization accept it.
  fw="$out/${name}.framework"
  rm -rf "$fw"
  mkdir -p "$fw/Versions/A/Resources"
  if [ -n "$intel" ]; then
    lipo -create "$arm" "$intel" -output "$fw/Versions/A/$name"
  else
    cp "$arm" "$fw/Versions/A/$name"
  fi
  install_name_tool -id "@rpath/${name}.framework/Versions/A/${name}" "$fw/Versions/A/$name"

  # CFBundleIdentifier forbids underscores, so map them to hyphens.
  bundle_id="io.moonfin.cores.$(echo "$core" | tr '_' '-')"
  cat >"$fw/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>${name}</string>
	<key>CFBundleIdentifier</key>
	<string>${bundle_id}</string>
	<key>CFBundleName</key>
	<string>${name}</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
</dict>
</plist>
PLIST

  ln -s A "$fw/Versions/Current"
  ln -s "Versions/Current/$name" "$fw/$name"
  ln -s "Versions/Current/Resources" "$fw/Resources"
done

# The PSP core needs its assets in the system directory at runtime. Bundle them
# so the app can seed them. The native side copies them in when PSP loads.
ppsspp_assets="$out/assets/PPSSPP"
if [ ! -d "$ppsspp_assets" ]; then
  ref="${PPSSPP_ASSETS_REF:-v1.17.1}"
  echo "==> PPSSPP assets ($ref)"
  if curl -fsSL "https://codeload.github.com/hrydgard/ppsspp/tar.gz/refs/tags/${ref}" \
      -o "$work/ppsspp.tgz"; then
    mkdir -p "$out/assets"
    if tar -xzf "$work/ppsspp.tgz" -C "$out/assets" --strip-components=1 \
        "ppsspp-${ref#v}/assets"; then
      mv "$out/assets/assets" "$ppsspp_assets"
    else
      echo "    warn: could not extract PPSSPP assets; PSP will not boot"
    fi
  else
    echo "    warn: could not fetch PPSSPP assets; PSP will not boot"
  fi
fi

echo "Done. Frameworks and assets in $out"
