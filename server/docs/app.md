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

## "Download Now" and the Tortugarr plugin

The released app (the APKs on the Releases page) holds no addresses, keys or passwords. After
the normal Jellyfin login it asks the **Tortugarr plugin** in Jellyfin what this server offers,
and the plugin does the work there: searching your indexers, handing the picked release to
Radarr or Sonarr, download progress, the disk space check, the file-list check that removes
torrents without a video file, subtitles, deletes and the optional adult library. These
features are for Jellyfin administrators.

Downloading works with every download client the installer supports. The file-list check, the
suggestions for making room and the adult library need qBittorrent (in Docker, or one you
already have).

The installer names the download categories `radarr` and `sonarr`, which is what the plugin
looks for.

### A private build with keys inside

An older way still works for a build of your own: the installer writes the addresses and API
keys to

```
/opt/tortugarr/download_now_secrets.dart   (root only - it contains API keys)
/opt/tortugarr/app-config.json             (the same values as JSON)
```

Copy the first into the app source at `lib/data/services/download/download_now_secrets.dart`
and build without `--dart-define=TORTUGARR_PUBLIC=true`. Such an APK carries your server's API
keys and download-client password: install it on your own devices only, never share or
publish it, and never commit the file (it is in `.gitignore`).

## App and plugin versions

The app is built on a Moonfin release and needs at least the matching Moonfin server
plugin (`MOONFIN_PLUGIN_MIN_VERSION` in `versions.env`). The installer puts that version
in place and leaves Jellyfin's automatic plugin updates on, so newer Moonfin plugin
releases arrive by themselves. When you update Tortugarr, update the app too.
