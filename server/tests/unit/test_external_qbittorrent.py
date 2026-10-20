"""A qBittorrent outside the stack (torrent_client qbittorrent-ext): Radarr's download client and
remote path mappings. Replays 2026-10-18: the container was stopped for a qBittorrent on Windows,
Radarr got a client named "qBittorrent" by hand and a mapping to a folder inside the container
that was not the Windows one, so nothing was imported. A fake Radarr; nothing else is contacted.
    python3 -I tests/unit/test_external_qbittorrent.py"""
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


class FakeRadarr:
    """Just the endpoints configure_remote_paths uses; folders as a set of visible paths."""

    def __init__(self, maps, visible):
        self.maps = [dict(m, id=i + 1) for i, m in enumerate(maps)]
        self.visible = visible
        self.next_id = len(self.maps) + 1

    def get(self, path):
        if path == "/remotepathmapping":
            return [dict(m) for m in self.maps]
        if path.startswith("/filesystem?"):
            q = urllib.parse.parse_qs(path.split("?", 1)[1])
            base = q["path"][0].rstrip("/")
            dirs = [{"path": v + "/", "name": v.rsplit("/", 1)[1]} for v in sorted(self.visible)
                    if v.rsplit("/", 1)[0] == base]
            return {"directories": dirs}
        raise AssertionError(path)

    def post(self, path, body):
        assert path == "/remotepathmapping", path
        self.maps.append(dict(body, id=self.next_id))
        self.next_id += 1

    def put(self, path, body):
        raise AssertionError("unexpected put " + path)

    def delete(self, path):
        mid = int(path.rsplit("/", 1)[1])
        self.maps = [m for m in self.maps if m["id"] != mid]


def main():
    tb.ok = tb.warn = tb.info = lambda *a: None
    warnings = []
    tb.warn = warnings.append

    check("url parts", tb.url_parts("http://192.168.1.15:8070") == ("192.168.1.15", 8070, False, ""))
    check("url parts with ssl and base", tb.url_parts("https://nas.lan/qbt/") == ("nas.lan", 443, True, "/qbt"))

    tb.STATE.clear()
    tb.STATE.update({"torrent_client": "qbittorrent-ext", "external_qbit": {
        "url": "http://192.168.1.15:8070", "username": "",
        "mounts": [{"remote": "H:\\Downloads\\", "host_path": "/mnt/h/Downloads",
                    "container_path": "/data/torrents-ext/1"}]}})
    tb.SECRETS.clear()
    tb.SECRETS.update({"admin_user": "captain", "admin_password": "parrot-1234"})

    v = tb.download_client_values("radarr", "qbittorrent-ext")
    check("client host and port from the address", (v["host"], v["port"], v["useSsl"]) == ("192.168.1.15", 8070, False))
    check("no Tortugarr admin login sent to the user's qBittorrent", v["username"] == "" and v["password"] == "")
    check("radarr category", v["movieCategory"] == "radarr")
    check("plugin and app use the user's address", tb.download_client_url() == "http://192.168.1.15:8070")
    check("plugin sees a plain qBittorrent", tb.client_kind() == "qbittorrent")

    # The state on 2026-10-18: a mapping into the container's own torrents folder.
    radarr = FakeRadarr(
        maps=[{"host": "192.168.1.15", "remotePath": "H:\\Downloads\\radarr\\", "localPath": "/data/torrents/movies/"},
              {"host": "nas.lan", "remotePath": "/volume1/dl/", "localPath": "/data/nas/"}],
        visible={"/data/torrents-ext/1", "/data/torrents-ext/1/radarr", "/data/torrents/movies"})
    tb.configure_remote_paths("radarr", radarr)
    pairs = {(m["host"], m["remotePath"], m["localPath"]) for m in radarr.maps}
    check("stale mapping into the container's own folder removed",
          ("192.168.1.15", "H:\\Downloads\\radarr\\", "/data/torrents/movies/") not in pairs)
    check("mapping to the mounted folder added",
          ("192.168.1.15", "H:\\Downloads\\", "/data/torrents-ext/1/") in pairs)
    check("other hosts' mappings untouched", ("nas.lan", "/volume1/dl/", "/data/nas/") in pairs)
    check("no warning when the folder is visible", not warnings, "; ".join(warnings))

    tb.configure_remote_paths("radarr", radarr)
    check("running again changes nothing", len(radarr.maps) == 2)

    radarr.visible = set()
    tb.configure_remote_paths("radarr", radarr)
    check("warns when the mounted folder is not visible", any("not visible" in w for w in warnings))

    tb.STATE["torrent_client"] = "qbittorrent"
    before = len(radarr.maps)
    tb.configure_remote_paths("radarr", radarr)
    check("in-stack qBittorrent: mappings left alone", len(radarr.maps) == before)

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
