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
    def __init__(self, folders, users=None):
        self.folders = folders  # name -> {"CollectionType", "Locations"}
        self.users = users or []

    def get(self, path):
        if path == "/Users":
            return [dict(u) for u in self.users]
        if path.startswith("/Items?"):
            return {"TotalRecordCount": 0}
        assert path == "/Library/VirtualFolders", path
        return [{"Name": n, "ItemId": "id-" + n, "CollectionType": f["CollectionType"], "Locations": list(f["Locations"])}
                for n, f in self.folders.items()]

    def post(self, path, body=None):
        if path.startswith("/Users/"):
            uid = path.split("/")[2]
            self.users = [dict(u, Policy=body) if u["Id"] == uid else u for u in self.users]
        elif path.startswith("/Library/VirtualFolders?"):
            q = urllib.parse.parse_qs(path.split("?", 1)[1])
            self.folders[q["name"][0]] = {"CollectionType": q["collectionType"][0],
                                          "Locations": [p["Path"] for p in body["LibraryOptions"]["PathInfos"]]}
        elif path.startswith("/Library/VirtualFolders/Paths"):
            self.folders[body["Name"]]["Locations"].append(body["PathInfo"]["Path"])
        else:
            raise AssertionError(path)

    def delete(self, path):
        q = urllib.parse.parse_qs(path.split("?", 1)[1])
        if "path" not in q:
            del self.folders[q["name"][0]]
            return
        self.folders[q["name"][0]]["Locations"].remove(q["path"][0])


