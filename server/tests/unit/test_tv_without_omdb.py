"""OMDb off for series/seasons/episodes in TV libraries, kept for movies (2026-11-07: 480
OMDb episode errors in a day). A fake Jellyfin; nothing else is contacted.
    python3 -I tests/unit/test_tv_without_omdb.py"""
import copy
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

FAILED = []
OMDB = tb.OMDB_FETCHER


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


def fetchers(*names):
    return [{"Name": n, "DefaultEnabled": True} for n in names]


AVAILABLE = {"TypeOptions": [
    {"Type": t, "MetadataFetchers": fetchers("TheMovieDb", OMDB, "TheTVDB"),
     "ImageFetchers": fetchers("TheMovieDb", "TheTVDB"), "DefaultImageOptions": [{"Type": "Primary", "Limit": 1}]}
    for t in ("Series", "Season", "Episode")]}


class FakeJellyfin:
    def __init__(self, folders):
        self.folders = folders
        self.posts = []

    def get(self, path):
        if path.startswith("/Libraries/AvailableOptions"):
            return copy.deepcopy(AVAILABLE)
        assert path == "/Library/VirtualFolders", path
        return copy.deepcopy(self.folders)

    def post(self, path, body):
        assert path == "/Library/VirtualFolders/LibraryOptions", path
        self.posts.append(body)
        for f in self.folders:
            if f["ItemId"] == body["Id"]:
                f["LibraryOptions"] = copy.deepcopy(body["LibraryOptions"])


def folder(name, ctype, type_options=None, locations=("/data/media/tv",)):
    opts = {"PathInfos": [{"Path": p} for p in locations], "EnableRealtimeMonitor": True}
    if type_options is not None:
        opts["TypeOptions"] = type_options
    return {"Name": name, "ItemId": "id-" + name, "CollectionType": ctype, "Locations": list(locations),
            "LibraryOptions": opts}


def main():
    tb.ok = tb.info = tb.warn = tb.important = lambda *a: None
    tb.STATE.clear()

    j = FakeJellyfin([folder("TV Shows", "tvshows"), folder("Movies", "movies", locations=("/data/media/movies",))])
    tb.jellyfin_tv_without_omdb(j)
    check("one library changed (TV Shows only)", len(j.posts) == 1 and j.posts[0]["Id"] == "id-TV Shows")
    tv = j.folders[0]["LibraryOptions"]
    types = {t["Type"]: t for t in tv.get("TypeOptions", [])}
    check("series, season and episode set", set(types) == {"Series", "Season", "Episode"})
    check("OMDb gone, TMDB and TVDB kept",
          all(t["MetadataFetchers"] == ["TheMovieDb", "TheTVDB"] for t in types.values()), types)
    check("image fetchers stay on", all(t["ImageFetchers"] == ["TheMovieDb", "TheTVDB"] for t in types.values()))
    check("other options kept", tv["EnableRealtimeMonitor"] and tv["PathInfos"] == [{"Path": "/data/media/tv"}])
    check("movies untouched", "TypeOptions" not in j.folders[1]["LibraryOptions"])

    tb.jellyfin_tv_without_omdb(j)
    check("second run changes nothing", len(j.posts) == 1)

    own = [{"Type": "Episode", "MetadataFetchers": [OMDB, "TheTVDB"], "MetadataFetcherOrder": ["TheTVDB", OMDB],
            "ImageFetchers": ["TheTVDB"]},
           {"Type": "Series", "MetadataFetchers": ["TheTVDB"], "ImageFetchers": []}]
    j = FakeJellyfin([folder("Clips", "tvshows", type_options=own, locations=("/data/library/3",))])
    tb.jellyfin_tv_without_omdb(j)
    types = {t["Type"]: t for t in j.folders[0]["LibraryOptions"]["TypeOptions"]}
    check("the user's own choices are kept, only OMDb goes", types["Episode"]["MetadataFetchers"] == ["TheTVDB"]
          and types["Episode"]["ImageFetchers"] == ["TheTVDB"] and types["Series"]["MetadataFetchers"] == ["TheTVDB"])
    check("a type without settings gets defaults minus OMDb", types["Season"]["MetadataFetchers"] == ["TheMovieDb", "TheTVDB"])

    if FAILED:
        print(f"\n{len(FAILED)} failed")
        sys.exit(1)
    print("\nall passed")


if __name__ == "__main__":
    main()
