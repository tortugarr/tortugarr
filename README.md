<p align="center">
  <img src="docs/images/screensaver-sign.webp" alt="Tortugarr" width="520">
</p>

<h1 align="center">Every pirate needs a harbor.</h1>

<p align="center">
  <b>Moonfin for Jellyfin on Android TV, taken further: find and download right from the remote.</b><br>
  One installer sets up the whole *arr stack for you. No subscriptions, no ads, nothing disappears.
</p>

> **Built on [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core).** The Tortugarr app is a
> fork of Moonfin-Core 2.7.0, with Moonfin's full git history kept and Tortugarr's work on top.
> Media playback, multi-server support and the design engine are the work of Moonfin and its
> contributors. Tortugarr adds the one-command
> server installer, the Tortugarr Jellyfin plugin, junk-release filtering and Download Now from
> the TV. Report Tortugarr bugs to the [Tortugarr issue tracker](https://github.com/tortugarr/tortugarr/issues),
> not to Moonfin: the Moonfin developers do not support Tortugarr builds.

<p align="center">
  <a href="https://github.com/tortugarr/tortugarr/releases/latest"><img alt="Release 4.20.02" src="https://img.shields.io/badge/release-4.20.02-8b5a2b"></a>
  <a href="LICENSE"><img alt="License: GPL-2.0" src="https://img.shields.io/badge/license-GPL--2.0-blue"></a>
  <img alt="App: Android TV, Google TV, phone" src="https://img.shields.io/badge/app-Android%20TV%20%C2%B7%20Google%20TV%20%C2%B7%20phone-3ddc84">
  <img alt="Server: Ubuntu 22.04, 24.04, 26.04" src="https://img.shields.io/badge/server-Ubuntu%2022.04%20%C2%B7%2024.04%20%C2%B7%2026.04-e95420">
</p>

<p align="center">
  <a href="#get-started-in-about-15-minutes"><b>Get started</b></a> ·
  <a href="https://github.com/tortugarr/tortugarr/releases/latest"><b>Download</b></a> ·
  <a href="docs/FAQ.md"><b>FAQ</b></a> ·
  <a href="server/docs/troubleshooting.md"><b>Troubleshooting</b></a> ·
  <a href="#take-it-further-"><b>Build on it</b></a>
</p>

<p align="center">
  <img src="docs/images/tv-home.webp" alt="Tortugarr on a TV" width="900">
</p>

---

## Five subscriptions, and still nothing to watch?

Shows vanish. Prices go up. The film you wanted is "not available in your region".

**Tortugarr turns a spare PC into your own streaming service.** It looks and feels like the
big apps, it runs on your TV with the normal remote, and everything you add stays.

## From the sofa, in three clicks

1. **Browse** what is trending, popular and coming soon, right on the TV.
2. **Pick** *Download Now*, and choose the exact file: quality, size, how many share it.
3. **Watch.** It lands in your library on its own, with subtitles.

No laptop. No copying files around. No fiddling with five web pages.

<p align="center">
  <img src="docs/images/tv-download-now.webp" alt="Download Now: pick the exact file, by quality, size and seeders" width="900"><br>
  <sub><b>Download Now</b>: every release, sorted by quality, with size and seeders. You pick; it does the rest.</sub>
</p>

## Why people keep it

- 🛋️ **Made for the remote.** Every feature works from the sofa, on Android TV and Google TV.
- 🎯 **You choose the file.** No black box: see every release, its quality and size, and pick.
- 🛡️ **Fakes stay out.** Cinema recordings, fake releases and hidden `.exe` files are filtered
  and blocked before they reach your library.
- 📺 **Series that complete themselves.** See exactly which episodes you are missing, grab one,
  a whole season, or let a season follow itself as new episodes air.
- 💬 **Subtitles included.** Fetched automatically by your server. Missing one? Find it from
  the TV.
- 🧹 **Cleans up after itself.** Delete from the TV and the file, the download and the request
  all go. Running low on space? It tells you what is safe to remove.
- 🔒 **Nothing phones home.** No account with us, no tracking, no analytics. The app talks to
  your server, fetches posters and trailers from public sites such as TMDB and YouTube, and
  asks GitHub whether a new Tortugarr release is out. The app itself holds no keys or
  passwords. Details: [privacy policy](PRIVACY_POLICY.md).
- 📱 **TV, phone and tablet.** Same library everywhere; start on the phone, finish on the TV.
  The phone app does everything the TV app does, and doubles as a remote for the TV.

<p align="center">
  <img src="docs/images/tv-collection.webp" alt="Film series: see which parts you are missing" width="900"><br>
  <sub>Film series at a glance: the parts you have, the ones you are <b>missing</b> (one click to get them), and what is <b>coming</b>.</sub>
</p>

<p align="center">
  <img src="docs/images/tv-player.webp" alt="Playback" width="440">
  &nbsp;
  <img src="docs/images/phone-login.webp" alt="Tortugarr on a phone" width="160">
</p>

## See it in action

<p align="center">
  <img src="docs/media/tv-browse.gif" alt="Browsing on the TV: recently added, a film page and its film series" width="720"><br>
  <sub>Browse with the remote: open a film and see the whole film series – what you have, what is <b>missing</b>, what is <b>coming</b>.</sub>
</p>

<p align="center">
  <img src="docs/media/tv-delete.gif" alt="Deleting a film from the TV" width="720"><br>
  <sub>Delete from the sofa. It asks first, then the file, the download and the request are gone.</sub>
</p>

▶️ Full videos: [TV app, 48 s](https://github.com/tortugarr/tortugarr/raw/main/docs/media/tv-demo.mp4) · [Installing, 1:26 sped up](https://github.com/tortugarr/tortugarr/raw/main/docs/media/install-timelapse.mp4) · [Uninstalling, 42 s](https://github.com/tortugarr/tortugarr/raw/main/docs/media/uninstall.mp4)

<details>
<summary><b>More screenshots</b></summary>
<br>
<p align="center">
  <img src="docs/images/tv-home-banner.webp" alt="Home screen banner" width="440">
  <img src="docs/images/tv-movie-available.webp" alt="A film page, available in your library" width="440">
  <img src="docs/images/tv-trending.webp" alt="Trending films and series" width="440">
  <img src="docs/images/tv-requests.webp" alt="Recent requests with their status" width="440">
</p>
</details>

## How it works

One command sets up the whole harbor. A few questions with sensible defaults, then the installer
sets up and connects everything: Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr, the download
client and the Tortugarr plugin. The app talks to your Jellyfin server; downloads, deletes and
subtitles go through the Tortugarr plugin there, so the app holds no keys.

Tortugarr does not bundle these tools. They are independent open-source projects; the installer
downloads their official releases and wires them together.

```mermaid
flowchart LR
  app["📺 Tortugarr app<br/>TV · phone · tablet"] -->|port 8096| jf["Jellyfin<br/>+ Tortugarr plugin"]
  jf --> arr["Sonarr · Radarr"]
  jf --> bazarr["Bazarr<br/>subtitles"]
  seerr["Seerr<br/>requests"] --> arr
  prowlarr["Prowlarr<br/>your indexers"] --> arr
  arr --> dl["Download client<br/>qBittorrent · Transmission · Deluge · SABnzbd"]
  dl --> media[("Your media folder")]
  media --> jf
```

Ports, files and security notes: [**architecture**](server/docs/architecture.md).

## Get started in about 15 minutes

Everything you need is on the **[Releases page](https://github.com/tortugarr/tortugarr/releases/latest)**:

| File | For |
|---|---|
| `tortugarr-server-4.20.02.tar` | The server: installer + Tortugarr plugin, ready to run |
| `tortugarr-tv-4.20.02.apk` | The app for Android TV / Google TV |
| `tortugarr-phone-4.20.02.apk` | The app for Android phones and tablets |

Jellyfin, Seerr, Sonarr and the other tools are not inside these files: the installer downloads
them (and Docker, if needed) from the internet while it runs, about 5 GB the first time.

**Before you start, you need:**
- A PC or server with **Linux**: Ubuntu 22.04, 24.04 or 26.04 (64-bit). Other Debian-based systems
  usually work but are not tested.
- **4 GB RAM**, about **5 GB** for the software, and room for your movies and series.
- An **internet connection** during the install.
- Your own indexers (and, if you want, a usenet provider or a VPN subscription).
- Windows? It is not supported, but you can run the installer inside WSL2. See
  [Windows and WSL2](server/docs/install.md#requirements) in the install guide first.
  To set up WSL2 with a fixed IP address, use
  [Sentinel Greenhorn](https://github.com/sentinelarmory/greenhorn), a one-file WSL installer
  that also downloads Tortugarr for you.

### 1. Install the server

Open a terminal on the machine that will be your server and run:

```bash
wget https://github.com/tortugarr/tortugarr/releases/latest/download/tortugarr-server-4.20.02.tar
wget https://github.com/tortugarr/tortugarr/releases/latest/download/SHA256SUMS.txt
sha256sum --check --ignore-missing SHA256SUMS.txt   # should print: tortugarr-server-4.20.02.tar: OK
tar -xf tortugarr-server-4.20.02.tar
cd tortugarr-server
sudo ./install.sh
```

Answer the questions (pressing Enter takes the default), and choose the username and password
you will log in with everywhere. Docker is installed for you if it is missing. At the end the
installer prints the addresses of everything it set up.

<p align="center">
  <img src="docs/media/install.gif" alt="The installer running, sped up" width="760"><br>
  <sub>A whole install, sped up: questions, downloads, wiring everything together, done.</sub>
</p>

- Every question and option explained: the [**install guide**](server/docs/install.md).
- Which ports it uses and how the pieces connect: [**architecture**](server/docs/architecture.md).
- Something not right? Run `sudo tortugarr doctor`, then see
  [**troubleshooting**](server/docs/troubleshooting.md).

### 2. Add your indexers

Open Prowlarr at `http://<server-address>:9696` and add the indexers you want under
**Indexers > Add Indexer**. They are passed on to the rest automatically. This is the one thing
Tortugarr cannot do for you.

Sites behind Cloudflare (1337x and others) need FlareSolverr, which the installer sets up.
Tortugarr gives every indexer the `flaresolverr` tag, also ones you add later (within a few
minutes). If an indexer's test still fails with a Cloudflare or 403 error, type `flaresolverr`
under **Tags** at the bottom of its settings yourself and press **Test** again; the test can
take a few minutes.

### 3. Put the app on your TV

The TV needs to allow apps from outside the Play Store:

1. On the TV, install **Downloader** (by AFTVnews) from the Play Store.
2. Allow it to install apps: **Settings > Apps > Security & restrictions > Unknown sources >
   Downloader**.
3. Open Downloader, type the address of `tortugarr-tv-4.20.02.apk` from the Releases page, and
   install it.

Other ways work too: a USB stick with the APK, or `adb install tortugarr-tv-4.20.02.apk`.

### 4. Put the app on your phone (optional)

Open the Releases page on the phone, tap `tortugarr-phone-4.20.02.apk`, and allow your browser
to install apps when Android asks.

> 💡 **Stay up to date without thinking about it:** add this repository to
> [Obtainium](https://github.com/ImranR98/Obtainium), a free app that installs APKs straight from
> GitHub Releases and tells you when a new version is out.

### 5. Connect

Open Tortugarr, add your server (`http://<server-address>:8096`) and choose **Quick Connect**.
The TV shows a six-digit code. On your phone, open the same address in a browser, log in, tap
the profile icon > **Quick Connect**, and type the code. Done.

<details>
<summary><b>Changed your mind? Uninstall</b></summary>

On the server:

```bash
sudo tortugarr uninstall
```

It lists what it will remove and asks before it does anything:

- **Your movies and series are never touched.** Everything in the data folder
  (`/srv/tortugarr` by default) stays exactly where it is.
- **Settings and passwords:** keep them (a reinstall picks up where you left off) or delete them.
- **A backup first:** offered by default, so you can always come back.
- **Docker and the downloaded images:** removed only if you say so, and Docker only if
  Tortugarr installed it.
- **On Windows with WSL2:** the port forwarding, firewall rules and keep-alive task are removed
  too, and the network is set back the way it was.

On the TV or phone, remove the app like any other: **Settings > Apps > Tortugarr > Uninstall**.

▶️ [See an uninstall, 42 s](https://github.com/tortugarr/tortugarr/raw/main/docs/media/uninstall.mp4)

</details>

<details>
<summary><b>For developers: build from source</b></summary>

```bash
git clone https://github.com/tortugarr/tortugarr.git
cd tortugarr
```

You need these installed first (setting them up is up to you):

| To build | You need |
|---|---|
| The **app** (TV and phone APK) | [Flutter](https://flutter.dev) 3.47 or newer (stable) with the Android SDK, and a JDK 17 or newer |
| The **server plugin** | The [.NET 10 SDK](https://dotnet.microsoft.com) |

App (from the repository root):

```bash
cp lib/data/services/download/download_now_secrets.example.dart \
   lib/data/services/download/download_now_secrets.dart
flutter pub get
flutter build apk --release --flavor androidTv-public --dart-define=TORTUGARR_PUBLIC=true   # TV
flutter build apk --release --flavor mobile-public    --dart-define=TORTUGARR_PUBLIC=true   # phone
```

The APKs land in `build/app/outputs/flutter-apk/`. Without your own signing key
(`android/app/release.keystore`) they are signed with the debug key, which is fine for
sideloading.

- Server: build the plugin and make the tar file as described in
  [`server/README.md`](server/README.md). A plain clone is not enough to install: the built
  plugin is not kept in git.

</details>

## Help and documentation

| | |
|---|---|
| ❓ [**FAQ**](docs/FAQ.md) | Answers to the questions people actually ask: downloading, series, subtitles, the remote, disk space. |
| 🧰 [**Install guide**](server/docs/install.md) | Everything the installer does, every question it asks, and how to manage the server afterwards (`sudo tortugarr`). |
| 🩺 [**Troubleshooting**](server/docs/troubleshooting.md) | Symptoms, causes and fixes when something on the server is not right. |
| 📺 [**The app**](server/docs/app.md) | Connecting the app to your server, and how app and server versions belong together. |
| 🏗️ [**Architecture**](server/docs/architecture.md) | How the pieces fit, which ports are used, and the security notes. |
| 🔌 [**Plugin API**](server/docs/design/tortugarr-plugin-api.md) | The contract between the app and the Tortugarr plugin, for developers. |
| ⚖️ [**Disclaimer**](server/DISCLAIMER.md) | What Tortugarr is and is not responsible for. |

## Tested on

| | |
|---|---|
| **Server** | Ubuntu 26.04 LTS in WSL2 on Windows 11 (with the optional Windows helper, not officially supported); earlier releases on Ubuntu 24.04.5 LTS. |
| **App** | Android TV and Google TV (a real TCL TV and the emulator), and a real Android phone. |
| **Version** | 4.20.02 |

## Take it further 🏴‍☠️

Tortugarr stands on the work of the Moonfin team and contributors, and was shaped for one living
room. If it is useful to you, it can be so much more, and **you are warmly invited to build on it**:

- **Fork it** and make it yours. That is what the licence is for.
- **More screens:** Moonfin itself already runs on iPhone, Apple TV, desktop and web. Tortugarr
  only ships Android today; bring the Tortugarr features to the rest.
- **More homes:** other Linux distributions, ARM boards like the Raspberry Pi, a NAS.
- **More people:** per-user permissions, profiles for the kids, more languages.
- **Better ideas than ours:** open an issue, send a pull request, or just tell us what you
  would change. [**CONTRIBUTING.md**](CONTRIBUTING.md) shows how to build both parts and what
  is where in this repository.

Every pirate ship started as somebody else's boat. This one started as Moonfin.

## What is in this repository

| Folder | What |
|---|---|
| [`lib/`](lib/), [`android/`](android/), … | The Tortugarr app, a fork of [Moonfin-Core](https://github.com/Moonfin-Client/Moonfin-Core) with its full history. |
| [`server/`](server/) | The installer and the Tortugarr Jellyfin plugin. |
| [`docs/`](docs/) | [FAQ](docs/FAQ.md), images and videos. |

## Free, and it stays free

Open source under GPL-2.0. Use it, change it, share it. See [LICENSE](LICENSE).

> Tortugarr ships software only: no content, no indexers and no accounts. You decide what you
> add, and you are responsible for using it legally where you live.
