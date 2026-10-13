#!/usr/bin/env bash
# Builds the shipping libretro cores from pinned sources for arm64-apple-tvos,
# interpreter only, into tvos/Frameworks/Cores/staging/. This is the App Store
# path: reproducible, no JIT. Follow with wrap_frameworks.sh then wire_tvos_cores.rb.
#
# Every core uses its own `platform=tvos-arm64` target. pcsx_rearmed's tvos-arm64
# target forces -DDRC_DISABLE (interpreter), which is asserted below. TVOS_DEPLOYMENT_TARGET
# pins the minimum OS for cores whose target does not set one (fceumm).
#
# Usage: build_cores.sh [core ...]   (default: all six)

set -euo pipefail

export TVOS_DEPLOYMENT_TARGET=16.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING="$SCRIPT_DIR/../../Frameworks/Cores/staging"
WORK="${CORES_BUILD_DIR:-$SCRIPT_DIR/.build}"
mkdir -p "$STAGING" "$WORK"

xcrun -sdk appletvos --show-sdk-path >/dev/null || {
  echo "error: appletvos SDK not found (install Xcode + tvOS platform)" >&2
  exit 1
}

# core | repo | pinned commit | build subdir | recursive submodules
CORES="
fceumm|https://github.com/libretro/libretro-fceumm.git|0d610d9a6401697157f693a5407adf450a0e52fb|.|0
snes9x|https://github.com/libretro/snes9x.git|185488cd83aaf274752a742c94d45561cbecb7af|libretro|0
gambatte|https://github.com/libretro/gambatte-libretro.git|dfc165599f3f1068c40a0b7ad6fe5f161283d483|.|0
genesis_plus_gx|https://github.com/libretro/Genesis-Plus-GX.git|fa4dca561e08d5be9077419f7b255e1da213ed21|.|0
mgba|https://github.com/libretro/mgba.git|6dce57eef127dc4cc292644f38196e0e7c58590c|.|0
pcsx_rearmed|https://github.com/libretro/pcsx_rearmed.git|050981b6eeb715f142854f57c68086f62921f027|.|1
"

want=("$@")
selected() {
  [ ${#want[@]} -eq 0 ] && return 0
  for w in "${want[@]}"; do [ "$w" = "$1" ] && return 0; done
  return 1
}

fetch() {
  local dir="$1" repo="$2" commit="$3" recursive="$4"
  if [ ! -d "$dir/.git" ]; then
    git clone -q "$repo" "$dir"
  fi
  git -C "$dir" fetch -q origin "$commit" 2>/dev/null || git -C "$dir" fetch -q --all
  # reset --hard (not checkout) so a prior run's source patch does not persist.
  git -C "$dir" reset -q --hard "$commit"
  git -C "$dir" clean -qfdx
  if [ "$recursive" = "1" ]; then
    git -C "$dir" submodule update --init --recursive -q
  fi
}

# mgba's tvos-arm64 target omits -DHAVE_LOCALE, so it redefines locale_t against
# the SDK's. Add it, matching mgba's own iOS targets.
patch_mgba() {
  local mk="$1/Makefile.libretro"
  grep -q "tvos-arm64" "$mk" || return 0
  awk '
    /else ifeq \(\$\(platform\), tvos-arm64\)/ {intvos=1}
    {print}
    intvos && /DEFINES \+= -DHAVE_STRLCPY/ {print "    DEFINES += -DHAVE_LOCALE"; intvos=0}
  ' "$mk" > "$mk.tmp" && mv "$mk.tmp" "$mk"
}

build_one() {
  local core="$1" repo="$2" commit="$3" subdir="$4" recursive="$5"
  local dir="$WORK/$core"
  echo "==> $core @ ${commit:0:10}"
  fetch "$dir" "$repo" "$commit" "$recursive"
  [ "$core" = "mgba" ] && patch_mgba "$dir"

  local makedir="$dir/$subdir"
  local makefile="Makefile.libretro"
  [ -f "$makedir/$makefile" ] || makefile="Makefile"

  ( cd "$makedir" && make -f "$makefile" platform=tvos-arm64 clean >/dev/null 2>&1 || true )
  local log="$WORK/$core.log"
  ( cd "$makedir" && make -f "$makefile" platform=tvos-arm64 -j"$(sysctl -n hw.ncpu)" ) >"$log" 2>&1

  # pcsx_rearmed compliance: the interpreter build must define DRC_DISABLE.
  if [ "$core" = "pcsx_rearmed" ] && ! grep -q "DRC_DISABLE" "$log"; then
    echo "error: pcsx_rearmed did not build with -DDRC_DISABLE (would ship a JIT)" >&2
    exit 1
  fi

  local dylib
  dylib="$(ls "$makedir"/*_libretro_tvos.dylib 2>/dev/null | head -1)"
  [ -n "$dylib" ] || { echo "error: $core produced no dylib (see $log)" >&2; exit 1; }
  lipo -info "$dylib" | grep -q arm64 || { echo "error: $core is not arm64" >&2; exit 1; }
  cp "$dylib" "$STAGING/${core}_libretro_tvos.dylib"
}

built=0
while IFS='|' read -r core repo commit subdir recursive; do
  [ -z "$core" ] && continue
  selected "$core" || continue
  build_one "$core" "$repo" "$commit" "$subdir" "$recursive"
  built=$((built + 1))
done <<< "$CORES"

echo "done: built $built core(s) into $STAGING"
echo "next: wrap_frameworks.sh"
