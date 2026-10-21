# Tortugarr Jellyfin plugin - route specification

The contract between the Tortugarr app and the Tortugarr Jellyfin plugin: every route, who may
call it, what it answers, and the release filters. The plugin implements it; the app's public
build uses it.

## 1. Principles

- **The app never holds a key.** Prowlarr/Sonarr/Radarr/Bazarr/Seerr keys and the download-client
  login live only in the plugin's configuration on the server (written by the installer, never returned
  by any route, never logged).
- **One login:** every route uses the app's normal Jellyfin session
  (`Authorization: MediaBrowser Token="<token>"`), exactly like Moonfin's Seerr proxy.
- **Administrators only (v1).** Every route except `Capabilities` requires a Jellyfin
  administrator (Jellyfin policy `RequiresElevation`). `Capabilities` answers any logged-in user
  and tells them what is on.
- **Sonarr/Radarr search, the plugin filters like the app does today.** Searches go through
  Sonarr/Radarr's own interactive search by ID (using the indexers Prowlarr synced), so quality
  profiles and blocklists apply. On top, the plugin applies exactly the filters the app applies
  today (section 4), so the picker behaves the same after the switch.
- **Administrators only in the first version**; no per-user flag yet.
- **Adult library: in the public plugin, off by default** (decision changed 2026-10-06, section 3.9):
  switched on by an administrator on the plugin's admin page, administrators only in v1, its own
  Jellyfin library so access is controlled per user in Jellyfin, no indexers pre-filled, neutral
  wording in code and docs.
- **Stable and versioned:** everything under `/Tortugarr/v1/`. Breaking changes get `/v2/`.
  The app checks `Capabilities` first; a server without the plugin answers 404 and the app keeps
  the features hidden.
- JSON in and out, camelCase. Times in UTC ISO 8601. Sizes in bytes.

## 2. Errors (all routes)

```json
{ "error": { "code": "not_admin", "message": "Only administrators can download." } }
```

| HTTP | code | When |
|---|---|---|
| 400 | `bad_request` | missing/invalid parameter |
| 401 | (Jellyfin) | no or invalid session |
| 403 | `not_admin` / `feature_off` | not an administrator / the feature is switched off on this server |
| 404 | `not_found` | unknown title, release or download |
| 409 | `search_expired` | the release is no longer in Sonarr/Radarr's search cache (search again) |
| 409 | `already_in_client` | Grab (3.3): qBittorrent already has the release; the error also carries `downloadId`, `category`, `progress`, `state` |
| - | `no_indexers` | only as a search job's `error.code` (3.2, 3.9): the search found nothing and the service has no active indexer |
| 502 | `upstream_failed` | Sonarr/Radarr/Prowlarr/Bazarr/download client answered with an error (message says which) |
| 503 | `not_configured` | the plugin has no address/key for the service the route needs |

## 3. Routes

### 3.1 `GET /Tortugarr/v1/Capabilities` - any logged-in user

```json
{
  "apiVersion": 1,
  "pluginVersion": "1.0.0.0",
  "isAdmin": true,
  "features": { "downloadNow": true, "downloads": true, "diskSpace": true,
                "videoCheck": true, "subtitles": true, "deleteTitles": true,
                "missingEpisodes": true, "freeSpace": true, "adult": false },
  "categories": { "movies": "radarr", "tv": "sonarr" }
}
```
A non-admin gets the same shape with every feature `false`. A feature is `false` when its service
is not configured (for example `subtitles` without Bazarr). `adult` is true only when an
administrator switched it on (3.9), Prowlarr is configured and the download client is qBittorrent.
`deleteTitles` (3.10) needs Radarr or Sonarr; Seerr is optional for it (without Seerr the title is
still deleted, and the answer says `seerr: "not_configured"`).

### 3.2 Search for a title - asynchronous

A search through Sonarr/Radarr takes 30-90 seconds, so it is a job the app starts and then asks
about:

- `POST /Tortugarr/v1/Searches` with body
  `{ "type": "movie", "tmdbId": … }` | `{ "type": "episode", "tvdbId": …, "season": …, "episode": … }` |
  `{ "type": "season", "tvdbId": …, "season": … }`
  → **202** `{ "searchId": "…", "pollAfterSeconds": 2 }`
- `GET /Tortugarr/v1/Searches/{searchId}` → while running:
  `{ "status": "running", "elapsedSeconds": 31 }`; when done: `{ "status": "done", "result": { … } }`
  (shape below); when it failed: `{ "status": "failed", "error": { "code": "upstream_failed", … } }`.
- **No usable indexer:** when the search finds nothing, the server checks whether the service it
  searched has any active indexer (Radarr/Sonarr: interactive search on and not disabled after
  failures; for searches through Prowlarr: enabled and not disabled). If none is active, the job
  ends as `failed` with code `no_indexers` and a message naming the service and why (for example
  "Radarr has no active indexers: 1 disabled until 05:21 UTC after failures"), so the app can show
  its own message instead of "nothing found". A search that finds releases is never held up by
  this check.
