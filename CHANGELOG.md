# Changelog

## 4.20.02 - unreleased

**App**

- **Automatic player** (Android TV): each film starts on Media3 or mpv, whichever plays that
  kind of file best, and the app switches by itself when playback stutters or never gets going.
  The new *Player* button in the player picks one by hand for a film.
- **Download limits** for users who are not administrators: a size limit per movie and per
  episode and a number per week. Files over the limit are greyed out; the server refuses a
  download over a limit. Set them under Administration > Users > a user > Permissions.
- Audio: the language you chose wins over the file's default track (a release that marks an
  Italian dub as default now starts in English for someone who picked English).
- Norwegian: about 1,700 texts that showed in English are translated.
- Seerr: the Networks and Studios rows (Netflix, HBO, Disney+, Viaplay …) are back, *Recently
  Added* shows titles again, and the search button opens the main search on its Seerr tab.
- Cancel in a release search closes at once, also after a quick double tap.
- Settings: Administration and Language at the top, *Picture & Sound System* in Playback, and
  About has check for updates, diagnostics, licenses and the privacy policy again.
- New users are asked in the setup wizard whether Trending and Popular show only titles in
  their languages.

**Server** (Tortugarr plugin 1.3.0.0, Moonfin plugin 2.4.0.0)

- The plugin's page in Jellyfin (Dashboard > Plugins > Tortugarr) holds all its settings:
  connections with a Test button, download limits per user, download folders, the adult
  library and the release filters. Keys and passwords are never shown.
- New series and movies get a quality profile named `720p-2160p` when Radarr/Sonarr have one,
  and a download no longer moves a movie off a profile that already takes its quality.
- The installer retries a library import that hit Radarr's collection race, and `doctor`
  reports a user folder that Radarr or Sonarr lost.

## 4.20.01 - 2026-10-21

**App** (now built on Moonfin 2.7.0, with Moonfin's full git history)

- The phone app does everything the TV app does, and has a remote control for the TV.
- Download progress shows from the moment a file is picked, also for episodes of a series that
  is otherwise complete. Cancelling a request stops its download.
- Missing episodes: the file list has 2160p / 1080p / 720p / other / all tabs, as for movies.
- Subtitles: one menu with only your languages, and size, height and colour at the bottom.
  Showing two subtitle tracks at once is gone.
- Settings: *Short intro*, *Loading logo size* (25-100 %), and language filter changes that
  show at once on an open Seerr page.

**Server** (Tortugarr plugin 1.2.8.0, Moonfin plugin 2.4.0.0)

- VPN: any provider gluetun knows, or *custom* with your own WireGuard `.conf` or OpenVPN
  `.ovpn` file.
- Answer *no* at the summary to go through the questions again, with your answers kept.
- Every Prowlarr indexer gets the `flaresolverr` tag, so sites behind Cloudflare work.
- A new folder type *Documentaries*: only documentaries go there, also when requested in Seerr.
  On one drive a new movie goes to the folder that already holds the most movies.
- Tortugarr's own empty movie and series folders leave Radarr and Sonarr when you have your own.
- An uninstall that deletes the settings keeps every backup, in `/var/backups/tortugarr`.
- The adult library is switched on by an administrator in Jellyfin: Dashboard > Plugins >
  Tortugarr > Adult library.
- Installer: answers can be edited with the arrow keys, and arrow up brings back earlier ones.
  Ubuntu 26.04 is supported.
- Tested together and pinned: Jellyfin 12.2.0, Seerr 3.5.0, Sonarr 4.0.20, Radarr 6.4.4,
  Prowlarr 2.6.5, Bazarr 1.6.2, FlareSolverr 3.5.2.

## 4.20.0 - 2026-10-07

First release of Tortugarr: your own streaming service at home.

**Server**

- One installer sets up and connects Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr, the
  download client and the Tortugarr plugin on Ubuntu 22.04 or 24.04.
- The app signs in with a short code from the TV, typed into a phone.
- The Tortugarr Jellyfin plugin does the downloads, deletes and subtitles on the server, so the
  app holds no keys or passwords.
- Optional Windows helper for an install inside WSL2 (not supported, best effort).

**App** (Android TV / Google TV, and Android phones and tablets; based on Moonfin)

- Browse what is trending, popular and coming soon, right on the TV, with the remote.
- *Download Now*: see every release with its quality, size and seeders, and pick the exact file.
- Cinema recordings, fake releases and hidden `.exe` files are filtered and blocked.
- Series: see which episodes are missing, grab one or a whole season, or let a season follow
  itself as new episodes air. Film series show the parts you have, miss and are coming.
- Subtitles are fetched automatically, and can be searched from the TV.
- Delete from the TV removes the file, the download and the request; low disk space is shown
  with what is safe to remove.
- Nothing phones home: the app talks to your server only.

**Known limits**

- Tortugarr features are for Jellyfin administrators only in this version.
- Usenet, VPN, Transmission and Deluge are set up by the installer but not tested end to end.
