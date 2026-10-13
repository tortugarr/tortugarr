"""Jellyfin that is slow to start (Win11 VM, 2026-10-07): /health says 200 while /Startup/*
still answers 503. A fake Jellyfin on localhost; nothing else is contacted.
    python3 -I tests/unit/test_jellyfin_start.py"""
import http.server
import json
import os
import sys
import threading
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bootstrap"))
import tortugarr_bootstrap as tb  # noqa: E402

T0 = time.time()
CALLS = []
CFG = {"ready_after": 4.0, "flaky_user_posts": 1, "wizard_done": False}


class FakeJellyfin(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def answer(self, code, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self, method):
        n = int(self.headers.get("Content-Length") or 0)
        if n:
            self.rfile.read(n)
        CALLS.append((round(time.time() - T0, 1), method, self.path))
        starting = time.time() - T0 < CFG["ready_after"]
        if self.path == "/health":
            return self.answer(200)
        if self.path == "/System/Info/Public":
            return self.answer(200, {"StartupWizardCompleted": CFG["wizard_done"]})
        if self.path.startswith("/Startup/"):
            if starting:
                return self.answer(503)
            if method == "POST" and self.path == "/Startup/User" and CFG["flaky_user_posts"] > 0:
                CFG["flaky_user_posts"] -= 1
                return self.answer(503)
            if self.path == "/Startup/Complete":
                CFG["wizard_done"] = True
            return self.answer(200, {} if method == "GET" else None)
        return self.answer(404)

    def do_GET(self):
        self.handle_any("GET")

    def do_POST(self):
        self.handle_any("POST")


def main():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FakeJellyfin)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    tb.jellyfin_base = lambda: f"http://127.0.0.1:{srv.server_port}"
    tb.SECRETS.update({"admin_user": "admin", "admin_password": "pw"})
    fails = 0

    def check(name, cond, detail=""):
        nonlocal fails
        print(("  PASS  " if cond else "  FAIL  ") + name + ("" if cond else f"  {detail}"))
        fails += 0 if cond else 1

    print("Slow start: /health 200 at once, /Startup/* 503 for 4 s, one more 503 on POST /Startup/User")
    tb.jellyfin_startup()
    posts = [c for c in CALLS if c[1] == "POST"]
    check("wizard completed", CFG["wizard_done"])
    check("no wizard POST while Jellyfin was starting", all(c[0] >= CFG["ready_after"] for c in posts), posts)
    check("POST /Startup/User was retried after its 503", sum(1 for c in posts if c[2] == "/Startup/User") == 2, posts)

    print("Never ready: a clear error after the timeout")
    CALLS.clear(); CFG.update({"ready_after": 1e9, "wizard_done": False})
    t = time.time()
    try:
        tb.jellyfin_wait_ready(timeout=5)
        check("raises", False)
    except tb.BootstrapError as e:
        check("raises BootstrapError naming the last answer", "within 5s" in str(e) and "HTTP 503" in str(e), str(e))
    check("gives up near the timeout", 5 <= time.time() - t < 12, time.time() - t)

    print("Dependent steps are skipped when Jellyfin fails")
    ran = []

    def boom():
        raise tb.BootstrapError("POST /Startup/Configuration -> HTTP 503")
    for name in ("configure_jellyfin", "configure_seerr", "configure_tortugarr_seerr", "configure_moonfin_webhook",
                 "configure_prowlarr", "configure_bazarr", "write_app_config", "configure_qbittorrent"):
        setattr(tb, name, boom if name == "configure_jellyfin" else (lambda n=name: ran.append(n)))
    tb.configure_arr = lambda app: ran.append(app)
    tb.STATE.update({"torrent_client": "qbittorrent", "usenet": False})
    out = []
    tb.out = lambda level, msg: out.append(msg)
    rc = tb.cmd_configure()
    text = "\n".join(out)
    check("exit 1", rc == 1)
    check("seerr, tortugarr-seerr, moonfin-webhook not run", not {"configure_seerr", "configure_tortugarr_seerr", "configure_moonfin_webhook"} & set(ran), ran)
    check("independent steps still ran", {"sonarr", "radarr", "configure_prowlarr", "configure_bazarr", "write_app_config"} <= set(ran), ran)
    check("each says 'skipped: Jellyfin setup failed'", text.count("skipped: Jellyfin setup failed") == 3, text)
    check("summary: 1 failed, 3 skipped", "1 failed step(s), 3 skipped" in text, text)
    srv.shutdown()
    print(f"{'FAILED' if fails else 'all passed'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
