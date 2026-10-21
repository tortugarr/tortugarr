"""Library import of an existing media folder. Replays 2026-10-20: downloads requested through
Seerr had been moved by hand into H:\\-=MOVIES=- (/data/library/7) under their release names,
while Radarr still waited for them elsewhere without a file. A fake Radarr; nothing else is
contacted.
    python3 -I tests/unit/test_import_existing.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

FAILED = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


ROOT = "/data/library/7"


class FakeRadarr:
    def __init__(self):
        self.movies = {
            1: {"id": 1, "tmdbId": 10, "title": "Buddy", "year": 2026, "path": "/data/media/movies/Buddy (2026)", "hasFile": False},
            2: {"id": 2, "tmdbId": 20, "title": "Cliffhanger", "year": 1993, "path": "/data/media/movies/Cliffhanger (1993)", "hasFile": True},
            3: {"id": 3, "tmdbId": 30, "title": "7 Days in Hell", "year": 2015, "path": "/data/media/movies/7 Days in Hell (2015)", "hasFile": False},
        }
        self.unmapped = ["Buddy 2026 2160p WEB-DL SDR DDP 5.1 H.265-THD", "Cliffhanger (1993) [2160p] [4K]",
                         "7 Days In Hell (2015) [1080p] [WEBRip]", "7 Days in Hell 2015 1080p AMZN WEB-DL"]
        self.puts, self.commands = [], []

    def get(self, path):
        if path == "/rootfolder":
            return [{"path": ROOT, "unmappedFolders": [{"name": n, "path": f"{ROOT}/{n}"} for n in self.unmapped]}]
        if path == "/qualityprofile":
            return [{"id": 4, "name": "HD-1080p"}]
        if path.startswith("/movie/lookup?term="):
            term = path.split("=", 1)[1].lower()
            return [dict(m) for m in self.movies.values() if m["title"].lower().replace(" ", "%20") in term
                    or m["title"].lower() in term]
        if path.startswith("/movie/"):
            return dict(self.movies[int(path.rsplit("/", 1)[1])])
        raise AssertionError(path)

    def put(self, path, body):
        assert path.endswith("?moveFiles=false"), path
        self.puts.append(path)
        self.movies[body["id"]] = body

    def post(self, path, body):
        if path == "/command":
            self.commands.append(body)
            return
        raise AssertionError("nothing new should be added: " + path)


def main():
    notes = []
    tb.ok = tb.info = tb.warn = notes.append
    tb.STATE.clear()
    r = FakeRadarr()
    tb.import_existing("radarr", r, ROOT)
    check("wanted movie takes the folder it was moved to",
          r.movies[1]["path"] == f"{ROOT}/Buddy 2026 2160p WEB-DL SDR DDP 5.1 H.265-THD", r.movies[1])
    check("movie with a file is left alone", r.movies[2]["path"] == "/data/media/movies/Cliffhanger (1993)")
    check("of two folders for one wanted movie only the first is taken",
          r.movies[3]["path"] == f"{ROOT}/7 Days In Hell (2015) [1080p] [WEBRip]" and len(r.puts) == 2, r.puts)
    check("adopted titles refreshed", [c["movieIds"] for c in r.commands] == [[1], [3]], r.commands)
    check("the second copies are reported", any("Cliffhanger" in n and "AMZN" in n for n in notes), notes)
    # 2026-10-21: Radarr filled in the Lord of the Rings collection while The Two Towers was
    # added, and the add failed on a UNIQUE constraint. One retry a moment later adds it.
    class Collection(FakeRadarr):
        def __init__(self):
            super().__init__()
            self.movies = {}
            self.unmapped = ["The.Lord.of.the.Rings.The.Two.Towers.2002.2160p"]
            self.posts = 0

        def get(self, path):
            if path.startswith("/movie/lookup?term="):
                return [{"tmdbId": 121, "title": "The Two Towers", "year": 2002}]
            return super().get(path)

        def post(self, path, body):
            self.posts += 1
            if self.posts == 1:
                raise tb.BootstrapError('HTTP 500: {"errorMessage": "code = Constraint (19), message = '
                                        'constraint failed\\nUNIQUE constraint failed: MovieMetadata.TmdbId\\n   at x"}')

    sleeps, real_sleep = [], tb.time.sleep
    tb.time.sleep = sleeps.append
    try:
        c = Collection()
        out = []
        real_ok, real_warn = tb.ok, tb.warn
        tb.ok, tb.warn = out.append, out.append
        tb.import_existing("radarr", c, ROOT)
        tb.ok, tb.warn = real_ok, real_warn
    finally:
        tb.time.sleep = real_sleep
    check("a collection race is retried once and the title is added",
          c.posts == 2 and sleeps == [5] and any("1 existing title" in o for o in out), out)

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