- The server gives a search **150 seconds** (the *arr call itself gets a 150 s HTTP timeout); after
  that the job ends as `failed` with code `timeout`. Finished jobs are kept for 30 minutes (as long as
  Sonarr/Radarr keep their search cache), then `GET` answers 404.
- One running search per user and title: starting the same search again returns the running job.

**How the title gets into Sonarr/Radarr - the same as the app today** (from the app's
`download_now_service.dart` `downloadPickedRelease`):
- **Movie** missing in Radarr: added **monitored, without a search** (`monitored: true`,
  `addOptions.searchForMovie: false`). Quality profile by tier name - Ultra-HD/4K/2160p, HD-1080p,
  HD-720p, else the first profile; root folder: the one with the most free space.
- **Series** missing in Sonarr: added **unmonitored, without a search**; the user decides
  monitoring per season (as `ensureSeriesByTmdb` does).
  Consequence, kept on purpose: for an unmonitored episode Sonarr does not look for another release
  by itself when a download fails or is blocklisted; the user picks another release in the app.

Search: the *arr's interactive search by ID (`GET /api/v3/release?movieId=` / `?episodeId=` /
`?seriesId=&seasonNumber=`), then section 4. The finished result:

```json
{ "title": "Elephants Dream", "year": 2006, "arrId": 12, "droppedEarly": 0,
  "releases": [ {
    "guid": "…", "indexerId": 3, "indexer": "…", "title": "Elephants.Dream.2006.1080p.WEB-DL…",
    "size": 372178639, "seeders": 10, "leechers": 2, "protocol": "torrent",
    "quality": "WEBDL-1080p", "languages": ["English"], "publishDate": "2026-10-01T00:00:00Z",
    "seasonPack": false, "sd": false, "approved": true, "recommended": true, "rejections": [] } ],
  "dropped": { "below the quality minimum": 3 },
  "unavailableIndexers": ["Internet Archive"] }
```
Releases that fail a filter or carry a **hard** rejection are left out; releases with only **soft**
rejections stay, with `approved: false`, `recommended: false` and the reasons in `rejections`
(shown to the user, as the app does now). Sorted as in 4.4. `dropped` counts the releases each
filter left out (for example `{ "below the quality minimum": 3, "too small": 1 }`); a hard
rejection is counted under Radarr's/Sonarr's own reason (for example `"Unknown Series": 6` -
releases of another show that only share a word with the title), so the app can
say why nothing is shown or hint that SD releases exist. **`allowSd: true`** in the search body
keeps releases below the quality minimum (4.1.4), marked `"sd": true`;
`unavailableIndexers` names the indexers that are switched off after failures right now - from
Radarr's/Sonarr's health check and Prowlarr's own block list, names without " (Prowlarr)" - so the
app can say that a source was left out (empty list when all are up; the adult search in 3.9 has it
too, from Prowlarr); every other filter
(cam/TS, executables, size, home release, hard rejections) still applies. Default false; the app's
setting "Show SD releases". If every release was dropped by the
home-release rule (4.1.6), `droppedEarly` says how many (the app shows "only early files (n)").

