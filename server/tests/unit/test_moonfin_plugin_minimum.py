"""The Moonfin plugin is kept at a minimum version or newer, with auto-update on.
Earlier releases pinned one exact version (2.0.2.0) with auto-update off; an update must
undo that. Works on a temporary plugins folder; nothing else is touched.
    python3 -I tests/unit/test_moonfin_plugin_minimum.py"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

GUID = "8c5d0e91-4f2a-4b6d-9e3f-1a7c8d9e0f2b"
FAILED = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        FAILED.append(name)


def plugin(root, folder, version, auto_update, guid=GUID):
    d = os.path.join(root, "jellyfin", "plugins", folder)
    os.makedirs(d)
    with open(os.path.join(d, "meta.json"), "w") as f:
        json.dump({"guid": guid, "version": version, "autoUpdate": auto_update, "status": "Active"}, f)
    return d


def main():
    check("version order", tb.plugin_version_tuple("2.10.0.0") > tb.plugin_version_tuple("2.4.0.0"))
    check("junk sorts lowest", tb.plugin_version_tuple("x") < tb.plugin_version_tuple("0.0.0.1"))

    with tempfile.TemporaryDirectory() as root:
        tb.CFG = root
        tb.chown_tree = lambda path: None
        tb.STATE.clear()
        tb.STATE.update({"moonfin_plugin_guid": GUID, "moonfin_plugin_version": "2.4.0.0",
                         "moonfin_plugin_min_version": "2.4.0.0"})
        old = plugin(root, "Moonbase_2.0.2.0", "2.0.2.0", False)
        cur = plugin(root, "Moonbase_2.4.0.0", "2.4.0.0", False)
        newer = plugin(root, "Moonbase_2.5.0.0", "2.5.0.0", True)
        other = plugin(root, "Other_1.0.0.0", "1.0.0.0", False, guid="11111111-2222-3333-4444-555555555555")

        check("restart needed after changes", tb.jellyfin_plugin_pin() is True)
        check("old pinned version removed", not os.path.exists(old))
        check("minimum version kept", os.path.exists(cur))
        check("newer version kept", os.path.exists(newer))
        with open(os.path.join(cur, "meta.json")) as f:
            check("auto-update switched back on", json.load(f)["autoUpdate"] is True)
        with open(os.path.join(other, "meta.json")) as f:
            check("other plugins untouched", json.load(f)["autoUpdate"] is False)
        check("nothing left to change", tb.jellyfin_plugin_pin() is False)

        # Upgrading from the pinned 2.0.2.0: the new version must be installed, not skipped.
        class FakeJellyfin:
            def __init__(self, plugins):
                self.plugins, self.posts = plugins, []

            def get(self, path):
                return {"/Plugins": self.plugins, "/Repositories": [{"Url": tb.STATE["moonfin_plugin_repo"]}]}[path]

            def post(self, path, body=None):
                self.posts.append(path)

        tb.STATE["moonfin_plugin_repo"] = "https://example.invalid/manifest.json"
        jf = FakeJellyfin([{"Id": GUID, "Version": "2.0.2.0", "Status": "Active"}])
        check("pinned 2.0.2.0 present: restart needed", tb.jellyfin_plugin(jf) is True)
        check("pinned 2.0.2.0 present: 2.4.0.0 gets installed",
              any(p.startswith("/Packages/Installed/Moonbase?") and "version=2.4.0.0" in p for p in jf.posts), jf.posts)
        jf = FakeJellyfin([{"Id": GUID, "Version": "2.5.0.0", "Status": "Active"}])
        check("newer version active: nothing to do", tb.jellyfin_plugin(jf) is False and not jf.posts)
        jf = FakeJellyfin([{"Id": GUID, "Version": "2.4.0.0", "Status": "Restart"}])
        check("installed but not loaded yet: just a restart", tb.jellyfin_plugin(jf) is True and not jf.posts)

        # A state.json written by an older release has no minimum: the installed version is it.
        tb.STATE.pop("moonfin_plugin_min_version")
        check("falls back to the release version", tb.moonfin_plugin_min_version() == "2.4.0.0")

    print("all passed" if not FAILED else f"{len(FAILED)} failed")
    sys.exit(1 if FAILED else 0)


if __name__ == "__main__":
    main()
