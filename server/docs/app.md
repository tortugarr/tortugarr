# The Tortugarr app

Tortugarr is a Jellyfin client based on [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core)
for Android TV and Android phones. It plays from Jellyfin like any Jellyfin client,
and adds request and "Download Now" features that use Seerr, Sonarr, Radarr and
Prowlarr on your Tortugarr server.

## Connecting

1. Install the app on the TV.
2. In the app, add the server `http://<server address>:8096` (the installer prints it) and
   choose **Quick Connect**. The TV shows a 6-digit code.
3. On a phone or PC, open the same address in a browser and log in with the username and
   password you chose during the install.
4. Tap the **profile icon** (top right) > **Quick Connect**, type the code from the TV and
   press **OK**. The TV is logged in - no typing a password with the remote.

Logging in on the TV with username and password directly also works. Other people get
their own user in Jellyfin (Dashboard > Users) and connect the same way.

Requests in the app go through the Moonfin plugin in Jellyfin to Seerr - the
installer has already connected them.

## "Download Now" and building the app

The current app version reads the addresses and API keys for Download Now **when
the app is built**, from `lib/data/services/download/download_now_secrets.dart`.
The installer writes a ready-made copy of that file for your server:

```
/opt/tortugarr/download_now_secrets.dart   (root only - it contains API keys)
/opt/tortugarr/app-config.json             (the same values as JSON)
```

**For a private build only.** An app built with this file carries your server's API
keys and download-client password inside the APK: install it on your own devices and
never share or publish it. A later app version will get this access after the normal
Jellyfin login instead, with no keys inside the app.

To build the app for your server, copy that file into the app source at
`lib/data/services/download/download_now_secrets.dart` and build as described in
the app's README. Never commit it - it is in the app's `.gitignore`.

Download Now hands the picked release to Radarr/Sonarr (grab, or push when they
do not know it), so downloading itself works with every download client the
installer supports. The app also talks to **qBittorrent directly** for:

- the disk space check before a download,
- the file-list check that removes torrents without a video file,
- the last-resort fallback when Radarr/Sonarr refuse a release,
- downloads into the optional adult library.

With Transmission or Deluge these four are unavailable; downloading still works.

The installer names the download categories `radarr` and `sonarr` (saved under
`torrents/movies` and `torrents/tv`), which is what the app looks for.

## App and plugin versions

The app is built on a Moonfin release and needs at least the matching Moonfin server
plugin (`MOONFIN_PLUGIN_MIN_VERSION` in `versions.env`). The installer puts that version
in place and leaves Jellyfin's automatic plugin updates on, so newer Moonfin plugin
releases arrive by themselves. When you update Tortugarr, update the app too.
