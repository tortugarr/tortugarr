# Changelog

## 4.20.04 - 2026-11-12 (app build 2000061, Tortugarr plugin 1.3.0.37, Moonfin 3.0.0)

**App**

- **New theme: Tortuga**, on from the start (Settings › Appearance › Theme). Dark wood,
  parchment text, brass accents, pirate headings and a soft lantern glow on the focused card;
  everything you read stays in the normal font. No blur, so it stays smooth on slower TVs. An
  app updated from Moonfin's default theme moves to Tortuga once; a theme you pick later stays.
  Under Tortuga the side menu has pirate names (Harbor, Spyglass, Booty, Captain's Quarters …),
  also shown in brackets under Settings › Navigation.
- **Harbor, a new Home** (Settings › Home Screen › Row Type › Harbor, the default): the
  focused title fills the screen, one row at a time as a 3D cover flow, a Spotlight of random
  titles, My Media as wide library tiles, Networks/Studios/Genres as logo tiles, collections as
  a small stack and big rank numbers on real rankings only. The focused title's trailer plays
  muted after a moment, in the background or a corner box (or off). On phones and tablets:
  swipe sideways through the cards, up and down between rows, tap to open.
- **Poster badges:** BB (blockbuster) and MB (mockbuster) on movies, and the studio or network
  logo on movies, series and episodes, everywhere posters are shown. Settings › Home Screen ›
  Poster badges: colours, opacity, corner, size, logo or app icon, and *Show mockbusters* to
  hide mockbusters from Home.
- **Top lists:** eight new lists (Trending, Netflix Top 10, Rotten Tomatoes, Certified Fresh)
  next to the four from before; each one can be switched on or off (Settings › Home Screen ›
  Top lists). Streaming rows "Popular on Netflix / HBO Max / Disney+ / Apple TV+ / Prime Video
  / SkyShowtime" show what is popular there now (External Sources).
- **New rows:** *On the way in* (Booty) shows your downloads with progress and time left;
  *Fits tonight* shows unwatched films under 1 h 45 and the next episode of your series.
- **SmartTube** (by Yuriy Liskov), when it is installed: an entry in the side menu, trailers
  from a title's page play there (*Play trailers in SmartTube*, Settings › Appearance › Details Page; off
  plays them in Tortugarr), and a search without results offers *Search in SmartTube*. Never
  the YouTube app. Install SmartTube first. *Show SmartTube button* under Settings ›
  Navigation; credit in About.
- **Requests:** a 4K request shows Available once the title is in the library.
- The download bar names the title being downloaded.
- Home rows switched off stay listed under Settings › Home Screen › Rows, so they can be
  switched on again (Seerr, IMDb and TMDB rows used to disappear).
- Switches are visible on a focused settings row.
- The app says Tortugarr, not Moonfin, where it means itself.

**Server** (Tortugarr plugin 1.3.0.37)

- **Imports in seconds:** movies, documentaries and series download into a hidden `.incoming`
  folder inside their own library on the drive being filled, so Radarr and Sonarr move the
  finished file instead of copying it. A download started in the app goes to the library its
  title lives in.
- Finished torrents are no longer moved between drives when the download folder changes drive
  (qBittorrent's *relocate on category change* is switched off).
- The movie and series download folders follow the drive to fill, also for what Radarr, Sonarr
  and Seerr grab on their own.
- Seerr's 4K status is kept in step with the library.
- Servers still on the first four top lists get the eight new ones.
- Installer: Jellyfin's library folders are writable, so titles can be deleted from the app;
  the streaming rows are added to Seerr (switched off until chosen in the app).

**Installer**

- **Windows: no false "network is Public" warning with a VPN.** `doctor` and setup now check
  the network the server's address is on. Before, a VPN or virtual network listed first by
  Windows (WireGuard, Hyper-V) gave "the firewall blocks other devices", and setup could offer
  to change that network instead of your home network.

## 4.20.03 - 2026-11-08 (app build 2000060, Tortugarr plugin 1.3.0.32, Moonfin 3.0.0)

**App**

- **Now based on Moonfin 3.0.0.** Everything new from Moonfin since 2.7.0 is the work of the
  [Moonfin team and contributors](https://github.com/Moonfin-Client/Moonfin-Core/releases); see
  their release notes for what it brings. Tortugarr's own changes are kept on top, and a
  routine with checks (`docs/MOONFIN-UPSTREAM.md`) makes sure a Moonfin update cannot quietly
  undo them. The points below are Tortugarr's own work.
- **Release picker:** most seeders first, live seeder counts from the trackers, dead torrents
  hidden, and Left/Right switches resolution tier straight from the list, with sound badges per
  release.
- **Held seek speeds up** gently, on the seek bar too (20x, 40x, 90x, 180x, up to 300x); a
  single press still skips by the step you set.
- **Subtitles:** the menu shows only the languages you picked; untagged tracks only when there
  is no track in your language.
- **Home rows from top lists** (IMDb Top 250, Trakt, weekly Top 10).
- **Administration on TV** works with the remote everywhere: focus starts on the page list,
  stays on screen, Back goes one step at a time, Left goes to the menu.
- **Server health** card on the admin dashboard: services, library drives and *arr warnings.
- **Plugin settings open inside the app**, signed in; Tortugarr's own settings are a native
  screen made for the remote.
- The activity count on the dashboard counts only new warnings and errors.
- Downloads: an imported title leaves *Importing* at once; series without a TVDB id on TMDB can
  be downloaded; Seerr *Requests* also lists series downloaded in the app.
- XXX: titles can be deleted, and the search box keeps its text.
- The intro video starts only once its first picture is on screen (no stutter at start).

**Server** (Tortugarr plugin 1.3.0.32)

- **Fill the fullest drive first:** new movies, series and downloads go to the drive with the
  least free space that still keeps 25 GB free (*Fill drives down to* setting; 0 = always the
  roomiest drive). No more downloads dead-ending on a full drive: a title is moved to a drive
  with room before the grab, and a held import is moved to the roomiest drive.
- **Torrent clients:** Transmission and Deluge work as well as qBittorrent.
- **Phone notifications** through the stack's own ntfy server: download ready, problems that
  need the admin.
- **Stuck downloads** are handled: a nudge when data stops, a swap, delete or stop after 3
  hours, a watchdog for torrents stuck at 100 %, fake downloads removed, and a video check on
  every torrent.
- Releases for a different movie are dropped, Radarr's own grabs of early "mockbuster"
  releases are refused, and a title whose folder is taken gets a tagged folder.
- Moonbase updates only after an app-contract check; playlists and collections can be deleted
  again.
- Installer: ntfy in the stack, OMDb off for TV libraries, and `doctor` checks ntfy's folder
  and library path mappings without false alarms.

## 4.20.02 - 2026-10-27

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
- Android TV: the mouse wheel scrolls again with a wireless keyboard + mouse receiver, and
  Down in the admin menu moves one step (Library and People were skipped).
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
