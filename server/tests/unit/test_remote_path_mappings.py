"""Path mappings for a qBittorrent on Windows. Replays 2026-10-21: a first install mounted
E:\\Downloads\\radarr itself, a reconfigure then mounted E:\\Downloads at the same container
folder, and the old mapping E:\\Downloads\\radarr\\ -> /data/torrents-ext/2/ stayed. Being the
most specific one it would have sent every import to the wrong folder.
A fake Radarr; nothing else is contacted.
    python3 -I tests/unit/test_remote_path_mappings.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

FAILED = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


class FakeArr:
    def __init__(self, maps):
        self.maps = [dict(m, id=i + 1) for i, m in enumerate(maps)]
        self.next = len(maps) + 1

    def get(self, path):
        if path == "/remotepathmapping":
            return [dict(m) for m in self.maps]
        if path.startswith("/filesystem"):
            return {"directories": [{"path": "/data/torrents-ext/1/"}, {"path": "/data/torrents-ext/2/"}]}
        raise AssertionError(path)

    def post(self, path, body):
        self.maps.append(dict(body, id=self.next)); self.next += 1

    def delete(self, path):
        rid = int(path.rsplit("/", 1)[1])
        self.maps = [m for m in self.maps if m["id"] != rid]


def main():
    tb.ok = tb.info = tb.warn = lambda *a: None
    tb.STATE.clear()
    tb.STATE["torrent_client"] = "qbittorrent-ext"
    tb.STATE["external_qbit"] = {"url": "http://192.168.1.15:8070", "mounts": [
        {"remote": "H:\\Downloads\\", "host_path": "/mnt/h/Downloads", "container_path": "/data/torrents-ext/1"},
        {"remote": "E:\\Downloads\\", "host_path": "/mnt/e/Downloads", "container_path": "/data/torrents-ext/2"}]}
    h = "192.168.1.15"
    arr = FakeArr([
        {"host": h, "remotePath": "H:\\Downloads\\", "localPath": "/data/torrents-ext/1/"},
        {"host": h, "remotePath": "E:\\Downloads\\radarr\\", "localPath": "/data/torrents-ext/2/"},
        {"host": h, "remotePath": "H:\\Downloads\\sonarr\\", "localPath": "/data/torrents-ext/1/sonarr/"},
        {"host": "nas.lan", "remotePath": "E:\\Downloads\\radarr\\", "localPath": "/elsewhere/"},
    ])
    tb.configure_remote_paths("radarr", arr)
    got = {(m["host"], m["remotePath"], m["localPath"]) for m in arr.maps}
    check("the stale category mapping on the same container folder is removed",
          (h, "E:\\Downloads\\radarr\\", "/data/torrents-ext/2/") not in got, got)
    check("E:\\Downloads\\ is mapped", (h, "E:\\Downloads\\", "/data/torrents-ext/2/") in got, got)
    check("a deeper mapping onto the matching sub-folder is kept",
          (h, "H:\\Downloads\\sonarr\\", "/data/torrents-ext/1/sonarr/") in got, got)
    check("another host's mapping is left alone", ("nas.lan", "E:\\Downloads\\radarr\\", "/elsewhere/") in got, got)
    n = len(arr.maps)
    tb.configure_remote_paths("radarr", arr)
    check("running again changes nothing", len(arr.maps) == n)
    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
