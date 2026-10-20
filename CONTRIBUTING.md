# Contributing to Tortugarr

Thanks for helping. This page covers how to build the two parts, and the two rules that keep
the repository and the releases clean.

## What is where

| Folder | |
|---|---|
| [`lib/`](lib/), [`android/`](android/), … | The Tortugarr app, a fork of [Moonfin-Core](https://github.com/Moonfin-Client/Moonfin-Core) with its full history. |
| [`server/`](server/) | The installer and the Tortugarr Jellyfin plugin. |
| [`docs/`](docs/) | [FAQ](docs/FAQ.md), user guide and manual. |

## Build the app

Needs Flutter 3.47 or newer (stable) with the Android SDK, and JDK 17 or newer. From the repository root:

```bash
cp lib/data/services/download/download_now_secrets.example.dart \
   lib/data/services/download/download_now_secrets.dart
flutter pub get
flutter build apk --release --flavor androidTv-public --dart-define=TORTUGARR_PUBLIC=true   # TV
flutter build apk --release --flavor mobile-public    --dart-define=TORTUGARR_PUBLIC=true   # phone
```


## Build the plugin

Needs the .NET 10 SDK. From the repository root:

```bash
server/plugin/build.sh
```

It runs the unit tests and writes `server/plugin/dist/Tortugarr_<version>/`. Details, the
server tar file and the tests: [server/README.md](server/README.md).

## Keep the repository free of private data

Everything committed here may end up in a public release, so nothing private goes in:

- No keys, passwords, tokens, server addresses or IP addresses. The app's
  `download_now_secrets.dart` is git-ignored; only the empty `.example.dart` template is committed.
- No personal paths (home folders, checkouts), usernames, email addresses or hostnames in code,
  docs, logs or build output.
- No real answers files, logs or screenshots from a real install. The answers files in
  `server/tests/` hold a throwaway test login only.
- No build output (`build/`, `bin/`, `obj/`, `plugin/dist/`, APKs, tar files).

Check `git diff --cached` before every commit. If something private was committed, say so in the
pull request: removing it in a later commit does not remove it from history.

## Release files come from a clean export

Release files (the APKs and `tortugarr-server-<version>.tar`) are always built from a clean
export of a commit (a fresh `git worktree` or `git archive`), never from a working copy. A
working copy can hold git-ignored files, such as a filled-in secrets file or a stray answers
file, that a clean export does not.

For the APKs, export the commit, use the empty secrets template, build there, then check the
APK holds no private strings or home-folder paths before keeping it:

```bash
rm -rf /tmp/tortugarr-export && mkdir -p /tmp/tortugarr-export
git archive HEAD | tar -x -C /tmp/tortugarr-export
cd /tmp/tortugarr-export
cp lib/data/services/download/download_now_secrets.example.dart \
   lib/data/services/download/download_now_secrets.dart
flutter pub get
flutter build apk --release --flavor androidTv-public --dart-define=TORTUGARR_PUBLIC=true   # TV
flutter build apk --release --flavor mobile-public    --dart-define=TORTUGARR_PUBLIC=true   # phone

# Check our own code in every APK: no output from grep means clean. Also grep for your
# own server addresses and keys.
for apk in build/app/outputs/flutter-apk/*-release.apk; do
  rm -rf /tmp/apk-check && unzip -q "$apk" -d /tmp/apk-check
  grep -rlaE 'file:///(home|root|Users)/' /tmp/apk-check/lib/*/libapp.so \
      /tmp/apk-check/assets/flutter_assets/ && echo "LEAK in $apk"
done
```

Build paths inside the prebuilt third-party `.so` files (such as `libass.so` and `libmpv.so`)
are expected and harmless, so the check skips them. Flutter embeds build paths as `file://`
URIs, so the check looks for those rather than bare `/home/` or `/Users/`, which also appear in
harmless places such as Jellyfin API paths.

For the server tar file, export the commit first, then build the plugin and make the tar
there as in [server/README.md](server/README.md). `server/plugin/build.sh` refuses to publish
a plugin DLL that contains a build path:

```bash
mkdir -p /tmp/tortugarr-export
git archive HEAD | tar -x -C /tmp/tortugarr-export
cd /tmp/tortugarr-export
server/plugin/build.sh
tar -cf tortugarr-server-<version>.tar --exclude=bin --exclude=obj \
    --transform 's,^server,tortugarr-server,' server
```

## Pull requests

Keep a pull request to one change, say what it changes and how you tested it, and run the tests
listed in [server/README.md](server/README.md#tests) for server changes. By contributing you
agree that your work is licensed under GPL-2.0, like the rest of Tortugarr.
