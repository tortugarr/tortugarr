"""Titles whose /data/library/N now holds another folder are pointed back at the folder they are
in. Replays 2026-10-20: the extra folders had been numbered anew, so Sonarr had American Dad in
/data/library/2 (now E:\\-=Dokumentarer=-) while it sits in E:\\-=Serier=- (/data/library/4).
A fake Sonarr; nothing else is contacted.
    python3 -I tests/unit/test_relink_moved_titles.py"""
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


class FakeSonarr:
    def __init__(self, series, folders, roots, free=None):
        free = free or {}
        self.series = {s["id"]: s for s in series}
        self.folders = folders  # folder -> set of sub-folder names
        self.roots = [{"id": i + 1, "path": r, "freeSpace": free.get(r, 0)} for i, r in enumerate(roots)]
        self.puts, self.commands = [], []

    def get(self, path):
        if path == "/series":
            return [dict(s) for s in self.series.values()]
        if path == "/rootfolder":
            return [dict(r) for r in self.roots]
        if path.startswith("/filesystem?"):
            q = urllib.parse.parse_qs(path.split("?", 1)[1])
            base = q["path"][0].rstrip("/")
            return {"directories": [{"name": n, "path": f"{base}/{n}/"} for n in sorted(self.folders.get(base, ()))]}
        raise AssertionError(path)

    def put(self, path, body):
        assert path.endswith("?moveFiles=false"), path
        if any(s["path"] == body["path"] and s["id"] != body["id"] for s in self.series.values()):
            raise tb.BootstrapError("HTTP 400: is already configured for an existing series")
        self.puts.append(path)
        self.series[body["id"]] = body

    def post(self, path, body):
        assert path == "/command", path
        self.commands.append(body)

    def delete(self, path):
        rid = int(path.rsplit("/", 1)[1])
        self.roots = [r for r in self.roots if r["id"] != rid]


def main():
    tb.ok = tb.info = tb.warn = lambda *a: None
    tb.STATE.clear()
    tb.STATE["extra_libraries"] = [
        {"host_path": "/mnt/e/-=Dokumentarer=-/", "container_path": "/data/library/2", "type": "movies", "arr_manage": True},
        {"host_path": "/mnt/e/-=Serier=-/", "container_path": "/data/library/4", "type": "tv", "arr_manage": True},
        {"host_path": "/mnt/h/-=Serier=-/", "container_path": "/data/library/9", "type": "tv", "arr_manage": True},
        {"host_path": "/mnt/e/-=Clips=-/", "container_path": "/data/library/1", "type": "other", "arr_manage": False},
    ]
    sonarr = FakeSonarr(
        series=[{"id": 1, "path": "/data/library/2/American Dad", "rootFolderPath": "/data/library/2"},
                {"id": 2, "path": "/data/library/9/Futurama", "rootFolderPath": "/data/library/9"},
                {"id": 3, "path": "/data/library/2/Gone Show", "rootFolderPath": "/data/library/2"},
                {"id": 4, "path": "/data/library/2/Twice", "rootFolderPath": "/data/library/2"},
                {"id": 5, "path": "/data/library/2/Crystal Lake", "rootFolderPath": "/data/library/2"},
                {"id": 6, "path": "/data/library/1/clips", "rootFolderPath": "/data/library/1"}],
        folders={"/data/library/2": {"Some Documentary (2020)"},
                 "/data/library/4": {"American Dad", "Twice"},
                 "/data/library/9": {"Futurama", "Twice"},
                 "/data/library/1": {"clips"}},
        roots=["/data/library/2", "/data/media/tv", "/data/library/4", "/data/library/9", "/data/library/1"],
        free={"/data/media/tv": 800, "/data/library/4": 50, "/data/library/9": 7})
    warnings = []
    tb.warn = warnings.append
    tb.relink_moved_titles("sonarr", sonarr)
    s = sonarr.series
    check("American Dad pointed at E: Serier",
          (s[1]["path"], s[1]["rootFolderPath"]) == ("/data/library/4/American Dad", "/data/library/4"), s[1])
    check("a title in the right place is left alone", s[2]["path"] == "/data/library/9/Futurama")
    check("wanted title in a movies folder moved to the roomiest tv folder",
          s[5]["path"] == "/data/media/tv/Crystal Lake" and s[3]["path"] == "/data/media/tv/Gone Show", (s[5], s[3]))
    check("a title found in two folders is left alone", s[4]["path"] == "/data/library/2/Twice")
    check("files are not moved", all(p.endswith("?moveFiles=false") for p in sonarr.puts) and len(sonarr.puts) == 3)
    check("moved titles refreshed", sonarr.commands == [{"name": "RefreshSeries", "seriesIds": [1, 3, 5]}], sonarr.commands)
    check("a series really in the clips folder is listed, not moved",
          s[6]["path"] == "/data/library/1/clips" and any("/data/library/1/clips" in w for w in warnings), warnings)
    check("root folder still in use is kept", any(r["path"] == "/data/library/2" for r in sonarr.roots))
    check("clips root kept while a title is in it", any(r["path"] == "/data/library/1" for r in sonarr.roots))

    # Two titles for one folder (Radarr, 2026-10-20: The Summit): the PUT is refused, the rest goes on.
    s[4]["path"] = "/data/library/4/Twice"
    sonarr.series[7] = {"id": 7, "path": "/data/library/2/American Dad", "rootFolderPath": "/data/library/2"}
    sonarr.folders["/data/library/9"].discard("Twice")
    del warnings[:]
    tb.relink_moved_titles("sonarr", sonarr)
    check("a second title for the same folder is reported, not fatal",
          sonarr.series[7]["path"] == "/data/library/2/American Dad" and any("American Dad" in w for w in warnings), warnings)
    del sonarr.series[7]
    tb.relink_moved_titles("sonarr", sonarr)
    check("movies root folder without titles removed from Sonarr",
          [r["path"] for r in sonarr.roots] == ["/data/media/tv", "/data/library/4", "/data/library/9", "/data/library/1"],
          [r["path"] for r in sonarr.roots])

    puts = len(sonarr.puts)
    tb.relink_moved_titles("sonarr", sonarr)
    check("running again changes nothing", len(sonarr.puts) == puts)

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