`type=season` is offered by the app when a season has **3 or more** aired, missing episodes
(the app's `seasonPackThreshold`); the plugin does not enforce that number, the app does.

### 3.3 `POST /Tortugarr/v1/Grab` - download a release

Body: `{ "type": "movie" | "episode" | "season", "arrId": 12, "guid": "…", "indexerId": 3 }`
Server: `POST /api/v3/release {guid, indexerId}` on Radarr/Sonarr (the release from the search cache).
Answer: `{ "downloadId": "…", "title": "…", "queued": true }`. Cache expired (about 30 min):
409 `search_expired`.

**Already in the download client (409 `already_in_client`).** When Radarr/Sonarr cannot hand the
release to the client because qBittorrent already has that torrent (same hash, for example left
from an earlier download), the *arr only reports "Failed to connect to qBittorrent". The plugin
then looks for the release in qBittorrent (by the release's info hash, else by its name) and, if
it is there, answers:
```json
{ "error": { "code": "already_in_client",
             "message": "qBittorrent already has this release (category radarr, 100 %).",
             "downloadId": "6B3BE6B4…", "category": "radarr", "progress": 1.0,
             "state": "stalledUP" } }
```
`progress` is 0-1. The plugin **never deletes** the existing torrent; the app shows its own message
("already downloading" while `progress` < 1, "already downloaded" at 1). Not found in qBittorrent:
the *arr's error stays 502 `upstream_failed`. Other download clients: 502 as before.

**Movies: the Seerr request comes after the queue (order kept from the app).** For a movie the
route answers only when the movie is in Radarr's queue (it waits up to 60 s; `queued: false` if it
did not show up). The app then creates and approves the Seerr request through Moonfin's Seerr proxy,
as today - **only when `queued` is true**, because Seerr's approval makes Radarr search, and Radarr
would grab a second copy if the first were not in its queue yet. The plugin uses its Seerr key
only to clear Seerr after deletes (3.10, 3.11), never to create or approve requests.
**Series: no Seerr request** (Seerr requests whole seasons, monitors and searches them, so one
picked episode would become every season).
A soft-rejected release can only be grabbed with `"force": true` in the body (the app asks the
user first) - kept, administrators only. Releases dropped by section 4
cannot be grabbed at all.

**Deliberately dropped: the qBittorrent fallback.** Today the app, as a last resort, sends a release
straight to qBittorrent when Radarr/Sonarr refuse it. The plugin does **not** do that: everything
goes through Radarr/Sonarr, so quality profiles, blocklists, the import checks and the automatic
retry always apply, and no download ever bypasses them. A refused release can only be taken with
`force` (soft rejections, administrators) - never around the *arr.

### 3.4 `GET /Tortugarr/v1/Downloads` - what is downloading

Merged queues of Radarr and Sonarr, plus the adult category in qBittorrent when `adult` is on:
```json
{ "items": [ { "downloadId": "…", "kind": "movie|episode|adult", "title": "…",
               "name": "…", "tmdbId": 9761, "tvdbId": null, "season": null, "episode": null,
               "status": "downloading|queued|paused|importPending|importing|completed|failed|warning",
               "progress": 0.42, "size": 1300000000, "sizeLeft": 215000000, "etaSeconds": 120,
               "messages": ["…"] } ] }
```
`title` is the release, `name` the movie or series. With qBittorrent, `size` and `sizeLeft` come
from qBittorrent itself (Radarr/Sonarr read the client once a minute). A grab Radarr/Sonarr have
not put in their queue yet (their history has it, qBittorrent has the torrent) is listed too, so
a new download shows at once.

### 3.5 `DELETE /Tortugarr/v1/Downloads/{downloadId}?blocklist=true|false`

Server: removes it from the *arr queue with `removeFromClient=true` (and blocklists it when asked,
so the *arr looks for another release). Adult items are removed from qBittorrent with their files
(no blocklist - there is no *arr). Answer: 204.

### 3.6 `POST /Tortugarr/v1/Downloads/{downloadId}/Check` - is there a video in it?

Server: finds the torrent in **qBittorrent** by its hash (category `radarr`, `sonarr` or `adult`) and
reads its file list there - not in the Radarr/Sonarr queue, where a fresh grab is not listed yet and a
fast download is already gone (real-indexer test 2026-10-07: always 404). If no file is a video
(4.5), the download is removed and its release blocklisted: through the *arr queue
(`removeFromClient=true&blocklist=true`) when it is listed there, otherwise by marking its grab
failed in the *arr history (which blocklists it) and removing the torrent with its files; adult
downloads are only removed (as the app's `release_video_guard.dart` does today). Not in qBittorrent:
404.
Answer: `{ "hasVideo": true, "files": [{"name": "…", "size": 0}], "action": "kept" | "removed" }`.
Not possible yet (metadata still loading): `{ "hasVideo": null, "action": "wait" }`.

### 3.7 `GET /Tortugarr/v1/Space` - free space where downloads land

Answer: `{ "path": "/data/torrents", "freeBytes": 0, "totalBytes": 0 }` - from the download client
(qBittorrent: `free_space_on_disk`); for other clients from Radarr/Sonarr's `/diskspace` for the
same path.

### 3.8 Subtitles (Bazarr)

- `GET /Tortugarr/v1/Subtitles?type=movie&tmdbId=…` | `?type=episode&tvdbId=…&season=…&episode=…`
  → Bazarr's manual search for that item:
  `{ "candidates": [ { "id": "…", "provider": "…", "language": "en", "hearingImpaired": false,
  "forced": false, "score": 90, "releaseInfo": ["…"], "originalFormat": false } ] }`
- `POST /Tortugarr/v1/Subtitles` with `{ "type": …, ids…, "id": "<candidate id>", "provider": "…",
  "language": "en", "hearingImpaired": false, "forced": false, "originalFormat": false }` → Bazarr
  downloads it next to the video (`originalFormat` is passed on as Bazarr's `original_format`);
  Bazarr's Jellyfin integration (or the plugin) refreshes the item. Answer: 204.
- `GET /Tortugarr/v1/Subtitles/State?type=movie&tmdbId=…` | `?type=episode&tvdbId=…&season=…&episode=…`
  → `{ "have": ["en"], "missing": ["no"] }`: language codes (Bazarr's `code2`) of the subtitles
  Bazarr has for the item, and of those its language profile wants but are missing. 404 when
  Bazarr does not know the title yet.
- `POST /Tortugarr/v1/Subtitles/Search` with `{ "type": …, ids…, "languages": ["no"] }` → **202**
  `{ "status": "searching" }`. Bazarr's own automatic search (its "Search" button,
  `PATCH /api/movies/subtitles` / `/api/episodes/subtitles`) for each language, in the background,
  with hearing-impaired/forced as the profile asks; empty `languages` = every missing one. The app
  asks `State` afterwards.

### 3.9 Adult library (off by default)

**Switching it on.** The plugin's admin page (Jellyfin Dashboard > Plugins > Tortugarr) has one
switch, "Adult library", off by default. Switching it on:
1. uses the adult folder (`AdultSavePath`: the folder the user gave the *Adult* type during
   install, else `/data/media/adult`), saved to by qBittorrent with category `adult`; a
   qBittorrent outside Docker saves to the same folder by its own path (`AdultDownloadPath`,
   for example `E:\-=XxX=-`);
2. creates **its own Jellyfin library** "Adult" (type: movies, home videos style metadata off,
   no internet metadata) on that folder;
3. **hides that library from every non-administrator** (their access lists in Jellyfin are set
   to all libraries except this one) - and does the same for users created later, through
   Jellyfin's user-created event. An administrator then grants access per user in Jellyfin
   (Dashboard > Users > the user > Access), the normal Jellyfin way.
4. **The plugin keeps its own list of the users it converted** from "all libraries" (and of new
   users, who start with "all except the adult library"). For them it stays as if they still had
   "all libraries" except the adult one: every **new ordinary library** is added to their access
   list as soon as Jellyfin reports it (its own `ItemAdded` event for libraries), plus one check
   after Jellyfin starts as a safety net. **What an administrator changed by hand is respected**:
   the plugin only adds new libraries, never puts back one an administrator took away, and never
   removes adult access an administrator granted. Users with their own access list from before
   are not touched. **Also "all except adult"**: anyone - also an administrator who hid the adult
   library for himself in the app (which turns off his "all libraries") - whose list holds every
   ordinary library known so far gets new libraries too; a list narrowed by hand does not match.
Switching it off stops the routes (403 `feature_off`); the library and files are left alone.
No indexers are added - the administrator adds adult indexers in Prowlarr themselves (they must
not be synced to Sonarr/Radarr; Prowlarr's per-application tags handle that).

**Routes** - administrators only (v1), and only when `adult` is on:

- `POST /Tortugarr/v1/Adult/Searches` with `{ "query": "…" }` → **202** `{ "searchId": "…", "pollAfterSeconds": 2 }`
- `GET /Tortugarr/v1/Adult/Searches/{searchId}` → running / done / failed, like 3.2 (also `no_indexers` when Prowlarr has no active indexer). Done:
  ```json
  { "query": "…", "releases": [ { "guid": "…", "indexerId": 7, "indexer": "…", "title": "…",
      "size": 0, "seeders": 0, "leechers": 0, "publishDate": "…", "matchedWords": 2 } ] }
  ```
- `POST /Tortugarr/v1/Adult/Grab` with `{ "searchId": "…", "guid": "…", "indexerId": 7 }` → the plugin
  takes the release's magnet link from Prowlarr's result, or fetches the `.torrent` behind its
  download URL itself (a qBittorrent outside Docker cannot open Prowlarr's address), and adds it
  to qBittorrent with category `adult` and the adult folder as save path. Answer
  `{ "downloadId": "<torrent hash>", "title": "…" }`. Only releases shown in that search can be
  taken (else 409 `search_expired`). Never through Sonarr/Radarr.
- Adult downloads appear in 3.4 (`kind: "adult"`), can be removed with 3.5 and checked with 3.6.

**Search (as the app does today, `searchKeywords`):** Prowlarr search in categories
**6000-6090** for the whole phrase **and** for each word of it separately; the results are merged
(one per guid+indexer), then ranked by **how many of the query's words the title contains**, then
by **seeders**.

**Filters (4.7)** - only the safety checks, not the movie/TV rules.

### 3.10 `DELETE /Tortugarr/v1/Library/{itemId}` - delete a title from the library

Does on the server exactly what the original app does today with its
own keys. `itemId` is the Jellyfin item the user is looking at; its type decides what is deleted:

| Jellyfin item | What the server does |
|---|---|
| Movie | Find the movie in Radarr by the TMDB id from Jellyfin. Check that Radarr's file is the one in Jellyfin (same file name), else 409 `file_mismatch`. Delete the movie with its file (`deleteFiles=true`, `addImportExclusion=false`). |
| Episode | Find the series in Sonarr by the TVDB id (of the series), and the episode by season and episode number. Unmonitor the episode first, so Sonarr does not search for it again at once. Check the file name as for a movie. Delete the episode file. |
| Season | As for an episode, for every episode of that season: unmonitor them all, then delete their files (no file-name check, as in the app today). |
| Series | Delete the series in Sonarr with all files (`deleteFiles=true`, `addImportListExclusion=false`). |

Then, on the server:
1. **Seerr:**
   - **Movie or whole series - targeted:** the title's Seerr entry is deleted
     (`DELETE /api/v1/media/{mediaId}`, the same as "Clear Data" in Seerr), so a new request is
     possible at once. The entry is found by the TMDB id (`GET /api/v1/movie/{tmdbId}` or
     `/api/v1/tv/{tmdbId}`; for a series the TMDB id comes from Sonarr, else from Jellyfin). No
     entry in Seerr is not an error (`seerr: "not_found"`).
   - **Episode or season - no Clear Data:** the series' request history is kept. The delete only
     starts the debounced full availability-sync of 3.11 (`seerr: "sync_queued"`), and Seerr
     marks the series partial itself.
2. **Jellyfin:** a scan of only the library the title was in (the same as "Scan library" on
   that one library). In addition the plugin removes Jellyfin's **database entry** of what it just
   deleted when its file or folder is gone from disk - only the entry, never a file - because
   Jellyfin's scan skips a library folder that became empty (the last title of a library would
   otherwise stay listed).
3. **qBittorrent:** the title's torrents are removed with their download copies, so the same
   release can be fetched again later (otherwise qBittorrent refuses it as a duplicate). They are
   found by the `downloadId`s in Radarr's/Sonarr's history, read before the delete, and only
   torrents in the `radarr`/`sonarr` category are touched. For an episode or a season, a torrent
   is removed only if it holds nothing but the deleted episodes - a season pack other episodes
   came from stays. A failure here does not undo the delete. Other download clients: nothing is
   removed. Known limit, Sonarr only: Sonarr 4 keeps a finished hash as "imported" in memory
   until it restarts, so grabbing **the same release** of an episode again after a delete is not
   imported (Sonarr fixes this only in its next major version; documented in
   `docs/troubleshooting.md`). Radarr fixed it in 6.4.4 ("Re-grabbing a torrent that was already
   imported should re-import"), the pinned version since 2026-10-06. Removing the torrent does not
   clear that memory.

Answer 200:
```json
{ "deleted": "movie", "title": "Sita Sings the Blues", "files": 1, "torrentsRemoved": 1,
  "libraryId": "f137a2dd…", "seerr": "cleared" }
```
`deleted`: `movie | episode | season | series | adult`. `seerr`: `cleared | not_found | sync_queued |
not_configured | failed | not_applicable` (`failed` does not undo the delete; 3.11 catches it).

**Adult library (3.9):** there is no Radarr/Sonarr; the file belongs to a qBittorrent download in
the `adult` category saved straight into the library. That download is removed with its files (it
holds this file, or the folder the file is in), then the entry and a scan of the adult library.
Answer: `deleted: "adult"`, `seerr: "not_applicable"`. No such download: 409 `not_managed`.

Errors: 400 `bad_request` (an item type that cannot be deleted, for example a library or a
folder); 404 `not_found` (no such Jellyfin item); 409 `not_managed` (the title is not in
Radarr/Sonarr, for example added by hand, or an adult file no qBittorrent download holds - nothing
is deleted); 409 `file_mismatch` (Radarr's/Sonarr's file is not the one in
Jellyfin - nothing is deleted); 502/503 as in section 2.

**The app afterwards (as today):** checks every 3 s, for up to 3 min, that the item is gone
(`GET /Users/{userId}/Items/{itemId}` answers 404), then refreshes the home screen.

### 3.11 Seerr after deletes made elsewhere (no route)

A title deleted outside 3.10 (in Radarr/Sonarr, in Jellyfin, or on disk) would stay "available"
in Seerr until Seerr's own hourly availability-sync. The plugin listens to Jellyfin's
`ItemRemoved` event for movies, episodes, seasons and series (not in the adult library) and then
asks Seerr to run that job once (`POST /api/v1/settings/jobs/availability-sync/run`).
**Debounced:** the job runs 2 minutes after the last removal, so many deletes in a row (a whole
series, a library scan, an upgrade that replaces a file) give one run; during a steady stream it
runs at least every 10 minutes. Seerr decides each title's status itself. Without a Seerr key
this does nothing.

### 3.12 `POST /Tortugarr/v1/Hooks/Arr` - targeted library refresh (server to server)

Not for the app. Radarr's and Sonarr's webhook "Tortugarr: refresh Jellyfin" (events: import,
upgrade, rename, movie/series delete, movie/episode file delete) posts its normal webhook JSON
here with the header `X-Tortugarr-Hook-Key: <shared key>`. The installer generates that key
(`tortugarr_hook_key` in `secrets.json`) and writes it into the plugin configuration (`HookKey`)
and the two webhooks. The route accepts **only** this key (compared in constant time), not a
Jellyfin session, so Radarr/Sonarr no longer hold a Jellyfin administrator key; the key can only
trigger a refresh. Missing or wrong key: 401 `bad_hook_key`. Before this route the webhook called `/Library/Refresh`, a scan of **every**
library on every import or delete.

Server: takes the paths from the payload (the file paths first - `movieFile`, `episodeFile`,
`episodeFiles`, `renamed…Files`, `deletedFiles` - then `movie.folderPath` / `series.path`) and,
like Jellyfin's own folder watcher, refreshes the nearest item that still exists for each: the
season, the series, the movie folder, or the library's own folder for a new title. Only that part
of that library is scanned, at once (the folder watcher waits about 60 s). A path that is in no
library falls back to a full library scan, as before. `eventType: "Test"` (sent when the webhook
is saved) does nothing. `MovieAdded` (sent only when there are documentary folders) moves a
movie TMDB lists as a documentary into a documentary folder (`DocumentaryRoots`) before anything
is downloaded, so Seerr requests land there too; nothing is scanned. After an import (`Download`) the plugin also starts Seerr's
"recently added" scan 30 s later (imports close together give one run), so a request shows as
available at once instead of at Seerr's next 5-minute run. Answer: 204.

### 3.13 `GET /Tortugarr/v1/Repository/manifest.json` - the plugin's own catalog (no login)

Jellyfin's plugin page looks the plugin up in the configured repositories
(`/Packages/Tortugarr?assemblyGuid=…`); without one that lists it, the page shows "error fetching
repository details". The plugin serves a catalog with one entry (with the parrot logo as `imageUrl`, also the plugin's
picture in Jellyfin): the installed version, with
`sourceUrl` pointing at `GET /Tortugarr/v1/Repository/Tortugarr_<version>.zip` (the installed
DLLs and meta.json) and its MD5 checksum. The installer adds the repository "Tortugarr" =
`http://127.0.0.1:8096/Tortugarr/v1/Repository/manifest.json` (Jellyfin reads it from itself).
No login: it holds only the plugin itself, never configuration or keys. Auto-update stays off
and only the installed version is listed, so it never offers an update. For the public launch
the repository can move to the project's own address.

### 3.14 Missing episodes and season monitoring (Sonarr)

For the app's missing-episodes view and its season switch (`missing_episodes.dart`:
`stateFor`, `setSeasonMonitoring`). The app keeps its
own rules (`downloading` / `importing` / `unaired` / `missing`, season packs from 3 episodes); the
plugin supplies the data. Administrators only.

**`GET /Tortugarr/v1/Series/{tvdbId}`** - read only (a series not in Sonarr is not added):
```json
{ "inSonarr": true, "arrId": 3, "title": "Pioneer One", "year": 2010, "monitored": true,
  "seasonMonitoring": { "0": false, "1": true },
  "queuedEpisodeIds": [293],
  "seasons": [ { "seasonNumber": 1, "monitored": true,
                 "episodes": [ { "episodeId": 293, "seasonNumber": 1, "episodeNumber": 1,
                                 "title": "Earthfall", "airDateUtc": "2010-06-16T00:00:00Z",
                                 "hasFile": false, "monitored": false, "queued": true } ] } ] }
```
- Every season, season 0 (specials) included; the app decides what to show.
- `queued` / `queuedEpisodeIds`: the episode is in Sonarr's queue (the app's "downloading").
- Not in Sonarr: `{ "inSonarr": false }` (200). Sonarr not configured: 503.

**`PUT /Tortugarr/v1/Series/{tvdbId}/Seasons/{seasonNumber}`** with
`{ "monitored": true, "search": false }` - exactly the app's `setSeasonMonitoring`:
1. A series not yet in Sonarr is added first as in 3.2 (unmonitored, without a search).
2. The season's `monitored` flag is set and the whole series is saved with two more changes:
   series `monitored` = true if **any** season is monitored, else false (turning the last season
   off turns the series off), and `monitorNewItems: "none"`.
3. On **without** a search (the default): every **aired** episode of that season
   (`airDateUtc` <= now) is set unmonitored, so Sonarr only follows future episodes and neither
   fetches nor upgrades the old ones.
4. On **with** `search: true`: the episodes stay monitored and Sonarr's `SeasonSearch` starts. If
   that command fails, the season stays monitored and the answer says so
   (`searchQueued: false`, `message`).
5. Off: only the season flag (and the series rule in 2); episode flags are not touched.

Answer: `{ "arrId": 3, "seasonNumber": 1, "monitored": true, "seasonMonitoring": { "1": true },
"searchQueued": false, "message": null }` - the app redraws its toggles from `seasonMonitoring`.
Unknown season: 404.

### 3.15 Free space: what can go, and the check before a download

For the app's free-space dialog and its check (`space_guard_service.dart`: `check`,
`candidates`). The staleness rules (30 days / 180
days), the favorite exclusion and the order stay **in the app**; the plugin supplies the data.
Administrators only.

**`GET /Tortugarr/v1/Space/Candidates`**
```json
{ "freeBytes": 17504247808, "totalBytes": 107374182400,
  "duplicates": [ { "hash": "6B3BE6B4…", "name": "Sita.Sings.the.Blues…mkv", "category": "radarr",
                    "bytes": 1172428172, "added": "2026-10-06T22:13:00Z" } ],
  "titles": [ { "kind": "movie", "title": "Sita Sings the Blues", "year": 2008, "arrId": 8,
                "tmdbId": 20529, "tvdbId": null, "bytes": 1172428172,
                "jellyfinId": "4cf7b9535cdbdee75986f9633ee358f5",
                "added": "2026-10-06T22:13:00Z", "lastPlayed": null, "favorite": false } ] }
```
- **`duplicates`:** finished torrents (progress 100 %) in the `radarr`/`sonarr` category that are not
  in Radarr's/Sonarr's queue any more, i.e. already imported. Oldest first.
  **With the installer's hardlinks, removing one frees no space** while the library still has the
  same file (both names point at the same data); it only matters for downloads that were copied,
  or whose library file is gone. The app shows `bytes` as today; this is a known difference from
  the private build, where imports are moves.
- **`titles`:** whole movies (Radarr) and whole series (Sonarr) with a size above 0 - no seasons.
  `bytes` from `sizeOnDisk` / `statistics.sizeOnDisk`; `added` from Radarr/Sonarr;
  `jellyfinId` matched by TMDB id (movies) / TVDB id (series), `null` when Jellyfin does not have
  it (then 3.10 cannot delete it); `lastPlayed` = the latest `LastPlayedDate` of **any** Jellyfin
  user (for a series: of any of its episodes, played or half-watched); `favorite` = any user has
  marked the title as a favorite. The adult library is not listed.
- Titles are deleted with 3.10; duplicates with:

**`DELETE /Tortugarr/v1/Space/Duplicates/{hash}`** - removes the torrent from qBittorrent **with its
files**, only if it is in the `duplicates` list right now (finished, `radarr`/`sonarr` category,
not in a queue); otherwise 404. Answer: 204.

**`GET /Tortugarr/v1/Space/Check?bytes=<release size>`**
```json
{ "freeBytes": 4000000000, "pendingBytes": 500000000, "bufferBytes": 10737418240,
  "neededBytes": 15737418240, "shortfallBytes": 12237418240, "enough": false }
```
- Free space on the **download disk** (qBittorrent `free_space_on_disk`); `pendingBytes` = the sum
  of `amount_left` of every torrent still downloading.
- `neededBytes = bytes × 1 + bufferBytes`; `shortfallBytes = max(0, needed + pending − free)`;
  `enough = shortfall == 0`. `bufferBytes` is the plugin setting `SpaceBufferBytes` (default
  10 GB).
- qBittorrent unreachable: 502 / 503 - the app goes ahead with the download, as today (it never
  blocks on a failed check). The plugin never blocks a Grab itself.

**Capabilities (3.1):** `missingEpisodes` (Sonarr configured) and `freeSpace` (qBittorrent and
Radarr or Sonarr configured), admins only like the rest.

## 4. Filters (the same as the app today)

From the app code (the app's `prowlarr_search_client.dart` `_isValidMedia`,
`release_picker_dialog.dart`, `missing_episodes.dart` `pickable`, `release_video_guard.dart`).

### 4.1 Every release (movies and TV) must pass

1. **Junk words** (case-insensitive, word-bounded) - must NOT match:
   `\b(HD-?CAM|CAM-?RIP|HQ-?CAM|CAM|HD-?TS|TS-?RIP|TELESYNC|PDVD|HD-?TC|TELECINE|DVD-?SCR|SCREENER|WORKPRINT|TS|TC|exe|scr|lnk|msi)\b`
   (the same as the *arrs' release profile, which a hand-picked release would otherwise bypass).
2. **Quality minimum** - the title must contain `720p`, `1080p` or `2160p`, or match
   `\b(BluRay|Blu-Ray|BDRip|BRRip|BDRemux|REMUX|DVDRip|DVD9|DVD5|DVD|WEB-?DL|WEBRip|WEB|HDRip)\b`.
3. **Minimum size**, only when the indexer reports a size above 0: episodes 200 MB, movies 700 MB.
   For SD releases kept by `allowSd` (3.2) the minimum is lower - episodes 80 MB, movies 350 MB -
   because the HD minimums stop real SD files.
   (Season packs: the episode minimum is per pack.)
4. **No banned extension** in the title or download URL:
   `.exe .msi .apk .app .dmg .pkg .bat .cmd .ps1 .sh .scr .com .jar .py .rb .pl .php .zip .rar .7z .tar .gz .bz2 .xz .iso .img .vhd .vhdx .pdf .doc .docx .txt .rtf`
5. **Torrent only** (`protocol` torrent), with a magnet link or a download URL.
6. **Movies: not before the home release.** Drop a release published more than **2 days before**
   the earlier of Radarr's `digitalRelease` / `physicalRelease` (renamed CAMs, mockbusters).
   Releases without a publish date are kept. The number dropped is returned as `droppedEarly`.

### 4.2 Hard rejections - the release is left out

Any *arr rejection matching (case-insensitive):
`blocklist|not enough seeders|must not contain|terms which are not allowed|unknown series|unable to parse|not requested|wasn.t requested|does not match|doesn.t match|wrong (series|episode|season)`

### 4.3 "Existing file" / "not an upgrade" / "does not allow upgrades"

- On a **single episode or a movie**: left out.
- On a **season pack**: kept (it fills the gaps), and that rejection is removed from its list.

### 4.4 Soft rejections and order

All other rejections (outside the quality profile, larger/smaller than the profile, already
exists, may not fit on disk ...) keep the release, as `recommended: false`, with the reasons.
Sort order:
1. season packs first (when the request was for a season);
2. recommended (no rejection) before soft-rejected;
3. resolution: 2160p > 1080p > 720p > other;
4. seeders, highest first.

### 4.5 What counts as video (route 3.6)

A file whose extension (case-insensitive) is one of
`.mkv .mp4 .m4v .avi .mov .wmv .ts .m2ts .webm .mpg .mpeg .vob` (the app's complete list,
`ReleaseVideoGuard.videoExtensions`) **and** that is at least **50 MB** (`minVideoBytes =
50 * 1024 * 1024`; a smaller video file is a sample or a decoy). A torrent with no such file is
removed and blocklisted.

### 4.6 Not carried over

- The app's Prowlarr category lists and its "with year, then without year" query fallback: the
  plugin searches through Sonarr/Radarr **by ID**, so it needs neither.

### 4.7 Adult releases (3.9) - safety checks only

1. No executable words: `\b(exe|scr|lnk|msi)\b` must not match the title.
2. No banned extension (4.1.4) in the title or the download URL.
3. At least **20 MB** when the indexer reports a size.
4. Torrent only, with a magnet link or a download URL.
(No quality minimum, no CAM/TS words, no home-release rule, no *arr rejections - there is no *arr.)

## 5. Plugin configuration (server side only)

Written by the installer to `plugins/configurations/Tortugarr.xml`; editable on the plugin's
admin page; **no route ever returns it**.

```
SonarrUrl, SonarrApiKey, RadarrUrl, RadarrApiKey, ProwlarrUrl, ProwlarrApiKey,
BazarrUrl, BazarrApiKey, SeerrUrl, SeerrApiKey, HookKey, SpaceBufferBytes = 10 GB,
DownloadClient { Type: qbittorrent|transmission|deluge|none, Url, Username, Password },
Categories { Movies: radarr, Tv: sonarr },
Filters (defaults = section 4; editable on the admin page): JunkRegex, QualityRegex,
  MinEpisodeBytes = 200 MB, MinMovieBytes = 700 MB, MinSdEpisodeBytes = 80 MB,
  MinSdMovieBytes = 350 MB, BannedExtensions,
  EarlyReleaseDays = 2, HardRejectionRegex, VideoExtensions, MinVideoBytes = 50 MB,
  SearchTimeoutSeconds = 150
MovieRoots, TvRoots, DocumentaryRoots (the Radarr/Sonarr root folders new titles may go to; a
  documentary goes only to DocumentaryRoots), DownloadRoots (a qBittorrent outside Docker: its
  download folders and where they are mounted, one per drive),
AdultEnabled = false (the admin-page switch), AdultCategory = "adult",
  AdultSavePath = "/data/media/adult" (the user's adult folder when there is one),
  AdultDownloadPath (the same folder as an outside qBittorrent sees it), AdultMinBytes = 20 MB,
  AdultUnsafeRegex = \b(exe|scr|lnk|msi)\b, AdultCategories = 6000-6090
```
Keys are only readable for administrators through Jellyfin's own plugin-configuration API
(which the admin page uses), the same as for every other key here; no Tortugarr route returns them.
Addresses are container names on the stack's network (`http://radarr:7878` …), so nothing is
exposed to the LAN for the plugin's sake.

## 6. What the installer does

Points Radarr's and Sonarr's refresh webhook at 3.12 (and at `/Library/Refresh` only when the
plugin is not active). Installs the plugin (pinned version, auto-update off: it ships with Tortugarr), writes its configuration from
`secrets.json` (the Seerr key is read from Seerr's `/settings/main` after the installer's admin
login, since `secrets.json` has none), and tests every route: admin served, non-admin 403, missing service 503, and each
action visible in Radarr/Sonarr/qBittorrent/Bazarr. Distribution: the installer carries the built plugin itself.

Without a route, the plugin itself gives every Prowlarr indexer the tag of the installer's
FlareSolverr proxy, every few minutes, so sites behind Cloudflare work.
