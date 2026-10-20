/// The public Tortugarr build (`--dart-define=TORTUGARR_PUBLIC=true`, made by
/// `build-android-tv-public.sh`). It carries no server addresses or keys, so
/// everything that talks to Prowlarr/Sonarr/Radarr/Bazarr/qBittorrent
/// directly is hidden, and requests go through Seerr as in upstream Moonfin.
const bool kTortugarrPublic = bool.fromEnvironment('TORTUGARR_PUBLIC');
