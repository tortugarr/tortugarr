# Changelog

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
