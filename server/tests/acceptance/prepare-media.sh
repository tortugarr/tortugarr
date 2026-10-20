#!/bin/bash
# Acceptance test, part 1 - run as root on the clean test machine BEFORE installing.
#
# Builds an "existing media library", as a new user would already have one:
#   /srv/existing/Movies  Big Buck Bunny, Sintel, Tears of Steel (Blender Foundation
#                         open movies, CC-BY), Tears of Steel with its official English
#                         subtitles next to it
#   /srv/existing/TV      a small test series (two episodes)
# and the files the download chain will fetch later, in /srv/test-seed/files.
#
# The test series and the two download-chain titles reuse the open-movie files under
# episode/release names: Sonarr, Radarr and Jellyfin identify media by name, so that is
# all the test needs, and every byte stays freely licensed.
set -euo pipefail
B=https://download.blender.org
EX=/srv/existing
SEED=/srv/test-seed
DL=/srv/acceptance-downloads
mkdir -p "$EX/Movies" "$EX/TV" "$SEED/files" "$SEED/torrents" "$DL"

fetch() {  # url file
  [ -s "$2" ] && return 0
  echo "download $1"
  # The network here drops large TLS downloads now and then (bad_record_mac): retry on any error.
  curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 -C - -o "$2.part" "$1" && mv "$2.part" "$2"
}
unzip_one() {  # zip -> first file inside, to target
  python3 - "$1" "$2" <<'EOF'
import sys, zipfile, shutil
z = zipfile.ZipFile(sys.argv[1])
name = next(n for n in z.namelist() if not n.endswith("/") and not n.startswith("__MACOSX"))
with z.open(name) as src, open(sys.argv[2], "wb") as dst:
    shutil.copyfileobj(src, dst, 1 << 20)
EOF
}

fetch "$B/peach/bigbuckbunny_movies/BigBuckBunny_640x360.m4v.zip" "$DL/bbb.zip"
fetch "$B/durian/movies/Sintel.2010.720p.mkv.zip" "$DL/sintel.zip"
fetch "$B/demo/movies/ToS/tears_of_steel_720p.mov" "$DL/tos.mov"
fetch "$B/demo/movies/ToS/subtitles/TOS-en.srt" "$DL/tos.en.srt"
fetch "$B/demo/movies/Sintel.2010.1080p.mkv" "$DL/sintel-1080p.mkv"   # > 700 MB: passes the plugin's movie minimum

mkdir -p "$EX/Movies/Big Buck Bunny (2008)" "$EX/Movies/Sintel (2010)" "$EX/Movies/Tears of Steel (2012)"
[ -s "$EX/Movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).m4v" ] || unzip_one "$DL/bbb.zip" "$EX/Movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).m4v"
[ -s "$EX/Movies/Sintel (2010)/Sintel (2010).mkv" ] || unzip_one "$DL/sintel.zip" "$EX/Movies/Sintel (2010)/Sintel (2010).mkv"
cp --update=none "$DL/tos.mov" "$EX/Movies/Tears of Steel (2012)/Tears of Steel (2012).mov"
cp --update=none "$DL/tos.en.srt" "$EX/Movies/Tears of Steel (2012)/Tears of Steel (2012).en.srt"

S="$EX/TV/The Beverly Hillbillies (1962)/Season 01"
mkdir -p "$S"
for e in 01 02; do
  cp --update=none "$EX/Movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).m4v" "$S/The Beverly Hillbillies (1962) - S01E$e.m4v"
done

# Payloads for the download chain (served to qBittorrent by a local web seed later).
# Big enough for Sonarr's minimum size of a 30-minute 1080p episode (120 MB).
cp --update=none "$EX/Movies/Sintel (2010)/Sintel (2010).mkv" "$SEED/files/Pioneer.One.S01E01.1080p.WEB-DL.AAC2.0.H.264-TEST.mkv"
cp --update=none "$DL/tos.mov" "$SEED/files/Elephants.Dream.2006.1080p.WEB-DL.AAC2.0.H.264-TEST.mov"
# For the adult-library chain through the plugin (a neutral test clip, served in category 6000).
cp --update=none "$EX/Movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).m4v" "$SEED/files/Adult-Test.Sample.Clip.1080p.m4v"
# For the Tortugarr plugin chain (what the public app uses). The title is a feature film
# (82 min, released by its author under CC0), so a 1.1 GB file fits both the app's movie
# minimum (700 MB) and Radarr's size limit per minute; a short film cannot pass both.
cp --update=none "$DL/sintel-1080p.mkv" "$SEED/files/Sita.Sings.the.Blues.2008.1080p.WEB-DL.AAC2.0.H.264-TEST.mkv"

# Owned by the user the installer will run the services as, so Bazarr can write
# subtitles next to the movies.
chown -R "${SUDO_UID:-1000}:${SUDO_GID:-1000}" "$EX"
echo "existing library:"; find "$EX" -type f -printf '  %s  %p\n'
echo "seed files:"; find "$SEED/files" -type f -printf '  %s  %p\n'
