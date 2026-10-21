# Privacy Policy

**Tortugarr**
Last updated: October 21, 2026

## Overview

Tortugarr is an app for your own Jellyfin server, built on the open-source Moonfin client.
Tortugarr does not run any servers, has no accounts, and does not collect or track anything. Your
media and your data stay between your devices and the server you set up yourself.

## Data Collection

### Data We Do NOT Collect

- We do not collect personal information
- We do not track your usage or behavior
- We do not serve advertisements
- We do not share any data with third parties
- We do not use analytics services (e.g., Google Analytics, Firebase). The released app contains
  no Firebase at all.

### Data Stored Locally on Your Device

Tortugarr stores the following data locally on your device only:

- **Server addresses** — The URLs of the Jellyfin servers you connect to
- **Authentication tokens** — Used to keep your session with your Jellyfin server
- **User preferences** — Display, playback, language and other settings
- **Cached images** — Temporarily cached artwork for speed

The app holds no keys or passwords for Sonarr, Radarr, Prowlarr, Bazarr or the download client:
those stay on your server, in the Tortugarr plugin.

### Crash Reports (Optional)

Tortugarr can send crash reports to **your own server** when the app runs into an error. This
feature:

- Is **on by default** and can be turned off in Settings > About > Diagnostics & Logging
- Sends crash data **only to your own server**, never to us or any third party
- May include: stack traces, app version, device model, and operating system version
- Does not include personal information, media content, or browsing history
- Has server addresses, IP addresses and access tokens stripped out before anything is sent

### Network Communication

Tortugarr talks to:

- **Your Jellyfin server** — To stream media, sign in, sync settings, and for downloads,
  deletes and subtitles through the Tortugarr plugin
- **Your Seerr server** — To browse and request media, through your Jellyfin server or directly
- **TMDB** (image.tmdb.org) — Posters and pictures of titles you browse
- **YouTube** — Trailers, when you play one or have trailers on in the media bar or screensaver,
  and SponsorBlock to skip the parts of a trailer that are not the trailer
- **GitHub** (api.github.com) — To check for new Tortugarr releases, for the APKs installed
  outside an app store

Some optional features contact the service they are about, only when you use them: for example
the theme catalogue, rating sources, or an external list you add yourself.

Tortugarr supports cleartext (HTTP) connections because many home servers run on the local
network without HTTPS. No data is sent to any server run by Tortugarr.

### Voice Search

Tortugarr may ask for microphone access for voice search on supported devices. Audio is processed
by the device's speech recognizer and is not recorded, stored, or sent by Tortugarr.

## Data Security

Sensitive data (authentication tokens, server credentials) is stored in the app's private storage
on your device, protected by the platform's security and app sandboxing. Tortugarr supports HTTPS
connections to your servers.

## Children's Privacy

Tortugarr is not directed at children under the age of 13. We do not knowingly collect any
information from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted to this page with an
updated date.

## Contact

If you have questions about this privacy policy, open an issue on the Tortugarr repository:
https://github.com/tortugarr/tortugarr/issues

## Open Source

Tortugarr is open-source software, and so is Moonfin, the app it is built on. You can review the
complete source code to check what it does:
https://github.com/tortugarr/tortugarr
