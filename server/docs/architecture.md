# Architecture

## Files

```
tortugarr-server/                 this repository
├── install.sh                  entry point (Linux only)
├── versions.env                pinned images (tag@digest) and plugin version
├── compose/compose.yml         the stack; optional parts are Compose profiles
├── lib/                        installer shell code (detect, docker, stack, prompts)
├── bootstrap/                  configuration engine (Python, standard library only)
├── i18n/                       installer texts: en (reference), nb, sv, da, de
├── docs/
└── tests/                      end-to-end tests used to verify the installer

/opt/tortugarr/                   an installation
├── app/                        copy of the installer that installed it
├── state.json                  every choice + everything created (drives repair/uninstall)
├── secrets.json                admin password and API keys (0600)
├── .env                        generated Compose environment (0600)
├── compose.yml                 copy of compose/compose.yml
├── overrides/                  media.yml, vpn.yml, vpn.env, hwaccel.yml (generated)
│                               local.yml (yours; never overwritten)
├── config/<service>/           each service's own settings and database
├── backups/                    tortugarr-backup-*.tar.gz (newest 10 kept)
├── logs/                       one log per installer run
├── app-config.json             values for the app
└── download_now_secrets.dart   the same, ready to drop into the app source

<data folder>/                  default /srv/tortugarr
├── media/movies  media/tv      the library (Jellyfin reads it read-only)
├── torrents/{movies,tv,prowlarr}
└── usenet/{complete,incomplete}
```

## Principles

- **Only Docker on the host.** The configuration engine runs in a throwaway
  `python:3.12-alpine` container on the `tortugarr` network and talks to each
  service's API by container name.
- **Pre-seed, then configure.** Before the first start the installer writes the
  config files that must exist from the beginning (API keys and login for the
  *arrs, the qBittorrent password hash, SABnzbd's API key). After start, everything
  else is set through the services' own APIs.
- **Idempotent.** Every configuration step looks for its own earlier result (by
  name) and updates it instead of adding a duplicate. `repair` re-runs all of it.
- **Record what was created.** `state.json` lists what the installer created
  (Docker installed, docker group, ufw rules). Uninstall removes
  exactly that and nothing else.
- **Media is never touched** by repair, restore or uninstall.
- **Pinned versions.** Images are pinned by digest in `versions.env`; the Moonfin
  plugin by version, with Jellyfin's auto-update switched off for it.

## Ports

| Port | Service | Published |
|---|---|---|
| 8096 | Jellyfin | LAN |
| 5055 | Seerr | LAN |
| 8989 | Sonarr | LAN (the app's Download Now uses it) |
| 7878 | Radarr | LAN (the app's Download Now uses it) |
| 9696 | Prowlarr | LAN (the app's quality probe uses it) |
| 8080 / 9091 / 8112 | qBittorrent / Transmission / Deluge web UI | LAN |
| 6881 tcp+udp | torrent peers | all interfaces |
| 8085 | SABnzbd | LAN |
| 8191 | FlareSolverr | not published (Prowlarr only) |

## Security notes

- Every web UI requires the admin login (Jellyfin, Seerr via Jellyfin, the *arrs
  with forms login, qBittorrent/Transmission/Deluge/SABnzbd with the password).
- The services are meant for your home network. Do not forward these ports on your
  router; use a VPN (e.g. WireGuard/Tailscale) to reach them from outside.
- `secrets.json`, `.env`, backups and the app files are readable by root only.

## Known limitations

- Sonarr/Radarr's built-in *Emby / Jellyfin* connection cannot notify Jellyfin
  10.11+/12 - it still sends an authentication header Jellyfin removed, and fails
  with 401 even with a valid key. The installer instead adds a *Webhook* connection
  ("Tortugarr: refresh Jellyfin") that POSTs to `/Library/Refresh` with the header
  `Authorization: MediaBrowser Token="<Jellyfin API key>"` after every import, rename
  or delete. The library scan every 30 minutes stays as a safety net.
- Transmission and Deluge cannot block file types; the title filter and
  Sonarr/Radarr import checks still stop fake `.exe` releases, but the file is
  downloaded first. qBittorrent is recommended for that reason.
- The VPN option needs your provider's details and cannot be verified by the
  installer until they are filled in.
