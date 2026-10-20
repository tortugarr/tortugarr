# Tortugarr Server - installing and running it

A one-command installer for a complete, self-hosted media server that the
**Tortugarr** app (a Moonfin-based Jellyfin client for Android TV and phones) is
built to work with.

It installs, connects and secures every piece, so you end up with a working
system instead of a weekend of configuration:

| Service | What it does |
|---|---|
| **Jellyfin** | Media server - plays your library on the TV, phone and web |
| **Seerr** | Browse and request movies/shows (the app's "request" screen) |
| **Sonarr / Radarr** | Find, download and organise TV shows / movies |
| **Prowlarr** (+ FlareSolverr) | Manages your indexers for Sonarr and Radarr |
| **Bazarr** | Fetches subtitles for everything Sonarr and Radarr download |
| **Torrent client** | Your choice: **qBittorrent**, **Transmission** or **Deluge** in Docker, a **qBittorrent you already have** (on Windows, say), or none |
| **SABnzbd** (optional) | Usenet downloads |
| **gluetun** (optional) | Sends all torrent traffic through your VPN, with a kill switch |
| **Moonfin plugin** | Server side of the Tortugarr app (settings sync, Seerr proxy) |

> **Please read [DISCLAIMER.md](../DISCLAIMER.md).** Tortugarr ships software only - no
> content, no indexers, no accounts. What you add is your decision and your
> responsibility.

## Contents

- [What you get](#what-you-get)
- [Requirements](#requirements)
- [Install](#install)
- [Media folders you already have](#media-folders-you-already-have)
- [Using a qBittorrent you already have](#using-a-qbittorrent-you-already-have)
- [After installing](#after-installing-your-part)
- [Managing it](#managing-it)
- [Languages](#languages)
- [How it works](#how-it-works)
- [Troubleshooting](troubleshooting.md) · [The app](app.md)

## What you get

- **Everything wired together automatically**: Prowlarr syncs indexers to Sonarr and
  Radarr, both use your download client, Seerr sends requests to them, Jellyfin
  picks up the results, and the Moonfin plugin connects the app to Seerr.
- **One login for everything**: the username and password you choose during the
  install, applied to Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr and the download client.
- **Junk protection out of the box**:
  - cam/telesync/screener releases are rejected (quality profiles *and* a title filter),
  - fake releases that are really Windows programs (`.exe`, `.scr`, `.lnk`, ...) are
    rejected by title, refused by Sonarr/Radarr at import, and - with qBittorrent -
    never even downloaded.
- **Instant imports**: downloads and library share one data folder, so finished
  downloads are hardlinked into the library - no copying, no double disk use.
- **Pinned, tested versions**: every image is pinned by digest. An install today and
  one in a year run exactly the same software. Updates are deliberate.
  The Moonfin Jellyfin plugin starts at the version the Tortugarr app was tested with and
  then keeps itself up to date through Jellyfin's automatic plugin updates; installing a
  newer one from the dashboard is fine.
  Likewise, Radarr, Sonarr, Prowlarr, Bazarr, Seerr and qBittorrent may show "New update is
  available" in their web pages. That is expected and harmless: each is pinned in
  `versions.env` to a version tested together with the app. Do not update them from their web
  pages (inside Docker that does not work anyway); newer versions arrive with
  `sudo tortugarr update` when Tortugarr itself is updated.
- **Repair, update, backup, restore and uninstall** built in (see below).

## Requirements

- **Linux only**: Ubuntu 22.04, 24.04 or 26.04 (other Debian-based systems usually work),
  x86-64 or ARM64, 4 GB RAM, systemd. Docker is installed for you if missing.
- **Windows is not supported.** Windows users can set up WSL2 or a Linux VM themselves
  and run the Linux installer there; it warns and asks before it continues inside WSL2.
  Only inside WSL2 it then offers an optional, best-effort **Windows helper**, and you have to
  choose actively - there is no default: *let the installer do it* (one administrator approval:
  port forwarding from your Windows LAN address into WSL, firewall rules for exactly the
  Tortugarr ports, and a keep-alive that starts WSL with Windows), or *skip - I will do it
  myself* (the exact commands are shown and saved to `/opt/tortugarr/windows-setup-yourself.txt`).
  If Windows has marked your network as Public, the helper asks you to set it to Private
  (recommended at home), to allow the ports from the local subnet only, or to leave it. Run it
  later with `sudo tortugarr windows`; `sudo tortugarr uninstall` removes it again.

> [!CAUTION]
> **The Windows helper (WSL2 only) changes Windows, not just WSL:**
> 1. **All WSL distros on the PC share the same ports.** Another distro (or program) using
>    8096, 8080, ... will clash with Tortugarr.
> 2. **The keep-alive keeps the whole of WSL - every distro - running and in memory**, also
>    right after Windows starts.
> 3. **Windows' firewall and port forwarding are changed**: a rule group "Tortugarr" and
>    forwarding for exactly the Tortugarr ports.
>
> Uninstall removes all of it again; `.wslconfig` is never touched. WSL2 itself stays
> unsupported.
- Disk space for your media, plus ~5 GB for the software.
- Your own indexers (and optionally a usenet provider and/or VPN subscription).

## Install

Download or clone this folder to the machine first.

### Linux

A dedicated machine (an old PC, a mini-PC, a NAS that runs Ubuntu) is the most
reliable choice: it runs 24/7, starts by itself, and other devices reach it directly.

```bash
cd tortugarr-server
sudo ./install.sh
```

The installer checks the machine, asks a few questions (most with sensible defaults;
the login you choose yourself), shows a summary, and then does the rest. It takes
5-15 minutes, mostly downloading images.

### Unattended install

Copy [answers.example.env](answers.example.env), fill it in, then:

```bash
sudo ./install.sh install --answers answers.env
```

## Media folders you already have

The installer asks for folders with videos you already have, and **what is in each one**. The
name of the folder does not matter; the type decides where it shows up:

| Type | Shown in Jellyfin as | Radarr/Sonarr |
|---|---|---|
| Movies | Movies | Radarr may add to it, if you allow it |
| TV series | TV Shows | Sonarr may add to it, if you allow it |
| Adult | the hidden adult library (switch it on in the app first) | - |
| Music videos and concerts | Music Videos | - |
| Other videos (clips, home videos) | Home Videos | - |

With several folders of one type, possibly on several drives, a new movie or series goes to the
one with the most free space. `sudo tortugarr reconfigure` lists your folders and lets you change
the type of each, remove one (nothing on the drive is deleted) or add more.

## Using a qBittorrent you already have

The installer's torrent client question offers **qBittorrent I already have**. Choose it when
qBittorrent is installed outside Tortugarr, for example on Windows next to WSL. Tortugarr then
starts no qBittorrent container and uses yours:

1. **Web UI on.** In qBittorrent: *Tools > Options > Web UI*. Note its port.
2. **Let Docker in.** Radarr and Sonarr reach qBittorrent from Docker's network. Either give the
   installer qBittorrent's user name and password, or under *Web UI > Bypass authentication for
   clients in whitelisted IP subnets* add `172.16.0.0/12`.
3. **Answer the questions.** The address (for example `http://192.168.1.15:8080`) and, if you
   use one, the login. The installer reads where qBittorrent saves downloads (its default save
   folder and the `radarr` and `sonarr` categories, which it adds when missing) and shows what
   it will do with them.

What the installer then sets up:

- **The download folder in Docker.** A Windows folder such as `H:\Downloads` is `/mnt/h/Downloads`
  in WSL; it is mounted into Radarr and Sonarr as `/data/torrents-ext/1`.
- **Remote path mappings** in Radarr and Sonarr from qBittorrent's paths to that folder
  (`H:\Downloads\` -> `/data/torrents-ext/1/`), so finished downloads are found and imported.
  Older mappings for the same qBittorrent that point elsewhere are removed.
- **A check** that Radarr and Sonarr reach qBittorrent and can see the folder.
- **More drives:** other drives with room can be added as download folders (the installer offers
  them and creates `X:\Downloads\radarr` and `\sonarr`). Each download then goes to the drive
  with the most free space.

Your qBittorrent's settings are otherwise left alone. If it does not block program files, the
installer says so: turn on *Tools > Options > Downloads > Excluded file names* with
`*.exe`, `*.scr`, `*.lnk`, `*.msi`, `*.bat`, `*.cmd`, `*.com`, `*.pif`, `*.vbs`, `*.js`.

Hardlinks do not work across a Windows drive, so a finished download is **copied** into the
library and takes its space twice while it is still seeding. Keep room for that on the drive.

Already switched to your own qBittorrent by hand? Run `sudo tortugarr reconfigure` and choose
**qBittorrent I already have**; the Tortugarr container is removed and the paths are set up.
`sudo tortugarr doctor` points this out when Radarr or Sonarr download somewhere else than the
client Tortugarr set up.

## After installing (your part)

The installer prints the addresses at the end; you log in everywhere with the username
and password you chose (show them again any time with `sudo tortugarr credentials`). Then:

1. **Add indexers in Prowlarr** (`http://<server>:9696` > Indexers > Add Indexer).
   They appear in Sonarr and Radarr automatically. If an indexer is behind
   Cloudflare (its test fails with a Cloudflare or 403 error), give it the tag
   `flaresolverr`. Its test can then take several minutes - wait for it.
2. *(Usenet)* add your provider in SABnzbd (Config > Servers).
3. *(VPN)* the settings are in `/opt/tortugarr/overrides/vpn.env`.
4. **Install the Tortugarr app** on your TV/phone and point it at
   `http://<server>:8096`. See [docs/app.md](app.md).
5. Request something in Seerr or in the app. Done.

### Watching anime? Add TheTVDB to Jellyfin

Sonarr numbers anime episodes the way TheTVDB does, and Seerr is set up to use
TheTVDB for anime too. Jellyfin uses TMDB, which often splits anime into seasons
differently, so episode titles and pictures can be wrong or missing. To make Jellyfin
follow the same numbering:

1. In Jellyfin (`http://<server>:8096`): **Dashboard > Plugins > Catalog > TheTVDB >
   Install**, then restart Jellyfin (Dashboard > Restart).
2. **Dashboard > Libraries > TV Shows > Manage library** (the ⋮ menu). Under the
   metadata downloaders for **Series**, **Seasons** and **Episodes**, tick **TheTVDB**
   and **drag it to the top**, above TheMovieDb. Do the same under image fetchers if
   you like. Save. Without this step Jellyfin keeps using TMDB first.
3. For anime series that are already in the library: open the series > ⋮ >
   **Refresh metadata** > **Replace all metadata**.

Not needed for ordinary series - their numbering is the same in TMDB and TheTVDB.

## Managing it

After installation the command `tortugarr` is available:

```bash
sudo tortugarr              # menu
sudo tortugarr status       # what runs where
sudo tortugarr doctor       # find problems, with a fix for each
sudo tortugarr repair       # fix containers, settings, ports and connections - keeps everything
sudo tortugarr reconfigure  # switch torrent client, VPN, usenet, ports, extra folders
sudo tortugarr update       # newer versions: backup first, automatic rollback if it fails
sudo tortugarr backup [--with-images]
sudo tortugarr restore <backup.tar.gz>
sudo tortugarr uninstall [--purge]
sudo tortugarr credentials
sudo tortugarr logs [service]
```


**Backups** contain every setting, password and database - never your movies or
shows. They are verified with checksums, and `restore` works on a fresh machine as
well (it rebuilds the whole installation from the backup). With `--with-images`
the exact container images are included too, so a restore brings back the
identical software even if those versions are no longer downloadable.

**Uninstall** removes exactly what the installer created (containers, network,
firewall rules) and asks before deleting settings. Your media is
never deleted.

## Languages

The installer speaks **English**, **Norsk**, **Svenska**, **Dansk** and **Deutsch**
(`--lang nb`, or chosen at the start). Adding a language is one file:
copy `i18n/en.sh` and translate the values.

## How it works

```
                 ┌──────────── tortugarr Docker network ─────────────┐
 TV / phone ───► │ Jellyfin :8096 ◄─ Moonfin plugin ─► Seerr :5055 │
                 │     ▲                                  │        │
                 │     │ library scan            requests ▼        │
                 │  /data/media ◄─ hardlink ─ Sonarr / Radarr      │
                 │                               │   ▲             │
                 │  /data/torrents ◄─ client ◄───┘   └── Prowlarr  │
                 └──────────────────────────────────────────────────┘
```

- Installed to `/opt/tortugarr` (settings, state, backups, a copy of this installer);
  media and downloads in the data folder you choose (default `/srv/tortugarr`).
- `state.json` records every choice and everything the installer created;
  `secrets.json` holds your login and the generated API keys (root only).
- The configuration engine (`bootstrap/`) runs in a throwaway Python container and
  talks to each service's own API. It is idempotent: `repair` simply runs it again.
- Your own Compose changes go in `/opt/tortugarr/overrides/local.yml` - never overwritten.

More: [docs/architecture.md](architecture.md).

## License and credits

The installer is released under the GNU General Public License v2 (see
[LICENSE](../LICENSE)), the same license as the Moonfin app it serves.

It installs, unmodified, the work of these projects: Jellyfin, Sonarr, Radarr,
Prowlarr, Seerr, FlareSolverr, qBittorrent, Transmission, Deluge, SABnzbd, gluetun
and the linuxserver.io images, and the Moonfin server plugin. All trademarks belong
to their owners.
