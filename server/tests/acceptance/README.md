# Acceptance test

A full test of every service on a **clean test machine** (never next to a running
media stack). About 30-45 minutes and ~3 GB of downloads, all freely licensed
(Blender Foundation open movies, CC-BY).

```bash
sudo bash tests/acceptance/prepare-media.sh                              # existing library + seed files
sudo ./install.sh install --answers tests/acceptance/answers.env          # installer points at it
sudo bash tests/acceptance/acceptance.sh                                  # proves it, writes the report
```

| Part | What it proves |
|---|---|
| 1. Existing library | Jellyfin identifies the three films and the test series in a folder the user already had; Radarr/Sonarr register them with their files (unmonitored, so nothing is re-downloaded) |
| 2. Indexer | Prowlarr adds a local Torznab feed (only the two test releases), searches it and syncs it to Sonarr/Radarr; Internet Archive is not used - archive.org throttles Prowlarr (HTTP 429 / timeouts), an external limit |
| 3. Download chain | A series and a film go Seerr -> Sonarr/Radarr **automatic search** -> qBittorrent (local web seed, no public swarm) -> **automatic** import (hardlink) -> Jellyfin |
| 4. Subtitles | Bazarr sees the official subtitle next to Tears of Steel, and tries the account-free sources; a subtitle extracted from the video file is reported apart from one downloaded from the internet |
| 5. Report | `/opt/tortugarr/acceptance-report.md`: per service, what was proven and what was not tested |

The test series and the two download-chain titles reuse the open-movie files under
episode/release names: Sonarr, Radarr and Jellyfin identify media by name.
