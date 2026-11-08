# Taking in a new Moonfin release

Tortugarr is built on Moonfin (`upstream` = github.com/Moonfin-Client/Moonfin-Core). Moonfin moves
fast, and Tortugarr changes many of the same files, so a release is taken in on purpose, one
release tag at a time, never by pulling `main` in passing. The plugin and installer (`server/`)
are Tortugarr's own and never come from upstream.

## 1. Look (read-only, any time)

```bash
scripts/moonfin-upstream-report.sh report.md
```

The report says which Moonfin release Tortugarr is on, which ones are newer with their release
notes, where upstream changed things, the files both sides changed (where the merge needs care,
largest first) and the dependency changes. Keep it with the logbook.

## 2. Decide

Read the release notes and decide with the owner: worth it now, wait, or take only single fixes
(`git cherry-pick`). Things to weigh: new device minimums (3.0.0 needs iOS/tvOS 18), a new
Moonbase plugin version on the server, and how many "both sides changed" files there are.

## 3. Merge on its own branch, in its own worktree

```bash
git worktree add ../tortugarr-merge-<version> -b merge/moonfin-<version>
cd ../tortugarr-merge-<version>
git merge --no-ff <tag>          # the release tag, e.g. 3.0.0 - not upstream/main
```

Day-to-day work continues on the normal branch meanwhile. When resolving conflicts:

- **Tortugarr wins** for: app id and names (`io.github.tortugarr`), the public build without
  Firebase, `kTortugarrPublic` gates, Download Now / plugin flows, Tortugarr settings entries,
  home sections of our own (top lists), the admin health card, the intro, `tg*` strings, and
  everything under `server/`.
- **Moonfin wins** for its own features and fixes; keep Tortugarr's hooks into them (for
  example where a Tortugarr row or button sits inside a Moonfin screen).
- Version numbers: keep Tortugarr's (`4.20.x`); note the Moonfin base in CHANGELOG.
- New upstream strings come in English; give every new Tortugarr string a Norwegian text.

## 4. Check

```bash
scripts/tortugarr-invariants.sh                # what must still be Tortugarr
flutter pub get && flutter gen-l10n
flutter analyze lib test                       # 0 errors (packages/*/test errors are old)
flutter test                                   # all green
```

Then build the public TV APK (`build-android-tv-public.sh <commit>`), install it on the TV and go
through the TV checklist: start (intro), Home rows incl. top lists, a film and an episode
playing (direct play and a transcode), subtitles, Download Now, Requests, admin dashboard,
settings, and the remote's Back key everywhere.

## 5. Land it

Only when the TV test is good and the owner says so: merge the branch into the working branch
(fast-forward or `--no-ff`), update the logbook (Moonfin base, what came in, what was left out),
and only push when asked. If the server's Moonbase plugin needs a newer version, update that in
the same round and check `tortugarr doctor`.
