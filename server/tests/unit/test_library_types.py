"""Extra media folders with one type each: Jellyfin libraries follow the type. Replays the
2026-10-20 setup, where the XXX and MUSIC folders sat in "Movies" and Clips in "TV Shows".
A fake Jellyfin; nothing else is contacted.
    python3 -I tests/unit/test_library_types.py"""
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

FAILED = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


class FakeJellyfin:
    def __init__(self, folders):
        self.folders = folders  # name -> {"CollectionType", "Locations"}

    def get(self, path):
        assert path == "/Library/VirtualFolders", path
        return [{"Name": n, "CollectionType": f["CollectionType"], "Locations": list(f["Locations"])}
                for n, f in self.folders.items()]

    def post(self, path, body=None):
        if path.startswith("/Library/VirtualFolders?"):
            q = urllib.parse.parse_qs(path.split("?", 1)[1])
            self.folders[q["name"][0]] = {"CollectionType": q["collectionType"][0],
                                          "Locations": [p["Path"] for p in body["LibraryOptions"]["PathInfos"]]}
        elif path.startswith("/Library/VirtualFolders/Paths"):
            self.folders[body["Name"]]["Locations"].append(body["PathInfo"]["Path"])
        else:
            raise AssertionError(path)

    def delete(self, path):
        q = urllib.parse.parse_qs(path.split("?", 1)[1])
        self.folders[q["name"][0]]["Locations"].remove(q["path"][0])


def main():
    tb.ok = tb.info = tb.warn = lambda *a: None
    tb.STATE.clear()
    tb.STATE["extra_libraries"] = [
        {"host_path": "/mnt/e/-=Clips=-/", "container_path": "/data/library/1", "type": "other", "arr_manage": False},
        {"host_path": "/mnt/e/-=MOVIES=-/", "container_path": "/data/library/3", "type": "movies", "arr_manage": True},
        {"host_path": "/mnt/e/-=XxX=-/", "container_path": "/data/library/5", "type": "adult", "arr_manage": False},
        {"host_path": "/mnt/h/-=MUSIC=-/", "container_path": "/data/library/8", "type": "music", "arr_manage": False},
        {"host_path": "/mnt/h/-=Serier=-/", "container_path": "/data/library/9", "type": "tv", "arr_manage": True},
    ]
    jf = FakeJellyfin({
        "Movies": {"CollectionType": "movies", "Locations": [
            "/data/media/movies", "/data/library/3", "/data/library/5", "/data/library/8", "/data/my-own"]},
        "TV Shows": {"CollectionType": "tvshows", "Locations": ["/data/media/tv", "/data/library/1", "/data/library/9"]},
        "Adult": {"CollectionType": "homevideos", "Locations": ["/data/media/adult"]},
    })
    tb.jellyfin_libraries(jf)
    f = jf.folders
    check("Movies keeps its own folders", set(f["Movies"]["Locations"]) == {"/data/media/movies", "/data/library/3", "/data/my-own"},
          f["Movies"]["Locations"])
    check("a path added by hand is left alone", "/data/my-own" in f["Movies"]["Locations"])
    check("Clips left TV Shows", "/data/library/1" not in f["TV Shows"]["Locations"])
    check("Home Videos library made for Clips",
          f.get("Home Videos", {}).get("CollectionType") == "homevideos" and f["Home Videos"]["Locations"] == ["/data/library/1"])
    check("Music Videos library made for MUSIC",
          f.get("Music Videos", {}).get("CollectionType") == "musicvideos" and f["Music Videos"]["Locations"] == ["/data/library/8"])
    check("XXX moved into the adult library", "/data/library/5" in f["Adult"]["Locations"])

    before = {n: list(x["Locations"]) for n, x in f.items()}
    tb.jellyfin_libraries(jf)
    check("running again changes nothing", before == {n: x["Locations"] for n, x in f.items()})

    jf2 = FakeJellyfin({"Movies": {"CollectionType": "movies", "Locations": ["/data/media/movies", "/data/library/5"]}})
    tb.jellyfin_libraries(jf2)
    check("without an adult library the XXX folder is not shown anywhere",
          all("/data/library/5" not in x["Locations"] for x in jf2.folders.values()))

    check("Radarr roots: own folder + managed movie folders", tb.arr_roots("radarr") == ["/data/media/movies", "/data/library/3"])
    check("Sonarr roots: own folder + managed tv folders", tb.arr_roots("sonarr") == ["/data/media/tv", "/data/library/9"])

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
