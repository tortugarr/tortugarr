"""The folder Seerr adds requests to. Replays 2026-10-21: Seerr's answer has no free space,
so H:\\-=MOVIES=- (11 GB free, most titles) won over E:\\-=MOVIES=- (50 GB free); and
E:\\-=Dokumentarer=- shares E: with E:\\-=MOVIES=-, which has more titles.
    python3 -I tests/unit/test_seerr_root.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

GB = 1 << 30
FREE = {"/data/media/movies": 944 * GB, "/data/library/2": 50 * GB + 5, "/data/library/3": 50 * GB,
        "/data/library/6": 11 * GB, "/data/library/7": 11 * GB}
TITLES = {"/data/library/2": 10, "/data/library/3": 45, "/data/library/6": 22, "/data/library/7": 68}


def main():
    tb.new_title_roots = lambda app: ["/data/library/2", "/data/library/3", "/data/library/6", "/data/library/7"]
    tb.arr_free_per_root = lambda app: FREE
    tb.arr_titles_per_root = lambda app: TITLES
    roots = [{"id": i, "path": p} for i, p in enumerate(FREE)]
    got = tb.seerr_root("radarr", roots)["path"]
    ok = got == "/data/library/3"
    print(("ok   " if ok else "FAIL ") + f"E:\\-=MOVIES=- chosen: roomiest drive, then most titles ({got})")
    tb.arr_free_per_root = lambda app: {}
    got = tb.seerr_root("radarr", [{"id": 1, "path": "/data/library/2", "freeSpace": 5 * GB},
                                   {"id": 2, "path": "/data/library/6", "freeSpace": 9 * GB}])["path"]
    ok2 = got == "/data/library/6"
    print(("ok   " if ok2 else "FAIL ") + f"without Radarr's figures Seerr's own are used ({got})")
    print("all passed" if ok and ok2 else "failed")
    sys.exit(0 if ok and ok2 else 1)


if __name__ == "__main__":
    main()
