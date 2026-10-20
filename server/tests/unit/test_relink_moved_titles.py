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
    def __init__(self, series, folders, roots):
        self.series = {s["id"]: s for s in series}
        self.folders = folders  # folder -> set of sub-folder names
        self.roots = [{"id": i + 1, "path": r} for i, r in enumerate(roots)]
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
    ]
    sonarr = FakeSonarr(
        series=[{"id": 1, "path": "/data/library/2/American Dad", "rootFolderPath": "/data/library/2"},
                {"id": 2, "path": "/data/library/9/Futurama", "rootFolderPath": "/data/library/9"},
                {"id": 3, "path": "/data/library/2/Gone Show", "rootFolderPath": "/data/library/2"},
                {"id": 4, "path": "/data/library/2/Twice", "rootFolderPath": "/data/library/2"}],
        folders={"/data/library/2": {"Some Documentary (2020)"},
                 "/data/library/4": {"American Dad", "Twice"},
                 "/data/library/9": {"Futurama", "Twice"}},
        roots=["/data/library/2", "/data/media/tv", "/data/library/4", "/data/library/9"])
    tb.relink_moved_titles("sonarr", sonarr)
    s = sonarr.series
    check("American Dad pointed at E: Serier",
          (s[1]["path"], s[1]["rootFolderPath"]) == ("/data/library/4/American Dad", "/data/library/4"), s[1])
    check("a title in the right place is left alone", s[2]["path"] == "/data/library/9/Futurama")
    check("a title found nowhere is left alone", s[3]["path"] == "/data/library/2/Gone Show")
    check("a title found in two folders is left alone", s[4]["path"] == "/data/library/2/Twice")
    check("files are not moved", all(p.endswith("?moveFiles=false") for p in sonarr.puts) and len(sonarr.puts) == 1)
    check("moved title refreshed", sonarr.commands == [{"name": "RefreshSeries", "seriesIds": [1]}], sonarr.commands)
    check("root folder still in use is kept", any(r["path"] == "/data/library/2" for r in sonarr.roots))

    s[3]["path"], s[4]["path"] = "/data/library/4/Gone Show", "/data/library/4/Twice"
    tb.relink_moved_titles("sonarr", sonarr)
    check("movies root folder without titles removed from Sonarr",
          [r["path"] for r in sonarr.roots] == ["/data/media/tv", "/data/library/4", "/data/library/9"],
          [r["path"] for r in sonarr.roots])

    puts = len(sonarr.puts)
    tb.relink_moved_titles("sonarr", sonarr)
    check("running again changes nothing", len(sonarr.puts) == puts)

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