def main():
    tb.ok = tb.info = tb.warn = tb.important = lambda *a: None
    tb.STATE.clear()
    tb.STATE.update(lan_ip="192.168.1.15", ports={"jellyfin": 8096})
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
    }, users=[{"Id": "u1", "Name": "odwar420", "Policy": {"EnableAllFolders": False,
                                                          "EnabledFolders": ["id-Movies", "id-TV Shows"]}},
              {"Id": "u2", "Name": "kid", "Policy": {"EnableAllFolders": False, "EnabledFolders": ["id-TV Shows"]}}])
    tb.jellyfin_libraries(jf)
    f = jf.folders
    check("Movies keeps the user's folders; Tortugarr's own (Linux disk) goes, new titles go to /data/library/3",
          set(f["Movies"]["Locations"]) == {"/data/library/3", "/data/my-own"}, f["Movies"]["Locations"])
    check("a path added by hand is left alone", "/data/my-own" in f["Movies"]["Locations"])
    check("Clips left TV Shows", "/data/library/1" not in f["TV Shows"]["Locations"])
    check("Home Videos library made for Clips",
          f.get("Home Videos", {}).get("CollectionType") == "homevideos" and f["Home Videos"]["Locations"] == ["/data/library/1"])
    check("Music Videos library made for MUSIC",
          f.get("Music Videos", {}).get("CollectionType") == "musicvideos" and f["Music Videos"]["Locations"] == ["/data/library/8"])
    check("XXX moved into the adult library", "/data/library/5" in f["Adult"]["Locations"])

    check("the account that sees Movies gets the new libraries",
          set(jf.users[0]["Policy"]["EnabledFolders"]) >= {"id-Home Videos", "id-Music Videos"}, jf.users[0])
    check("an account without Movies is left alone", jf.users[1]["Policy"]["EnabledFolders"] == ["id-TV Shows"])

    before = {n: list(x["Locations"]) for n, x in f.items()}
    tb.jellyfin_libraries(jf)
    check("running again changes nothing", before == {n: x["Locations"] for n, x in f.items()})

    jf2 = FakeJellyfin({"Movies": {"CollectionType": "movies", "Locations": ["/data/media/movies", "/data/library/5"]}})
    tb.jellyfin_libraries(jf2)
    check("without an adult library the XXX folder is not shown anywhere",
          all("/data/library/5" not in x["Locations"] for x in jf2.folders.values()))

    tb.STATE["new_titles_in_extra_only"] = False
    jf5 = FakeJellyfin({"Movies": {"CollectionType": "movies", "Locations": ["/data/library/3"]}})
    tb.jellyfin_libraries(jf5)
    check("with own folders as a choice too, Tortugarr's movie folder is in Movies",
          "/data/media/movies" in jf5.folders["Movies"]["Locations"], jf5.folders)
    del tb.STATE["new_titles_in_extra_only"]

    # 2026-10-20: the user made "Music & Conserts" for the MUSIC folder; Tortugarr leaves it there.
    jf3 = FakeJellyfin({"Music & Conserts": {"CollectionType": "movies", "Locations": ["/data/library/8"]},
                        "Movies": {"CollectionType": "movies", "Locations": ["/data/media/movies", "/data/library/3"]}})
    tb.jellyfin_libraries(jf3)
    check("a folder in the user's own library stays there, no second library",
          jf3.folders["Music & Conserts"]["Locations"] == ["/data/library/8"] and "Music Videos" not in jf3.folders,
          jf3.folders)

    # 2026-10-20: the adult library was moved to the user's XXX folder and the plugin made an
    # empty "Adult2" on /data/media/adult. With a qBittorrent on Windows the adult library is the
    # user's folder, and the empty leftover goes.
    tb.STATE["torrent_client"] = "qbittorrent-ext"
    check("adult library lives in the user's adult folder", tb.adult_save_path() == "/data/library/5")
    jf4 = FakeJellyfin({"Adult": {"CollectionType": "homevideos", "Locations": ["/data/library/5"]},
                        "Adult2": {"CollectionType": "homevideos", "Locations": ["/data/media/adult"]}})
    tb.jellyfin_libraries(jf4)
    check("the empty Adult2 on the Linux disk is removed, Adult stays",
          "Adult2" not in jf4.folders and jf4.folders["Adult"]["Locations"] == ["/data/library/5"], jf4.folders)
    tb.STATE["torrent_client"] = "qbittorrent"

    check("Radarr roots: own folder + managed movie folders", tb.arr_roots("radarr") == ["/data/media/movies", "/data/library/3"])
    check("Sonarr roots: own folder + managed tv folders", tb.arr_roots("sonarr") == ["/data/media/tv", "/data/library/9"])

    check("new movies only in the user's own movie folders by default", tb.new_title_roots("radarr") == ["/data/library/3"])
    check("new series only in the user's own tv folders by default", tb.new_title_roots("sonarr") == ["/data/library/9"])
    tb.STATE["new_titles_in_extra_only"] = False
    check("switched off: Tortugarr's own folder is a choice too",
          tb.new_title_roots("radarr") == ["/data/media/movies", "/data/library/3"])
    del tb.STATE["new_titles_in_extra_only"]

    # 2026-10-21: Fall landed in the documentary folder. Documentary folders are Radarr's, but
    # never a place for new movies, and they make their own Jellyfin library.
    tb.STATE["extra_libraries"].append({"host_path": "/mnt/e/-=Dokumentarer=-", "container_path": "/data/library/2",
                                        "type": "docs", "arr_manage": True})
    check("documentary folders are Radarr roots", "/data/library/2" in tb.arr_roots("radarr"))
    check("documentary folders are not Sonarr roots", "/data/library/2" not in tb.arr_roots("sonarr"))
    check("new movies never go to a documentary folder", tb.new_title_roots("radarr") == ["/data/library/3"])
    check("documentary roots", tb.doc_roots() == ["/data/library/2"])
    check("documentaries have a library of their own",
          tb.extra_library_paths()["Documentaries"] == ("movies", ["/data/library/2"]))
    tb.STATE["extra_libraries"] = []
    tb.STATE["new_titles_in_extra_only"] = True
    check("without own folders Tortugarr's folder is used", tb.new_title_roots("radarr") == ["/data/media/movies"])

    # 2026-10-21: Tortugarr's own folder sat unused in Radarr's list and puzzled the user.
    class FakeArr:
        def __init__(self, folders, titles):
            self.folders, self.titles, self.deleted = folders, titles, []

        def get(self, path):
            return self.folders if path == "/rootfolder" else self.titles

        def delete(self, path):
            self.deleted.append(path)

    tb.STATE["extra_libraries"] = [{"host_path": "/mnt/e/m", "container_path": "/data/library/3", "type": "movies",
                                    "arr_manage": True}]
    folders = [{"id": 1, "path": "/data/media/movies"}, {"id": 2, "path": "/data/library/3"}]
    empty = FakeArr(folders, [{"path": "/data/library/3/Fall (2022)"}])
    tb.remove_unused_own_root("radarr", empty, "/data/media/movies")
    check("an empty own folder leaves Radarr when new movies go to the user's", empty.deleted == ["/rootfolder/1"])
    used = FakeArr(folders, [{"path": "/data/media/movies/Old (1999)"}])
    tb.remove_unused_own_root("radarr", used, "/data/media/movies")
    check("one with a movie in it stays", used.deleted == [])
    tb.STATE["extra_libraries"] = []
    alone = FakeArr(folders, [])
    tb.remove_unused_own_root("radarr", alone, "/data/media/movies")
    check("without own folders it is the movie folder and stays", alone.deleted == [])

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
