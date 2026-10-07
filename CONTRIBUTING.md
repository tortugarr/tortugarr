# Contributing to Tortugarr

Thanks for helping. This page covers how to build the two parts, and the two rules that keep
the repository and the releases clean.

## Build the app

Needs Flutter 3.44 (stable) with the Android SDK, and JDK 17 or newer. From `app/`:

```bash
cp lib/data/services/download/download_now_secrets.example.dart \
   lib/data/services/download/download_now_secrets.dart
flutter pub get
flutter build apk --release --flavor androidTv-public --dart-define=TORTUGARR_PUBLIC=true   # TV
flutter build apk --release --flavor mobile-public    --dart-define=TORTUGARR_PUBLIC=true   # phone
```

Details: [app/README.md](app/README.md).

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

- `app/build-android-tv-public.sh` does this for the APKs: it builds in a separate worktree with
  the empty secrets template and scans the APK for private values before keeping it.
- `server/plugin/build.sh` refuses to publish a plugin DLL that contains a build path.

For the server tar file, export the commit first, then build the plugin and make the tar
there as in [server/README.md](server/README.md):

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
