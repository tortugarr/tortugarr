# Tortugarr app

Flutter app for Android TV and Android phones/tablets.

## Based on Moonfin

This app is a fork of [Moonfin](https://github.com/Moonfin-Client/Moonfin-Core) (GPL-2.0),
taken from upstream commit `567e2a8c` (after release 2.3.2). Everything Moonfin does as a
Jellyfin client is still here; Tortugarr adds the download, delete, subtitle, missing-episode,
free-space and adult-library features through the Tortugarr server plugin.

## Build

You need [Flutter](https://flutter.dev) 3.44 (stable) with the Android SDK, and a JDK 17 or
newer. The public builds contain no server keys: the secrets file is the empty template.

```bash
cp lib/data/services/download/download_now_secrets.example.dart \
   lib/data/services/download/download_now_secrets.dart
flutter pub get
flutter build apk --release --flavor androidTv-public --dart-define=TORTUGARR_PUBLIC=true   # TV
flutter build apk --release --flavor mobile-public    --dart-define=TORTUGARR_PUBLIC=true   # phone
```

The APKs land in `app/build/app/outputs/flutter-apk/`. Without your own signing key
(`android/app/release.keystore`) they are signed with the debug key, which is fine for
sideloading.

Package id: `io.github.tortugarr.public`. Version 4.20.0.

`build-android-tv-public.sh` is the maintainers' script: it builds from a separate git worktree
and scans the APK for private values before keeping it.

## Licence

GPL-2.0, see [LICENSE](LICENSE). Original Moonfin copyright and licence notices are kept.
