# Tortugarr FAQ

Answers to the questions people actually ask, from first install to the remote control on the
sofa. This page is about **using** Tortugarr. Installing the server: see the
[install guide](../server/docs/install.md). Something broken on the server: see
[troubleshooting](../server/docs/troubleshooting.md).

---

## Contents

- [The basics](#the-basics)
- [Finding something to watch](#finding-something-to-watch)
- [Downloading](#downloading)
- [Series: missing episodes and seasons](#series-missing-episodes-and-seasons)
- [Movie collections](#movie-collections)
- [Subtitles](#subtitles)
- [Watching](#watching)
- [Away from home](#away-from-home)
- [The TV remote](#the-tv-remote)
- [Disk space and deleting](#disk-space-and-deleting)
- [Adult content](#adult-content)
- [Privacy and safety](#privacy-and-safety)
- [When something looks wrong](#when-something-looks-wrong)

---

## The basics

**What is Tortugarr?**
Your own streaming service at home. A server keeps your movies and series, and the Tortugarr
app on your TV, phone and tablet looks and feels like the big streaming apps. You browse what is
trending, pick what you want, and it lands in your library, all from the sofa with the remote.

**Why the name?**
Tortuga was the legendary pirate harbor: the safe place where the ships came home. The *arr*
tools Tortugarr is built on all end in "-arr", which is a pirate joke to begin with. Your server
is the harbor; the parrot is the mascot. No subscriptions, no ads, nothing disappears.

**Is it really free?**
Yes. No price, no ads, no tracking, no account with us. It is open source (GPL-2.0): use it,
change it and share it. Changed versions must stay open source too.

**Which devices does it run on?**
- **App:** Android TV / Google TV (TVs and sticks), and Android phones and tablets.
- **Server:** Linux (Ubuntu 22.04, 24.04 or 26.04). Windows 11 with WSL2 works through an optional
  helper, but is not officially supported.
- TVs without Android (LG webOS, Samsung Tizen) can use an Android TV stick.

**Do I need to know Docker, Linux or networking?**
Not much. The installer asks a few questions with sensible defaults and connects everything for
you. The one thing you do yourself is add your own indexers in a web form.

**Is it affiliated with Netflix, HBO or anyone else?**
No. Tortugarr ships software only: no content, no indexers, no accounts.

---

## Finding something to watch

**Why do Trending and Popular show only some languages?**
The language filter keeps the discovery rows to the languages you actually watch. By default
those are English, Norwegian, Swedish, Danish, German and French; everything else is hidden
there. Titles already in your library always show. Turn it off in **Settings > Hide foreign
content**.

**Can I see what the filter hides?**
Yes. Turn on **Settings > Show what is hidden**. Nothing is removed then. Hidden titles get a red
"HIDDEN · KO" style badge with their language code, and the ones you keep get a small green
badge (EN, NO, SE, DK, DE, FR). Turn it off again when you are done looking.

Changes to these settings show at once, also on a Seerr page that is already open.

**Will the rows look empty when the filter removes a lot?**
No. When titles are filtered out, the app fetches more until the row is full again.

**Why is a new movie missing from Trending?**
It is probably only in cinemas so far. Tortugarr hides movies from Trending until they are out
on digital or disc, because before that most copies are cinema recordings or unrelated films
with the same name. It comes back on its own once it is released, and you can still find it
through search.

**There are two searches. Which one should I use?**
- **Search** in the left menu looks through your own library *and* everything you can get.
- **Search** inside Seerr looks only at what you can get. It searches movies and series together;
  use the All / Movies / Series filter to narrow it down.

Both understand episode codes. Type "American Horror Story S13E04", "the boys s02" or
"1x05", and the app searches for the series and takes you straight to that season or episode.

---

## Downloading

**How do I download something?**
Open a movie or series and choose **Download Now**. Tortugarr searches for files and lets you
pick the exact one, with quality, size and how many people share it (seeders). Your choice goes
to your library automatically.

**Why can't I choose some files?**
Tortugarr filters out cinema recordings (CAM, TS, screeners), fake releases and files that are
too small to be real. Files outside your quality profile (often 4K) are shown dimmed at the
bottom with the reason. You can still pick them.

**Can I get a movie before its digital release?**
Sometimes, but expect lower quality. Download Now warns you first, and *Show files anyway* lets
you look. Waiting a few weeks for the digital release usually gets you far better quality.

**The movie I downloaded is the wrong film.**
Some releases borrow the name of a big film. Tortugarr warns before downloading a movie that is
not out digitally, and hides files published before its digital release. If one slips through,
delete it in the app and that release is blocked from coming back. A much shorter running time
than the real film is a giveaway.

**A download contained an `.exe` or no video at all.**
Fake releases do that, often with a perfectly normal name. Tortugarr checks the file list as
soon as the download starts and removes and blocks such torrents automatically. The download
client is also set up never to download executables.

**Where do I see how far a download is?**
On the title's page, where the request button was, and in **Downloads**. The bar appears as soon
as the file is picked, before Radarr or Sonarr list it in their own queue. On the phone,
Downloads sits in the bottom bar while something downloads; to keep it there, turn on
**Settings > Appearance > Navigation Bar > Always show Downloads**.

**I cancelled a request. Does the download stop?**
Yes. Cancelling a request in the app also removes what Radarr or Sonarr were downloading for it,
files included.

**The download is done, but the app says "Importing" for a minute or two.**
The file is being copied into your library. With a download client on Windows (or downloads and
library on separate mounts) it cannot simply be moved, so a large file takes a while. It shows up
in the library once the copy is done.

**Something downloaded "by itself".**
Tortugarr never turns on automatic downloading for you. It only happens for seasons you have
switched to *monitored* yourself (see the next section). If a title you deleted comes back, it
was still monitored: turn monitoring off for it.

**Which folder does a new movie go to?**
When you added your own movie folders during install, new movies go there: to the folder on the
drive with the most free space, and on one drive to the folder that already holds the most
movies. Documentaries go to the folders you marked as *Documentaries*, and no other movie does.
Tortugarr reads that from the movie's genre on TMDB, also for movies requested through Seerr.

**Radarr lists `/data/media/movies` (or Sonarr `/data/media/tv`). What is it?**
Tortugarr's own movie and series folders, used when you have no media folders of your own. With
your own folders they hold nothing and are removed from Radarr and Sonarr at the next repair.
Removing your own folders brings them back, since new titles need somewhere to go.

**Why did a finished download disappear from the download client?**
On many setups the file is moved into your library once it is done, so the torrent is removed
after import. Check the app: the title is in your library.

---

## Series: missing episodes and seasons

**How do I see which episodes I'm missing?**
Open a series. Every season and every episode is listed, also the ones you don't have:
- **Missing** (red badge): aired, but not in your library. Select it to download it.
- **Coming 12 Oct**: not aired yet.
- **Downloading**: on its way.
- **Ready soon**: downloaded, being added to the library.

This works however you get to the series: from Series, search, or *Continue watching*.

**Can I choose the quality of an episode?**
Yes. The file list has the same tabs as for movies: 2160p, 1080p, 720p, other and all, each with
the number of files. It opens on the best quality that has files.

**Can I download a whole season at once?**
Yes. When three or more episodes of a season are missing, **Whole season** appears at the top.
It searches for season packs, so a season comes as one download.

**How do I move between seasons?**
Use the season buttons above the episode list or the **Seasons** tab. Back takes you to where you
came from, not through every season you visited.

**What does "Monitored" on a season mean?**
A monitored season is followed automatically: new episodes are downloaded when they air. All
seasons are **off** by default. When you switch a season on, the app asks whether to fetch the
episodes that are already missing now (*Yes*) or only follow new ones (*No*).

**Missing episodes are not shown for one series.**
Then the app could not match the series. Usually the folder name is unusual or the series is not
known to the series manager yet. If the app offers **Add to library manager**, use it. The
series is added without downloading anything, and the missing episodes appear.

---

## Movie collections

**What is the "Part of the … collection" row?**
When a movie belongs to a series of films (Back to the Future, The Lord of the Rings, Rambo …),
its page shows the other films in order, marked "Part 2 of 5" and so on. Films you have open
their page; films you are missing are greyed out with **Missing** and go straight to Download
Now; films not out yet show **Coming**. Turn it off in **Settings > Show movie collections**.

---

## Subtitles

**Do I have to look for subtitles myself?**
No. Your server fetches subtitles automatically for everything in your library, new and old, in
the languages you chose when you installed it (English by default). Run
`sudo tortugarr reconfigure` to change them.

**Why does a new movie have no subtitles yet?**
Subtitles for brand-new releases, especially in smaller languages, often appear days or weeks
later. Tortugarr keeps looking once a day and adds them when they show up.

**Can I search for subtitles myself?**
Yes. On a movie or episode page choose **Find subtitles**. You see which languages are there,
can start an automatic search right away, or pick a subtitle from a list yourself.

**The subtitle menu used to show 40 languages. Where did they go?**
The menu shows only the languages you picked in Settings (plus Off), and any track without a
language tag. The subtitle you are currently using always stays visible. Turn on **Settings > Show all subtitle
languages** to see every track again.

**How do I change the subtitle size or colour while watching?**
Press the subtitle button. One menu opens with the tracks in your languages, and at the bottom
the size, the height on screen and the colour. Changes show at once and are kept for next time.
(Showing two subtitle tracks at the same time is not offered.)

**Does it use subtitles already inside the video file?**
Yes. Subtitles built into the file count, so nothing is downloaded for a language the file
already has.

**Is there a limit?**
The free subtitle account allows about 20 downloads a day. That is plenty for new downloads;
catching up on a large old library takes a few days and happens by itself.

---

## Watching

**Why is there a parrot spinning when I press play?**
That's the loading screen. On a good connection you will barely see it. Its size is set in
**Settings > Loading logo size** (25-100 %; full size on a TV and 40 % on a phone until you
pick one).

**Can the intro at start-up be shorter?**
Yes. Turn on **Settings > Short intro** for a four-second version instead of the full one.
Any button on the remote skips the intro.

**Can I watch 4K away from home?**
Yes, if your home upload speed allows it. 4K streams from a home server over a VPN start quickly
and play at full quality on a normal fibre connection.

**Dolby (AC3/EAC3/Atmos) titles do not start, but others do.**
On some TVs the audio connection to the receiver hangs after days of uptime. Restart the TV (and
the receiver if needed). It is not a server or file problem.

**Which audio setups work?**
Whatever your TV passes through. Atmos reaches an eARC receiver untouched, so height speakers
work.

**Something is playing in the background when I open another page.**
Trailers on the home screen stop as soon as another page covers the home screen. If you would
rather have no trailer sound at all, turn off **Settings > Preview sound**.

---

## Away from home

**Can I use Tortugarr outside my home?**
Yes, through a VPN to your home. WireGuard works well and is free.

**Do I have to switch the VPN on and off?**
No, not with the free app **WG Tunnel** on Android. Mark your home Wi-Fi as *trusted*. The VPN
then switches off when you get home and on everywhere else (mobile data, a friend's Wi-Fi, a
hotel) by itself.

**It works on mobile data but not on my home Wi-Fi with the VPN on.**
Many home routers cannot connect to their own public address from inside the home. Let WG
Tunnel switch the VPN off on your home Wi-Fi, as above, and it just works.

**Can I reach my server from a terminal on my phone or tablet?**
Yes. With Termux and an SSH key you log in without a password, at home and over the VPN.

---

## The TV remote

**Can I use my phone as the remote?**
Yes. The phone app has a remote control in its bottom bar. It lists the devices playing from your
server, so pick the TV, and you can steer it from the phone.

**Can the Netflix / YouTube / brand buttons open Tortugarr?**
On many Android TVs, yes, with the free app **Button Mapper** (by flar2) from the Play Store:
remap the button to open Tortugarr. Add the button in Button Mapper *before* you disable the
original app, or the TV may never report the key.

**After remapping, holding the volume button moves only one step at a time.**
On some TVs (TCL in particular) any app that listens to key presses breaks hold-to-repeat on
volume. That is a limit of the TV, not of Tortugarr. You choose: remapped buttons, or smooth
volume.

**The remapped buttons stopped working after the TV restarted.**
Some TVs block apps from starting in the background after a reboot. Allow Button Mapper to
start automatically in the TV's app settings.

**Holding volume suddenly moves only one step at a time (without any remapping).**
Restart the TV fully (hold the power button and choose to turn it off). That resets the volume
link to the receiver.

---

## Disk space and deleting

**What happens when the disk is nearly full?**
Before a download, Tortugarr checks the free space. If it's tight, it suggests what to remove:
leftover copies first, then titles nobody has watched in a long time. Favourites, recently added
and recently watched titles are never suggested.

**How do I delete something?**
Use **Delete** on the movie or series page. It deletes through the library managers, so the file
is removed properly and won't be downloaded again.

**Delete says the file does not match, or deletes only from the library.**
If Sonarr or Radarr do not manage the title, the app deletes it through Jellyfin instead. If the
file on disk does not match what the library expects, nothing is deleted and the app says so;
remove the file in a file manager then.

**I deleted something, but it is still on the home screen.**
The home screen refreshes once the library has dropped the title, usually within seconds. If not,
use *Refresh library* in the Downloads dialog or the administration pages.

**Can I manage the server from the TV?**
Yes. The administration pages work with the remote, so most everyday tasks don't need a PC.

---

## Adult content

**Where is the adult library?**
It is off on the server until an administrator switches it on, and the app cannot do that:
open Jellyfin in a browser (`http://<server>:8096`), **Dashboard > Plugins > Tortugarr**, tick
**Adult library** and **Save**, then run `sudo tortugarr repair`. After that it is hidden in the
app until you choose **Settings > Adult content (XXX) > Show (PIN)**. You choose the PIN the
first time. It is separate from any login PIN and stored per device.

**Why can't I find adult titles in the normal search?**
The movie database behind discovery doesn't list them. Use *Search for new XXX* in the same
dialog, which searches your indexers directly. Turn on *XXX search in the menu* there to have it
in the menu (on the phone, in the bottom bar) while the library is shown.

**A finished adult download stays in the download client.**
That is expected. It is saved straight into the adult folder, so there is nothing to move and the
torrent keeps seeding there.

**Does hiding it affect everyone on the same account?**
Yes, on every device. Use separate users if people need different settings.

---

## Privacy and safety

**Does Tortugarr phone home?**
No. The app talks to your own server and nothing else of ours.

**Is my server open to the internet?**
Not unless you open it. Out of the box it is for your home network; for remote use, go through
your own VPN.

**Should I use a VPN for downloading?**
That's your call and depends on where you live. The installer can route all download traffic
through a VPN with a kill switch.

---

## When something looks wrong

**Jellyfin says "Plugin updates available" for Moonfin. Should I update?**

Yes. The Moonfin server plugin (Moonbase) is the server side of the Moonfin app Tortugarr is
built on. Tortugarr installs the version it was tested with (2.4.0.0) and leaves Jellyfin's
automatic plugin updates on, so newer Moonfin plugin releases usually arrive by themselves.
Installing an update from the dashboard is fine too. Only versions older than 2.4.0.0 are
replaced by `sudo tortugarr repair`. If something stops working after a plugin update,
**report it at the Tortugarr issue tracker** (`https://github.com/tortugarr/tortugarr/issues`),
not in Moonfin's tracker.

**Where to report problems.** Bugs, support questions, and unexpected behaviour are handled
**only by the Tortugarr maintainers**. Please file **every** issue at the [Tortugarr GitHub
issues page](https://github.com/tortugarr/tortugarr/issues), and not in the upstream Moonfin
tracker. The upstream Moonfin project maintains and supports only its own media-player client
(`Moonfin`, org.moonfin.androidtv). The Moonfin developers bear **no responsibility for**, and
provide **no support for**, Tortugarr-specific builds, Tortugarr's server stack, or its
automation features.

**A series shows up under the wrong name (e.g. "Ted" appears as "Ted Lasso").**
The folder name was ambiguous. Rename the folder to `Title (Year)`. If that's not enough, add the
series' TVDB id, like `Ted (2024) [tvdbid-404604]`, and the library picks it up correctly after a
rescan.

**The same movie or series appears twice.**
It probably exists in two folders. Keep the better copy and delete the other one.

**Episodes show without numbers, or a season seems incomplete.**
Some downloads name episodes by title only. Rename the files to the usual
`Series (Year) - S01E05` pattern and rescan; the library then sorts them correctly.

**"Generate trickplay images" runs every night and never finishes.**
The scrubbing thumbnails are set to be saved next to your media, which the server is only
allowed to read. Turn off *Save trickplay images next to media* in each library. The first full
run takes a few hours; after that only new files are processed.

**A whole series started downloading when I asked for one episode.**
*Download Now* on an episode fetches only that episode. Two other things fetch more:
- **A monitored season** fetches every missing episode, and new ones as they air. Open the series,
  go to the season, and switch **Monitored** off.
- **Request** (the Seerr button) asks for whole seasons. Use *Download Now* when you want a
  single episode.

**Search finds nothing for an episode.**
- Check that the search filter is set to **All** or **Series**, not Movies.
- Search for the series by name, or type the episode code straight away, like
  "the boys s02e03".
- If the series is found but *Download Now* finds no files, read the message: it says whether
  only low-quality (SD) files exist, which filters removed files, or which indexer was down.
