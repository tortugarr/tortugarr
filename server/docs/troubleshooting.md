# Troubleshooting

Start with the doctor. It checks every container, port, disk, connection and API,
and says what to do about each problem:

```bash
sudo tortugarr doctor
```

Most problems are fixed by **repair**, which is always safe - it keeps every
setting and only puts things back the way they should be:

```bash
sudo tortugarr repair
```

Logs: `sudo tortugarr logs <service>` (jellyfin, sonarr, radarr, prowlarr, seerr,
qbittorrent, transmission, deluge, sabnzbd, gluetun). Installer logs are in
`/opt/tortugarr/logs/`.

## Symptoms

**Downloads finish but never show up; the queue says "No files found are eligible for import".**
Radarr or Sonarr cannot see the folder the download client saved to. This happens when the
client was switched by hand, for example from Tortugarr's qBittorrent container to a qBittorrent
on Windows: the files are on `H:\Downloads`, which is not mounted into the containers. Run
`sudo tortugarr doctor` (it names the mapping or client that is off), then
`sudo tortugarr reconfigure` and choose **qBittorrent I already have**. See
[Using a qBittorrent you already have](install.md#using-a-qbittorrent-you-already-have).
Downloads already stuck in the queue: once the paths are right, use *Manual Import* in Radarr or
Sonarr, or remove them from the queue if you moved the files yourself.

**Nothing is found / nothing downloads.**
You need indexers: Prowlarr > Indexers > Add Indexer. The doctor warns until you
have at least one.

**A new episode "has no file" and sits in the queue with a warning about `.exe`.**
It was a fake release (a Windows program pretending to be a video). Sonarr/Radarr
refuse to import it. Remove it from the queue with *Remove and blocklist*. With
qBittorrent, such files are not downloaded in the first place.

**Downloads finish but never appear in the library.**
Look at Activity > Queue in Sonarr/Radarr: a yellow warning tells you why (often a
file name that cannot be matched - use *Manual Import*). New files show up in
Jellyfin at the next library scan (every 30 minutes), or at once with
Dashboard > Libraries > Scan.

**An episode I deleted and requested again downloads, but never shows up.**
Sonarr 4 remembers a finished download as "already imported" until it restarts, so the very
same release fetched again after a delete is ignored (Sonarr only fixes this in its next major
version; Radarr already did, in 6.4.4). Restart Sonarr - `sudo docker restart tortugarr-sonarr` -
and it imports the download within a minute. Picking another release for the episode also works.

**An indexer is missing from the search results.**
When a site fails (archive.org is down now and then), Prowlarr switches that indexer off for
a while - up to several hours - and Sonarr/Radarr then search without it. The app says which
indexers are unavailable. Check Prowlarr > System > Status. Once the site answers again,
press **Test** on that indexer in Prowlarr (Indexers > the indexer > Test) to switch it back
on at once instead of waiting.

**Radarr, Sonarr, Prowlarr, Bazarr, Seerr or qBittorrent says "New update is available".**
Expected and harmless. Every service is pinned in `versions.env` to a version tested together
with the Tortugarr app. Leave the notice; updating from the web page does not work inside Docker
anyway. Newer versions come with `sudo tortugarr update` when Tortugarr itself is updated.

**Jellyfin's dashboard says "Plugin updates available".**
Usually the Moonfin plugin. It may be updated: Tortugarr installs the version it was tested
with and keeps Jellyfin's automatic plugin updates on, so the update normally installs itself
at Jellyfin's next plugin check. Installing it from the dashboard is fine too.
`sudo tortugarr repair` only replaces Moonfin plugin versions older than the one this
Tortugarr release needs. (Only administrators see this notice.)

**Some videos will not play on the TV, others do.**
Check the audio codec of the ones that fail. If it is only Dolby (AC3/EAC3/Atmos)
that fails, the TV's audio passthrough to a soundbar/receiver has hung: restart
the TV (and the receiver). This is a TV problem, not a server problem.

**The address of the server changed.**
The doctor reports it. Run `sudo tortugarr reconfigure` and give the new address, or
better: give the server a fixed IP address in your router.

**"Port is already in use" during install.**
Another program uses that port. Pick another port when asked (the installer
suggests the next free one).

**A service shows an empty/fresh setup although its settings are on disk.**
Its settings folder was replaced while the container ran; the container still reads
the old, deleted one. `sudo tortugarr repair` recreates the containers.

**I changed the qBittorrent password in its web UI and now Sonarr cannot connect.**
Change it back, or put the new password in `/opt/tortugarr/secrets.json`
(`admin_password`) and run `sudo tortugarr repair`.

**The disk is full.**
The doctor warns at 90% and fails at 98%. Downloads and imports stop when the disk is
full. Free space, then run `sudo tortugarr repair`.

## Starting over

```bash
sudo tortugarr backup            # just in case
sudo tortugarr uninstall --purge # removes settings too; media is never deleted
sudo ./install.sh
```
