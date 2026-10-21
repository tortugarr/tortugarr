"""Seerr's Jellyfin library sync on both API forms. Replays 2026-10-21: Seerr 3.5.0 answered
GET /settings/jellyfin/library?sync=true with 400 "Unknown query parameter 'sync'".
A fake Seerr; nothing else is contacted.
    python3 -I tests/unit/test_seerr_library_sync.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

FAILED = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


LIBS = [{"id": "m", "type": "movie", "enabled": False}, {"id": "t", "type": "show", "enabled": False},
        {"id": "h", "type": "homevideos", "enabled": False}]


class Seerr35:
    def __init__(self):
        self.puts = {}

    def post(self, path, body=None):
        assert path == "/settings/jellyfin/library/sync", path
        return [dict(x) for x in LIBS]

    def put(self, path, body):
        self.puts[path.rsplit("/", 1)[1]] = body["enabled"]

    def get(self, path):
        raise tb.BootstrapError(f"GET {path} -> HTTP 400: Unknown query parameter 'sync'")


class Seerr34:
    def __init__(self):
        self.gets = []

    def post(self, path, body=None):
        raise tb.BootstrapError(f"POST {path} -> HTTP 404: not found")

    def get(self, path):
        self.gets.append(path)
        return [dict(x) for x in LIBS]


def main():
    s = Seerr35()
    tb.seerr_sync_libraries(s)
    check("Seerr 3.5: movie and series libraries switched on, nothing else", s.puts == {"m": True, "t": True}, s.puts)
    s = Seerr34()
    tb.seerr_sync_libraries(s)
    check("Seerr 3.4: the GET form still works",
          s.gets == ["/settings/jellyfin/library?sync=true", "/settings/jellyfin/library?enable=m,t"], s.gets)
    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
