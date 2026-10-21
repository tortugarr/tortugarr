#!/usr/bin/env python3
"""Tortugarr configuration engine.

Runs inside a throwaway python container on the `tortugarr` Docker network, so the
host needs nothing but Docker. install.sh calls it with one of these commands:

  preseed    write first-start config files (API keys, ports, passwords) BEFORE
             the containers start for the first time
  configure  wire every service together through its own API; idempotent, so
             `repair` simply runs it again
  doctor     API-level health checks; prints one line per check
  backup-db  consistent online snapshots of every SQLite database
  summary    print URLs and credentials

Mounts (set up by install.sh):
  /tortugarr   the install directory (state.json, secrets.json, backups/)
  /cfg       the config root (one directory per service)

Only the Python standard library is used.
"""

import base64
import hashlib
import http.cookiejar
import json
import os
import re
import secrets
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET

INSTALL = "/tortugarr"
CFG = "/cfg"

# Release titles we never want: cinema recordings and friends, plus executables
# disguised as video. Kept in one place so Sonarr and Radarr get the same filter.
JUNK_RELEASE_REGEX = (
    r"/\b(HD-?CAM|CAM-?RIP|HQ-?CAM|CAM|HD-?TS|TS-?RIP|TELESYNC|PDVD|HD-?TC|"
    r"TELECINE|DVD-?SCR|SCREENER|WORKPRINT|TS|TC|exe|scr|lnk|msi)\b/i"
)
JUNK_RELEASE_PROFILE = "Tortugarr: block cam/telesync and executables"
# Radarr quality names that are never acceptable.
JUNK_QUALITIES = {"WORKPRINT", "CAM", "TELESYNC", "TELECINE", "REGIONAL", "DVDSCR", "BR-DISK"}
# File names the torrent client refuses to download at all (qBittorrent only).
BLOCKED_FILE_PATTERNS = ["*.exe", "*.scr", "*.lnk", "*.msi", "*.bat", "*.cmd", "*.com",
                         "*.pif", "*.vbs", "*.js", "*.jar", "*.zipx", "*.arj"]


# Seerr -> Moonfin plugin webhook: the plugin's own path, event mask and payload template
# (Moonfin plugin SeerrProvisioningService, unchanged from 2.0.2 to 2.4.0). Kept identical, so the plugin sees the
# webhook as its own and leaves it alone.
MOONFIN_WEBHOOK_PATH = "/Moonfin/Seerr/Webhook"
MOONFIN_WEBHOOK_TYPES = 3918  # pending, approved, available, declined, and the four issue events
MOONFIN_WEBHOOK_PAYLOAD = """{
    "notification_type": "{{notification_type}}",
    "subject": "{{subject}}",
    "message": "{{message}}",
    "notifyuser_username": "{{notifyuser_username}}",
    "{{media}}": {
        "media_type": "{{media_type}}",
        "tmdbId": "{{media_tmdbid}}",
        "tvdbId": "{{media_tvdbid}}",
        "status": "{{media_status}}"
    },
    "{{request}}": {
        "request_id": "{{request_id}}",
        "requestedBy_username": "{{requestedBy_username}}",
        "requestedBy_jellyfinUserId": "{{requestedBy_jellyfinUserId}}"
    },
    "{{issue}}": {
        "issue_id": "{{issue_id}}",
        "issue_type": "{{issue_type}}",
        "issue_status": "{{issue_status}}",
        "reportedBy_username": "{{reportedBy_username}}"
    },
    "{{comment}}": {
        "comment_message": "{{comment_message}}",
        "commentedBy_username": "{{commentedBy_username}}"
    },
    "{{extra}}": []
}"""


# --------------------------------------------------------------------------- output

def out(level, msg):
    """One line per event: LEVEL<TAB>message. install.sh colours and translates LEVEL."""
    print(f"{level}\t{msg}", flush=True)


def ok(msg):
    out("OK", msg)


def info(msg):
    out("INFO", msg)


def warn(msg):
    out("WARN", msg)


CLOUDFLARE_TIP = ("Indexer test fails with a Cloudflare or 403 error (1337x and others)? Type flaresolverr under Tags at the bottom of its settings and press Test again")


def important(msg):
    """Shown in its own colour by the installer: advice that must not be missed."""
    out("IMPORTANT", msg)


def fail(msg):
    out("FAIL", msg)


class BootstrapError(Exception):
    pass


# --------------------------------------------------------------------------- state

def load_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        if default is not None:
            return default
        raise BootstrapError(f"missing {path}")


def save_json(path, data, mode=0o600):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


STATE = {}
SECRETS = {}


def load_state():
    global STATE, SECRETS
    STATE = load_json(f"{INSTALL}/state.json")
    SECRETS = load_json(f"{INSTALL}/secrets.json", {})


def secret(key, factory=None):
    """Return a stored secret, creating and persisting it on first use."""
    if key not in SECRETS or not SECRETS[key]:
        if factory is None:
            raise BootstrapError(f"secret {key} is not set")
        SECRETS[key] = factory()
        save_json(f"{INSTALL}/secrets.json", SECRETS)
    return SECRETS[key]


def api_key():
    return uuid.uuid4().hex


def chown_tree(path):
    uid, gid = int(STATE["puid"]), int(STATE["pgid"])
    for root, dirs, files in os.walk(path):
        for n in [root] + [os.path.join(root, d) for d in dirs] + [os.path.join(root, f) for f in files]:
            try:
                os.chown(n, uid, gid)
            except OSError:
                pass


# --------------------------------------------------------------------------- http

class Http:
    """Small JSON HTTP client with an optional cookie jar and default headers."""

    def __init__(self, base, headers=None, cookies=False, timeout=30):
        self.base = base.rstrip("/")
        self.headers = headers or {}
        self.timeout = timeout
        handlers = []
        if cookies:
            self.jar = http.cookiejar.CookieJar()
            handlers.append(urllib.request.HTTPCookieProcessor(self.jar))
        self.opener = urllib.request.build_opener(*handlers)

    def request(self, method, path, body=None, form=None, headers=None, raw=False, ok_status=(200, 201, 202, 204),
                retry_unavailable=0):
        """retry_unavailable: for that many seconds, try again on HTTP 503 or a refused
        connection - a service that is still starting. Both mean the request was not handled,
        so a POST is safe to repeat."""
        deadline = time.time() + retry_unavailable
        while True:
            try:
                return self._request_once(method, path, body, form, headers, raw, ok_status)
            except (BootstrapError, urllib.error.URLError) as e:
                unavailable = (getattr(e, "status", None) == 503 or
                               isinstance(getattr(e, "reason", None), ConnectionRefusedError))
                if not unavailable or time.time() >= deadline:
                    raise
                time.sleep(3)

    def _request_once(self, method, path, body, form, headers, raw, ok_status):
        url = path if path.startswith("http") else self.base + path
        hdrs = dict(self.headers)
        hdrs.update(headers or {})
        data = None
        if form is not None:
            data = urllib.parse.urlencode(form).encode()
            hdrs.setdefault("Content-Type", "application/x-www-form-urlencoded")
        elif body is not None:
            data = json.dumps(body).encode()
            hdrs.setdefault("Content-Type", "application/json")
        req = urllib.request.Request(url, data=data, method=method, headers=hdrs)
        try:
            with self.opener.open(req, timeout=self.timeout) as r:
                payload = r.read()
                status = r.status
        except urllib.error.HTTPError as e:
            payload = e.read()
            status = e.code
        if status not in ok_status:
            text = payload.decode(errors="replace")[:400]
            err = BootstrapError(f"{method} {url} -> HTTP {status}: {text}")
            err.status = status
            raise err
        if raw:
            return payload
        if not payload:
            return None
        try:
            return json.loads(payload)
        except ValueError:
            return payload.decode(errors="replace")

    def get(self, path, **kw):
        return self.request("GET", path, **kw)

    def post(self, path, body=None, **kw):
        return self.request("POST", path, body=body, **kw)

    def put(self, path, body=None, **kw):
        return self.request("PUT", path, body=body, **kw)

    def delete(self, path, **kw):
        return self.request("DELETE", path, **kw)


def wait_http(name, url, timeout=300, accept=(200, 204, 301, 302, 307, 401, 403)):
    """Wait until a service answers anything HTTP-ish."""
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=5) as r:
                if r.status in accept:
                    return True
        except urllib.error.HTTPError as e:
            if e.code in accept:
                return True
            last = f"HTTP {e.code}"
        except Exception as e:  # noqa: BLE001 - any connection error means "not yet"
            last = str(e)
        time.sleep(3)
    raise BootstrapError(f"{name} did not come up at {url} within {timeout}s ({last})")


# --------------------------------------------------------------------------- service topology

def torrent_client():
    return STATE.get("torrent_client", "qbittorrent")


def client_kind():
    """The client's software. qbittorrent-ext is a qBittorrent outside the stack (on the
    Windows host, a NAS, ...), reached by address instead of as a container."""
    client = torrent_client()
    return "qbittorrent" if client == "qbittorrent-ext" else client


def external_qbit():
    return STATE.get("external_qbit") or {}


def url_parts(url):
    """http://192.168.1.15:8070/qbt -> ("192.168.1.15", 8070, False, "/qbt")."""
    u = urllib.parse.urlsplit(url)
    ssl = u.scheme == "https"
    return u.hostname or "", u.port or (443 if ssl else 80), ssl, u.path.rstrip("/")


def download_client_url():
    """Where the plugin and the app's private build reach the torrent client."""
    client = torrent_client()
    if client == "none":
        return ""
    if client == "qbittorrent-ext":
        return external_qbit().get("url", "")
    return f"http://{client_host(client)}:{CLIENT_INTERNAL_PORT[client]}"


def download_client_login():
    if torrent_client() == "qbittorrent-ext":
        return external_qbit().get("username", ""), SECRETS.get("external_qbit_password", "")
    return SECRETS["admin_user"], SECRETS["admin_password"]


def client_host(service):
    """Container-to-container host name. Behind the VPN every client lives in gluetun's netns."""
    if STATE.get("vpn") and service in ("qbittorrent", "transmission", "deluge"):
        return "gluetun"
    return service


# Download-client category per app, and the folder under torrents/ (or usenet/complete/)
# it saves to. The Tortugarr app looks downloads up by these category names, which are
# also what Sonarr/Radarr suggest themselves.
CATEGORY = {"sonarr": "sonarr", "radarr": "radarr", "prowlarr": "prowlarr"}
CATEGORY_DIR = {"sonarr": "tv", "radarr": "movies", "prowlarr": "prowlarr"}

CLIENT_INTERNAL_PORT = {"qbittorrent": 8080, "transmission": 9091, "deluge": 8112, "sabnzbd": 8080}
ARR_PORT = {"sonarr": 8989, "radarr": 7878, "prowlarr": 9696}


def lan_url(port_key):
    return f"http://{STATE['lan_ip']}:{STATE['ports'][port_key]}"


# --------------------------------------------------------------------------- preseed

ARR_CONFIG_TEMPLATE = """<Config>
  <BindAddress>*</BindAddress>
  <Port>{port}</Port>
  <SslPort>{ssl_port}</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>{api_key}</ApiKey>
  <AuthenticationMethod>Forms</AuthenticationMethod>
  <AuthenticationRequired>Enabled</AuthenticationRequired>
  <Branch>{branch}</Branch>
  <LogLevel>info</LogLevel>
  <UrlBase></UrlBase>
  <InstanceName>{name}</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
  <AnalyticsEnabled>False</AnalyticsEnabled>
</Config>
"""


def preseed_arr(name, port, ssl_port, branch):
    d = f"{CFG}/{name}"
    os.makedirs(d, exist_ok=True)
    path = f"{d}/config.xml"
    key = secret(f"{name}_api_key", api_key)
    if os.path.exists(path):
        # Keep whatever the service wrote, but make sure the key matches our records.
        tree = ET.parse(path)
        root = tree.getroot()
        node = root.find("ApiKey")
        if node is None:
            node = ET.SubElement(root, "ApiKey")
        if node.text != key:
            node.text = key
            tree.write(path)
            info(f"{name}: API key in config.xml re-aligned with secrets.json")
    else:
        with open(path, "w") as f:
            f.write(ARR_CONFIG_TEMPLATE.format(port=port, ssl_port=ssl_port, api_key=key,
                                               branch=branch, name=name.capitalize()))
        ok(f"{name}: config.xml written")
    chown_tree(d)


def qbittorrent_pbkdf2(password):
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000, dklen=64)
    return f"@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(dk).decode()})"


def preseed_qbittorrent():
    d = f"{CFG}/qbittorrent/qBittorrent"
    os.makedirs(d, exist_ok=True)
    path = f"{d}/qBittorrent.conf"
    if os.path.exists(path):
        info("qbittorrent: config exists, password left untouched (configure verifies it)")
        return
    user = SECRETS["admin_user"]
    pw = SECRETS["admin_password"]
    with open(path, "w") as f:
        f.write(
            "[LegalNotice]\nAccepted=true\n\n"
            "[BitTorrent]\n"
            "Session\\DefaultSavePath=/data/torrents\n"
            "Session\\TempPathEnabled=false\n"
            f"Session\\Port={STATE['ports']['torrent_peer']}\n\n"
            "[Preferences]\n"
            "WebUI\\Enabled=true\n"
            "WebUI\\Port=8080\n"
            f"WebUI\\Username={user}\n"
            f"WebUI\\Password_PBKDF2=\"{qbittorrent_pbkdf2(pw)}\"\n"
            "WebUI\\HostHeaderValidation=false\n"
            "WebUI\\LocalHostAuth=true\n"
            "General\\Locale=en\n"
        )
    chown_tree(f"{CFG}/qbittorrent")
    ok("qbittorrent: config written with the admin password")


def preseed_sabnzbd():
    d = f"{CFG}/sabnzbd"
    os.makedirs(d, exist_ok=True)
    path = f"{d}/sabnzbd.ini"
    if os.path.exists(path):
        info("sabnzbd: config exists, left untouched")
        return
    key = secret("sabnzbd_api_key", api_key)
    nzb_key = secret("sabnzbd_nzb_key", api_key)
    with open(path, "w") as f:
        f.write(
            "__version__ = 19\n__encoding__ = utf-8\n[misc]\n"
            f"api_key = {key}\nnzb_key = {nzb_key}\n"
            f"username = {SECRETS['admin_user']}\npassword = {SECRETS['admin_password']}\n"
            f"host_whitelist = sabnzbd, tortugarr-sabnzbd, {STATE['lan_ip']}\n"
            "download_dir = /data/usenet/incomplete\ncomplete_dir = /data/usenet/complete\n"
            "permissions = 775\n"
            "[categories]\n"
            "[[*]]\nname = *\norder = 0\npp = 3\nscript = None\ndir = \"\"\npriority = 0\n"
            "[[sonarr]]\nname = sonarr\norder = 1\npp = \"\"\nscript = Default\ndir = tv\npriority = -100\n"
            "[[radarr]]\nname = radarr\norder = 2\npp = \"\"\nscript = Default\ndir = movies\npriority = -100\n"
            "[[prowlarr]]\nname = prowlarr\norder = 3\npp = \"\"\nscript = Default\ndir = prowlarr\npriority = -100\n"
        )
    chown_tree(d)
    ok("sabnzbd: config written")


def preseed_bazarr():
    """Bazarr makes its own config.yaml on first start; seed only the API key, so the
    engine can talk to it right away. Everything else is set through its API."""
    d = f"{CFG}/bazarr/config"
    os.makedirs(d, exist_ok=True)
    key = secret("bazarr_api_key", api_key)
    path = f"{d}/config.yaml"
    if not os.path.exists(path):
        with open(path, "w") as f:
            f.write(f"auth:\n  apikey: {key}\n")
        ok("bazarr: API key seeded")
    chown_tree(f"{CFG}/bazarr")


# --------------------------------------------------------------------------- Tortugarr plugin

TORTUGARR_PLUGIN_GUID = "19f30fb1bb78444ba75e2997883b215c"


def tortugarr_plugin_dist():
    """The built plugin shipped with the installer: (folder name, path) or None."""
    root = f"{INSTALL}/app/plugin/dist"
    if not os.path.isdir(root):
        return None
    names = sorted(d for d in os.listdir(root) if d.startswith("Tortugarr_"))
    return (names[-1], os.path.join(root, names[-1])) if names else None


def install_tortugarr_plugin():
    """Put the Tortugarr plugin into Jellyfin's plugin folder (exactly one version).
    Returns True when files changed, so a running Jellyfin needs a restart."""
    dist = tortugarr_plugin_dist()
    if not dist:
        warn("jellyfin: Tortugarr plugin not found in the installer - Download Now stays off in the app")
        return False
    import shutil
    name, src = dist
    plugins = f"{CFG}/jellyfin/plugins"
    os.makedirs(plugins, exist_ok=True)
    changed = False
    for d in os.listdir(plugins):
        if d.startswith("Tortugarr_") and d != name:
            shutil.rmtree(os.path.join(plugins, d), ignore_errors=True)
            changed = True
    dst = os.path.join(plugins, name)
    for f in os.listdir(src):
        a, b = os.path.join(src, f), os.path.join(dst, f)
        # Jellyfin rewrites meta.json when it loads the plugin, so only a missing meta.json
        # or a different DLL counts as a change (otherwise every repair restarts Jellyfin).
        same = os.path.exists(b) and (f == "meta.json" or open(a, "rb").read() == open(b, "rb").read())
        if not same:
            os.makedirs(dst, exist_ok=True)
            shutil.copyfile(a, b)
            changed = True
    chown_tree(plugins)
    if changed:
        ok(f"jellyfin: Tortugarr plugin {name.split('_', 1)[1]} installed")
    return changed


TORTUGARR_REPO_URL = "http://127.0.0.1:8096/Tortugarr/v1/Repository/manifest.json"


def windows_path(host_path):
    """/mnt/e/-=XxX=-/ as Windows writes it (E:\\-=XxX=-); None for a path not on a Windows drive."""
    m = re.match(r"^/mnt/([a-z])(/.*)?$", host_path.rstrip("/"))
    return m and f"{m.group(1).upper()}:" + (m.group(2) or "\\").replace("/", "\\")


def adult_download_path():
    """Where a qBittorrent outside the stack saves adult downloads: the user's adult folder as it
    sees it, so nothing lands in the Linux disk. Empty for the stack's own qBittorrent, which
    saves to /data/media/adult (the plugin's default)."""
    if torrent_client() != "qbittorrent-ext":
        return ""
    for e in STATE.get("extra_libraries", []):
        if e.get("type") == "adult" and (p := windows_path(e["host_path"])):
            return p
    mounts = external_qbit().get("mounts", [])
    return ext_join(mounts[0]["remote"], "adult") if mounts else ""


def ext_join(root, name):
    sep = "\\" if re.match(r"^[A-Za-z]:", root) else "/"
    return root.rstrip("\\/") + sep + name


def tortugarr_plugin_config(h):
    """The plugin's server-side settings: container addresses and keys. Never sent to the app."""
    client = torrent_client()
    conf = h.get(f"/Plugins/{TORTUGARR_PLUGIN_GUID}/Configuration")
    conf.update({
        "SonarrUrl": "http://sonarr:8989", "SonarrApiKey": secret("sonarr_api_key"),
        "RadarrUrl": "http://radarr:7878", "RadarrApiKey": secret("radarr_api_key"),
        "ProwlarrUrl": "http://prowlarr:9696", "ProwlarrApiKey": secret("prowlarr_api_key"),
        "BazarrUrl": "http://bazarr:6767", "BazarrApiKey": bazarr_key(),
        "DownloadClientType": client_kind(),
        "DownloadClientUrl": download_client_url(),
        "DownloadClientUsername": download_client_login()[0], "DownloadClientPassword": download_client_login()[1],
        "MovieCategory": CATEGORY["radarr"], "TvCategory": CATEGORY["sonarr"],
        # Several download folders (one per drive): the plugin picks the roomiest per grab.
        "DownloadRoots": "\n".join(f"{m['remote']}|{m['container_path']}" for m in external_qbit().get("mounts", [])),
        # New titles only go to root folders of their own type (never a folder not mounted there).
        "MovieRoots": ",".join(new_title_roots("radarr")), "TvRoots": ",".join(new_title_roots("sonarr")),
        # Radarr/Sonarr send this to the refresh hook (plugin spec 3.12) instead of a Jellyfin key.
        "HookKey": secret("tortugarr_hook_key", lambda: os.urandom(32).hex()),
        # The adult library stays as the administrator set it (off by default); only its place is set.
        "AdultCategory": "adult", "AdultSavePath": adult_save_path(), "AdultDownloadPath": adult_download_path(),
    })
    h.post(f"/Plugins/{TORTUGARR_PLUGIN_GUID}/Configuration", conf)
    ok("jellyfin: Tortugarr plugin linked to Sonarr, Radarr, Bazarr and the download client")
    # The plugin serves its own one-entry catalog (plugin spec 3.13); without a repository that
    # lists it, Jellyfin's plugin page shows "error fetching repository details".
    repos = h.get("/Repositories")
    if not any(r.get("Url") == TORTUGARR_REPO_URL for r in repos):
        repos.append({"Name": "Tortugarr", "Url": TORTUGARR_REPO_URL, "Enabled": True})
        h.post("/Repositories", repos)
        ok("jellyfin: Tortugarr plugin catalog added (served by the plugin itself)")


def configure_tortugarr_seerr():
    """Give the Tortugarr plugin Seerr's key, so it can clear a title in Seerr after a delete
    (plugin spec 3.10/3.11). A step of its own: Seerr is set up after Jellyfin, and its key is
    not in secrets.json - it is read from Seerr as the owner. Never sent to the app."""
    if not tortugarr_plugin_dist():
        return
    key = (seerr_login().get("/settings/main") or {}).get("apiKey")
    if not key:
        raise BootstrapError("seerr: /settings/main returned no API key")
    h, _ = jellyfin_login()
    if not any(p.get("Id", "").replace("-", "") == TORTUGARR_PLUGIN_GUID and p.get("Status") == "Active" for p in h.get("/Plugins")):
        warn("jellyfin: the Tortugarr plugin is not active - Seerr link skipped (run repair)")
        return
    conf = h.get(f"/Plugins/{TORTUGARR_PLUGIN_GUID}/Configuration")
    if conf.get("SeerrUrl") != "http://seerr:5055" or conf.get("SeerrApiKey") != key:
        conf.update({"SeerrUrl": "http://seerr:5055", "SeerrApiKey": key})
        h.post(f"/Plugins/{TORTUGARR_PLUGIN_GUID}/Configuration", conf)
    ok("jellyfin: Tortugarr plugin linked to Seerr (clears a title in Seerr after a delete)")


def preseed_jellyfin():
    for d in (f"{CFG}/jellyfin", f"{CFG}/jellyfin-cache"):
        os.makedirs(d, exist_ok=True)
        chown_tree(d)
    install_tortugarr_plugin()


def preseed_seerr():
    d = f"{CFG}/seerr"
    os.makedirs(d, exist_ok=True)
    chown_tree(d)


def cmd_preseed():
    secret("admin_user")
    secret("admin_password")
    preseed_jellyfin()
    preseed_seerr()
    preseed_arr("sonarr", 8989, 9898, "main")
    preseed_arr("radarr", 7878, 9898, "master")
    preseed_arr("prowlarr", 9696, 6969, "master")
    preseed_bazarr()
    if torrent_client() == "qbittorrent":
        preseed_qbittorrent()
    for name in ("transmission", "deluge"):
        if torrent_client() == name:
            os.makedirs(f"{CFG}/{name}", exist_ok=True)
            chown_tree(f"{CFG}/{name}")
    if STATE.get("usenet"):
        preseed_sabnzbd()
    ok("preseed complete")


# --------------------------------------------------------------------------- *arr helpers

def arr(name):
    port = ARR_PORT[name]
    ver = "v1" if name == "prowlarr" else "v3"
    h = Http(f"http://{name}:{port}/api/{ver}", headers={"X-Api-Key": secret(f"{name}_api_key")})
    return h


def wait_arr(name):
    wait_http(name, f"http://{name}:{ARR_PORT[name]}/ping", accept=(200,))
    h = arr(name)
    deadline = time.time() + 180
    while True:
        try:
            h.get("/system/status")
            return h
        except BootstrapError as e:
            if time.time() > deadline:
                raise BootstrapError(f"{name}: API key rejected or API not ready: {e}")
            time.sleep(3)


def fill_fields(fields, values):
    """Set values on an *arr provider `fields` list by field name; unknown names are ignored."""
    for f in fields:
        if f["name"] in values:
            f["value"] = values[f["name"]]
    return fields


def upsert_provider(h, endpoint, name, implementation, values, extra=None, schema_filter=None):
    """Create or update a provider (download client, application, indexer proxy, notification)."""
    existing = [p for p in h.get(endpoint) if p.get("name") == name]
    schema = [s for s in h.get(f"{endpoint}/schema") if s["implementation"] == implementation]
    if schema_filter:
        schema = [s for s in schema if schema_filter(s)]
    if not schema:
        raise BootstrapError(f"{endpoint}: implementation {implementation} not available")
    item = existing[0] if existing else schema[0]
    item = dict(item)
    item["name"] = name
    item["fields"] = fill_fields(item["fields"], values)
    item.update(extra(item) if callable(extra) else (extra or {}))
    if existing:
        h.put(f"{endpoint}/{item['id']}?forceSave=true", item)
        return "updated"
    h.post(f"{endpoint}?forceSave=true", item)
    return "created"


def set_arr_auth(name, h):
    host = h.get("/config/host")
    user = SECRETS["admin_user"]
    changed = (host.get("username") != user or host.get("authenticationMethod") != "forms"
               or host.get("authenticationRequired") != "enabled")
    host.update({
        "authenticationMethod": "forms",
        "authenticationRequired": "enabled",
        "username": user,
        "password": SECRETS["admin_password"],
        "passwordConfirmation": SECRETS["admin_password"],
        "analyticsEnabled": False,
    })
    h.put(f"/config/host/{host['id']}", host)
    ok(f"{name}: login set to {user} ({'changed' if changed else 'verified'})")


def ensure_root_folder(name, h, path):
    folders = h.get("/rootfolder")
    if any(f["path"].rstrip("/") == path.rstrip("/") for f in folders):
        return
    h.post("/rootfolder", {"path": path})
    ok(f"{name}: root folder {path}")


def quality_profile_id(h):
    want = STATE.get("default_quality_profile", "HD-1080p")
    profiles = h.get("/qualityprofile")
    return next((p["id"] for p in profiles if p["name"] == want), profiles[0]["id"])


def import_existing(app, h, root):
    """Register the titles that already sit in an existing media folder, so Sonarr/Radarr
    know them (and don't fetch them again). They are added unmonitored: nothing is
    downloaded or upgraded for them unless the user switches monitoring on."""
    folder = next((f for f in h.get("/rootfolder") if f["path"].rstrip("/") == root.rstrip("/")), None)
    unmapped = (folder or {}).get("unmappedFolders") or []
    if not unmapped:
        return
    profile = quality_profile_id(h)
    added, missed, copies, linked, adopted = [], [], [], [], set()
    for u in unmapped:
        name = u["name"]
        m = re.match(r"^(.*?)\s*\((\d{4})\)", name)
        title, year = (m.group(1), int(m.group(2))) if m else (name, None)
        kind = "movie" if app == "radarr" else "series"
        try:
            found = h.get(f"/{kind}/lookup?term={urllib.parse.quote(title)}")
        except BootstrapError:
            found = []
        pick = next((r for r in found if year and r.get("year") == year), found[0] if found else None)
        if not pick:
            missed.append(name)
            continue
        if pick.get("id"):
            # Lookup gives the library id of a title Radarr/Sonarr has already. Without files there
            # (a request whose download was moved here by hand) it takes this folder; with files
            # this is a second copy.
            lib = h.get(f"/{kind}/{pick['id']}")
            if title_has_files(lib) or lib["id"] in adopted:
                copies.append(f"{name} (also in {lib.get('path', '?')})")
                continue
            h.put(f"/{kind}/{lib['id']}?moveFiles=false", dict(lib, path=u["path"], rootFolderPath=root))
            if app == "radarr":
                h.post("/command", {"name": "RefreshMovie", "movieIds": [lib["id"]]})
            else:
                h.post("/command", {"name": "RefreshSeries", "seriesIds": [lib["id"]]})
            adopted.add(lib["id"])
            linked.append(name)
            continue
        body = dict(pick)
        body.update({"qualityProfileId": profile, "path": u["path"], "rootFolderPath": root, "monitored": False})
        if app == "radarr":
            body.update({"minimumAvailability": "released",
                         "addOptions": {"searchForMovie": False, "monitor": "none"}})
        else:
            body.update({"seasonFolder": True,
                         "addOptions": {"monitor": "none", "searchForMissingEpisodes": False,
                                        "searchForCutoffUnmetEpisodes": False}})
        try:
            h.post(f"/{kind}", body)
            added.append(name)
        except BootstrapError as e:
            m = re.search(r'"errorMessage":\s*"([^"]+)"', str(e))
            missed.append(f"{name} ({m.group(1) if m else str(e)[-80:]})")
    if added:
        ok(f"{app}: {len(added)} existing title(s) in {root} registered (unmonitored)")
    if missed:
        warn(f"{app}: not recognised in {root}: {'; '.join(missed)} - add them in {app.capitalize()} > Library Import")
    if linked:
        ok(f"{app}: {len(linked)} wanted title(s) found in {root} and pointed there: {'; '.join(linked)}")
    if copies:
        info(f"{app}: second copies in {root}, left alone: {'; '.join(copies)} - delete the copy you do not want")


def download_client_values(app, client):
    """Field values for a Sonarr/Radarr/Prowlarr download client, per client type."""
    category = CATEGORY[app]
    cat_field = {"sonarr": "tvCategory", "radarr": "movieCategory", "prowlarr": "category"}[app]
    if client == "qbittorrent-ext":
        host, port, ssl, base = url_parts(external_qbit()["url"])
        user, pw = download_client_login()
        return {"host": host, "port": port, "useSsl": ssl, "urlBase": base,
                "username": user, "password": pw, cat_field: category}
    host = client_host(client)
    port = CLIENT_INTERNAL_PORT[client]
    user, pw = SECRETS["admin_user"], SECRETS["admin_password"]
    category = CATEGORY[app]
    cat_field = {"sonarr": "tvCategory", "radarr": "movieCategory", "prowlarr": "category"}[app]
    v = {"host": host, "port": port, "useSsl": False}
    if client == "qbittorrent":
        v.update({"username": user, "password": pw, cat_field: category})
    elif client == "transmission":
        # Transmission has no categories; the *arrs emulate them as a sub-folder of
        # the download dir. Category and Directory are mutually exclusive, so the
        # directory field is cleared explicitly.
        v.update({"username": user, "password": pw, "urlBase": "/transmission/", cat_field: category,
                  {"sonarr": "tvDirectory", "radarr": "movieDirectory", "prowlarr": "directory"}[app]: ""})
    elif client == "deluge":
        v.update({"password": pw, "urlBase": "", cat_field: category})
    elif client == "sabnzbd":
        v.update({"apiKey": secret("sabnzbd_api_key"), "username": user, "password": pw, cat_field: category})
    return v


CLIENT_IMPL = {"qbittorrent": "QBittorrent", "qbittorrent-ext": "QBittorrent", "transmission": "Transmission",
               "deluge": "Deluge", "sabnzbd": "Sabnzbd"}


def configure_download_clients(app, h):
    wanted = []
    if torrent_client() != "none":
        wanted.append(torrent_client())
    if STATE.get("usenet"):
        wanted.append("sabnzbd")
    have = h.get("/downloadclient")
    for client in wanted:
        values = download_client_values(app, client)
        name = CLIENT_IMPL[client]
        # A client of the same kind added by hand as "qBittorrent" is taken over, not doubled.
        name = next((p["name"] for p in have if p.get("implementation") == CLIENT_IMPL[client]
                     and p.get("name", "").lower() == name.lower()), name)
        res = upsert_provider(h, "/downloadclient", name, CLIENT_IMPL[client], values,
                              extra={"enable": True, "priority": 1})
        ok(f"{app}: download client {name} {res}")
        if client == "qbittorrent-ext" and app != "prowlarr":
            mine = next(p for p in h.get("/downloadclient") if p["name"] == name)
            try:
                h.post("/downloadclient/test", mine)
                ok(f"{app}: reaches the qBittorrent at {external_qbit().get('url')}")
            except BootstrapError as e:
                warn(f"{app}: cannot reach the qBittorrent at {external_qbit().get('url')} ({str(e)[-160:]}). "
                     "In qBittorrent, give the installer its user name and password, or allow Docker in: "
                     "Web UI > Bypass authentication for clients in whitelisted IP subnets: 172.16.0.0/12")
    # Remove clients this installer created earlier but which are no longer selected
    # (the user switched torrent client with `reconfigure`).
    for p in h.get("/downloadclient"):
        if p["name"] in CLIENT_IMPL.values() and p["name"] not in [CLIENT_IMPL[c] for c in wanted]:
            h.delete(f"/downloadclient/{p['id']}")
            ok(f"{app}: removed download client {p['name']} (no longer selected)")


def configure_remote_paths(app, h):
    """A qBittorrent outside the stack reports its own paths (H:\\Downloads\\radarr\\...). Map
    them to the folders mounted into Sonarr/Radarr, drop older mappings for that host that point
    elsewhere (the *arrs use the most specific one, so a stale one would win), and check the
    container can see each mounted folder."""
    if torrent_client() != "qbittorrent-ext":
        return
    host = url_parts(external_qbit()["url"])[0]
    mounts = external_qbit().get("mounts", [])
    for m in mounts:
        remote, local = m["remote"], m["container_path"].rstrip("/") + "/"
        for p in h.get("/remotepathmapping"):
            if p["host"].lower() != host.lower():
                continue
            under = p["remotePath"].lower().startswith(remote.lower())
            if under and not (p["remotePath"].lower() == remote.lower() and p["localPath"] == local):
                # A deeper mapping is right only when it lands on the same sub-folder
                # (E:\Downloads\radarr\ -> .../2/radarr/). One left from a mount of the
                # category folder itself (E:\Downloads\radarr\ -> .../2/, 2026-10-21) won
                # as the most specific and sent every import to the wrong folder.
                rest = p["remotePath"][len(remote):].replace("\\", "/").strip("/")
                if p["localPath"].rstrip("/") == (local + rest).rstrip("/"):
                    continue
                h.delete(f"/remotepathmapping/{p['id']}")
                ok(f"{app}: removed path mapping {p['remotePath']} -> {p['localPath']} (not in the mounted folder)")
        if not any(p["host"].lower() == host.lower() and p["remotePath"].lower() == remote.lower()
                   for p in h.get("/remotepathmapping")):
            h.post("/remotepathmapping", {"host": host, "remotePath": remote, "localPath": local})
        ok(f"{app}: {remote} on {host} -> {local}")
        listing = h.get(f"/filesystem?path={urllib.parse.quote(local)}&includeFiles=false"
                        f"&allowFoldersWithoutTrailingSlashes=true")
        parent = h.get(f"/filesystem?path={urllib.parse.quote(local.rstrip('/').rsplit('/', 1)[0] + '/')}"
                       f"&includeFiles=false&allowFoldersWithoutTrailingSlashes=true")
        if not any(d.get("path", "").rstrip("/") == local.rstrip("/") for d in parent.get("directories", [])):
            warn(f"{app}: {local} is not visible inside {app} - downloads from {remote} cannot be imported. "
                 f"Check that {m['host_path']} exists on this machine, then run: sudo tortugarr repair")
        else:
            seen = ", ".join(d.get("name", "") for d in listing.get("directories", [])[:6])
            ok(f"{app}: sees {local}" + (f" ({seen})" if seen else ""))


def configure_quality(app, h):
    """Never accept cam/telesync/screener/disc-image qualities, in any profile."""
    for prof in h.get("/qualityprofile"):
        changed = False

        def walk(items):
            nonlocal changed
            for it in items:
                qname = (it.get("quality") or {}).get("name") or it.get("name")
                if qname in JUNK_QUALITIES and it.get("allowed"):
                    it["allowed"] = False
                    changed = True
                if it.get("items"):
                    walk(it["items"])

        walk(prof["items"])
        if changed:
            h.put(f"/qualityprofile/{prof['id']}", prof)
            ok(f"{app}: profile '{prof['name']}' no longer accepts cam/telesync/screener/BR-DISK")


def configure_release_filter(app, h):
    profiles = h.get("/releaseprofile")
    body = {"name": JUNK_RELEASE_PROFILE, "enabled": True, "required": [],
            "ignored": [JUNK_RELEASE_REGEX], "indexerId": 0, "tags": []}
    mine = [p for p in profiles if p.get("name") == JUNK_RELEASE_PROFILE]
    if mine:
        body["id"] = mine[0]["id"]
        h.put(f"/releaseprofile/{body['id']}", body)
    else:
        h.post("/releaseprofile", body)
    ok(f"{app}: release filter for cam/telesync and executables active")


def configure_media_management(app, h):
    mm = h.get("/config/mediamanagement")
    mm.update({
        "copyUsingHardlinks": True,
        "importExtraFiles": True,
        "extraFileExtensions": "srt,ass,ssa,sub,idx",
        "setPermissionsLinux": False,
        "deleteEmptyFolders": True,
        # The user picks the exact release; a repack or proper must not replace it (or be grabbed
        # next to it) by itself. Still preferred when the *arr chooses on its own.
        "downloadPropersAndRepacks": "doNotUpgrade",
    })
    # When a downloaded file is deleted (watched and cleaned up), stop monitoring that
    # episode/movie, or Sonarr/Radarr would simply download it again.
    for k in ("autoUnmonitorPreviouslyDownloadedEpisodes", "autoUnmonitorPreviouslyDownloadedMovies"):
        if k in mm:
            mm[k] = True
    h.put(f"/config/mediamanagement/{mm['id']}", mm)
    ok(f"{app}: media management (hardlinks, subtitles, no re-download of deleted files) set")


# Events after which Jellyfin should look at the library again. Each is set only when
# the app supports it (Sonarr and Radarr name some of them differently).
REFRESH_EVENTS = ["onDownload", "onUpgrade", "onImportComplete", "onRename", "onSeriesDelete",
                  "onEpisodeFileDelete", "onMovieDelete", "onMovieFileDelete"]


def tortugarr_plugin_active():
    try:
        h, _ = jellyfin_login()
        return any(p.get("Id", "").replace("-", "") == TORTUGARR_PLUGIN_GUID and p.get("Status") == "Active"
                   for p in h.get("/Plugins"))
    except BootstrapError:
        return False


def configure_jellyfin_refresh(app, h):
    """Tell Jellyfin to rescan as soon as something is imported, renamed or deleted.

    Sonarr/Radarr's own "Emby / Jellyfin" connection still sends an auth header that
    Jellyfin 10.11+/12 rejects (401), so a plain webhook with the header Jellyfin wants
    is used instead. Without it new files only show up on the next scheduled scan.
    It goes to the Tortugarr plugin, which refreshes only the folder that changed (plugin
    spec 3.12); /Library/Refresh, a scan of every library, only when the plugin is not active."""
    if "jellyfin" in FAILED_STEPS:
        warn(f"{app}: instant library refresh skipped: Jellyfin setup failed (run repair)")
        return
    key = SECRETS.get("jellyfin_api_key")
    if not key:
        warn(f"{app}: no Jellyfin API key yet - instant library refresh skipped (run repair)")
        return
    targeted = tortugarr_plugin_active() and bool(SECRETS.get("tortugarr_hook_key"))
    if targeted:
        # Only the hook's own key: Radarr/Sonarr then hold no Jellyfin administrator key.
        values = {"url": "http://jellyfin:8096/Tortugarr/v1/Hooks/Arr", "method": 1,
                  "headers": [{"key": "X-Tortugarr-Hook-Key", "value": SECRETS["tortugarr_hook_key"]}]}
    else:
        values = {"url": "http://jellyfin:8096/Library/Refresh", "method": 1,
                  "headers": [{"key": "Authorization", "value": f'MediaBrowser Token="{key}"'}]}

    def events(item):
        return {e: True for e in REFRESH_EVENTS if item.get("supports" + e[0].upper() + e[1:])}

    res = upsert_provider(h, "/notification", "Tortugarr: refresh Jellyfin", "Webhook", values, extra=events)
    if targeted:
        ok(f"{app}: Jellyfin refreshes only the changed folder on import/delete {res}")
    else:
        warn(f"{app}: the Tortugarr plugin is not active - every import scans all libraries (run repair) {res}")


def arr_roots(app):
    """The root folders Radarr/Sonarr should add new titles to: Tortugarr's own folder and the
    extra folders of that type it may manage."""
    kind = "tv" if app == "sonarr" else "movies"
    own = "/data/media/tv" if app == "sonarr" else "/data/media/movies"
    return [own] + [e["container_path"] for e in STATE.get("extra_libraries", [])
                    if e.get("type") == kind and e.get("arr_manage")]


def folder_names(h, path):
    """The sub-folder names of a folder as Radarr/Sonarr see it; empty when it is not there."""
    try:
        listing = h.get(f"/filesystem?path={urllib.parse.quote(path.rstrip('/') + '/')}"
                        f"&includeFiles=false&allowFoldersWithoutTrailingSlashes=true")
    except BootstrapError:
        return set()
    return {d.get("name") for d in listing.get("directories", [])}


def title_has_files(t):
    return bool(t.get("hasFile") or (t.get("statistics") or {}).get("episodeFileCount"))


def relink_moved_titles(app, h):
    """Points titles back at their folder when it is no longer where Radarr/Sonarr have it. Each
    extra media folder sits at /data/library/N; installers before 4.20.01 numbered them again
    when the list was entered anew, so on 2026-10-20 45 series and 74 movies pointed at a folder
    that now held other things. Files are never touched (moveFiles=false):
      - a title whose folder is missing in its own root and found in exactly one root of this
        type is pointed there;
      - a title in a /data/library root of another type with nothing on disk (wanted, not yet
        downloaded) is moved to the root of this type with the most free space, so its download
        does not land in, say, the clips folder;
      - a title whose folder really is in a root of another type is listed for the user.
    Root folders under /data/library that are left empty and are not of this type are removed."""
    kind = "series" if app == "sonarr" else "movie"
    roots = arr_roots(app)
    folders = h.get("/rootfolder")
    free = {f["path"].rstrip("/"): f.get("freeSpace") or 0 for f in folders}
    targets = new_title_roots(app)
    roomiest = max((r for r in targets if r in free), key=lambda r: free[r], default=targets[0])
    names = {}

    def has(root, name):
        if root not in names:
            names[root] = folder_names(h, root)
        return name in names[root]

    titles = h.get(f"/{kind}")
    taken = {t["path"].rstrip("/") for t in titles}
    moved, stray, failed = [], [], []
    for t in titles:
        root, _, name = t["path"].rstrip("/").rpartition("/")
        # Tortugarr's own folder when new titles go only to the user's folders: on WSL it is the
        # Linux disk, and a title waiting there would be downloaded into it.
        wrong_type = (root.startswith("/data/library/") and root not in roots) or (root == roots[0] and root not in targets)
        if not name:
            continue
        if has(root, name):
            if wrong_type:
                stray.append(t["path"])
            continue
        found = [r for r in targets if r != root and has(r, name)] or [r for r in roots if r != root and has(r, name)]
        if len(found) == 1:
            target = found[0]
        elif wrong_type and not found and not title_has_files(t):
            target = roomiest
        elif wrong_type and not found:
            stray.append(t["path"])
            continue
        else:
            continue
        new_path = f"{target}/{name}"
        if new_path in taken:
            failed.append(f"{t['path']} ({new_path} belongs to another title)")
            continue
        body = dict(t, path=new_path, rootFolderPath=target)
        try:
            h.put(f"/{kind}/{t['id']}?moveFiles=false", body)
        except BootstrapError as e:
            failed.append(f"{t['path']} ({str(e)[-80:]})")
            continue
        taken.discard(t["path"].rstrip("/"))
        taken.add(new_path)
        t.update(body)
        moved.append(t["id"])
    if moved:
        if app == "sonarr":
            h.post("/command", {"name": "RefreshSeries", "seriesIds": moved})
        else:
            h.post("/command", {"name": "RefreshMovie", "movieIds": moved})
        ok(f"{app}: {len(moved)} title(s) pointed at the right folder (no files moved)")
    if failed:
        warn(f"{app}: could not be pointed at their folder: {'; '.join(failed)} - when two titles share "
             f"a folder, delete the wrong one in {app.capitalize()} (do not delete its files)")
    if stray:
        warn(f"{app}: in a folder that is not a {app.capitalize()} folder any more: {'; '.join(stray)} - "
             f"delete them in {app.capitalize()} if they do not belong there (do not delete the files)")
    if app == "radarr":
        # Radarr adds missing collection movies to the collection's root folder; one that is gone
        # is a health error.
        coll = [c for c in h.get("/collection") if c.get("rootFolderPath", "").rstrip("/") not in roots]
        for c in coll:
            h.put(f"/collection/{c['id']}", dict(c, rootFolderPath=roomiest))
        if coll:
            ok(f"radarr: {len(coll)} collection(s) now add to {roomiest}")
    used = {t["path"].rstrip("/").rpartition("/")[0] for t in titles}
    for f in folders:
        path = f["path"].rstrip("/")
        if path.startswith("/data/library/") and path not in roots and path not in used:
            h.delete(f"/rootfolder/{f['id']}")
            ok(f"{app}: removed root folder {path} (not a {app.capitalize()} folder in Tortugarr's setup, no titles)")


def new_title_roots(app):
    """The root folders new titles go to: the user's own folders of this type when there are any
    and new_titles_in_extra_only is on (the default), else every root of this type. On WSL
    Tortugarr's own folder lives inside the distro's virtual disk, which reports its 1 TB limit
    as free space; on 2026-10-20 it took every new movie away from the drives the user chose."""
    roots = arr_roots(app)
    if len(roots) > 1 and STATE.get("new_titles_in_extra_only", True):
        return roots[1:]
    return roots


def configure_arr(app):
    h = wait_arr(app)
    set_arr_auth(app, h)
    root = "/data/media/tv" if app == "sonarr" else "/data/media/movies"
    ensure_root_folder(app, h, root)
    relink_moved_titles(app, h)
    for extra in STATE.get("extra_libraries", []):
        if extra["type"] == ("tv" if app == "sonarr" else "movies") and extra.get("arr_manage"):
            ensure_root_folder(app, h, extra["container_path"])
            import_existing(app, h, extra["container_path"])
    configure_download_clients(app, h)
    configure_remote_paths(app, h)
    configure_quality(app, h)
    configure_release_filter(app, h)
    configure_media_management(app, h)
    configure_jellyfin_refresh(app, h)
    return h


def ensure_tag(h, label):
    for t in h.get("/tag"):
        if t["label"] == label:
            return t["id"]
    return h.post("/tag", {"label": label})["id"]


def configure_prowlarr():
    h = wait_arr("prowlarr")
    set_arr_auth("prowlarr", h)
    for app in ("sonarr", "radarr"):
        values = {"prowlarrUrl": "http://prowlarr:9696", "baseUrl": f"http://{app}:{ARR_PORT[app]}",
                  "apiKey": secret(f"{app}_api_key")}
        res = upsert_provider(h, "/applications", app.capitalize(), app.capitalize(), values,
                              extra={"syncLevel": "fullSync"})
        ok(f"prowlarr: app link to {app} {res}")
    tag = ensure_tag(h, "flaresolverr")
    res = upsert_provider(h, "/indexerProxy", "FlareSolverr", "FlareSolverr",
                          {"host": "http://flaresolverr:8191/", "requestTimeout": 60},
                          extra={"tags": [tag]})
    ok(f"prowlarr: FlareSolverr proxy {res} (steps in only when Cloudflare blocks an indexer)")
    configure_download_clients("prowlarr", h)
    indexers = h.get("/indexer")
    if not indexers:
        warn("prowlarr: no indexers yet - add your own in Prowlarr (Indexers > Add Indexer)")
        important(CLOUDFLARE_TIP)
        return
    # Every indexer carries the proxy's tag (the plugin keeps it so for new ones):
    # FlareSolverr only steps in on a Cloudflare challenge, so other sites are unchanged.
    tagged = []
    for ix in indexers:
        if tag not in (ix.get("tags") or []):
            ix["tags"] = (ix.get("tags") or []) + [tag]
            h.put(f"/indexer/{ix['id']}?forceSave=true", ix)
            tagged.append(ix.get("name", str(ix["id"])))
    if tagged:
        ok(f"prowlarr: {', '.join(tagged)} now go(es) through FlareSolverr when Cloudflare blocks it")
    ok(f"prowlarr: {len(indexers)} indexer(s) configured, all with the flaresolverr tag")


# --------------------------------------------------------------------------- bazarr

# Subtitle providers that work without an account. OpenSubtitles.com needs one, so the
# user is told how to add it instead.
FREE_SUBTITLE_PROVIDERS = ["embeddedsubtitles", "podnapisi", "gestdown", "yifysubtitles"]


def bazarr_key():
    """The key we seeded; if Bazarr's config.yaml says otherwise (an older install),
    trust the file."""
    key = secret("bazarr_api_key", api_key)
    try:
        with open(f"{CFG}/bazarr/config/config.yaml") as f:
            m = re.search(r"^auth:\n(?:[ \t]+.*\n)*?[ \t]+apikey:\s*['\"]?([0-9a-f]+)", f.read(), re.M)
        if m and m.group(1) != key:
            SECRETS["bazarr_api_key"] = key = m.group(1)
            save_json(f"{INSTALL}/secrets.json", SECRETS)
    except OSError:
        pass
    return key


def bazarr():
    return Http("http://bazarr:6767/api", headers={"X-API-KEY": bazarr_key()})


def configure_bazarr():
    wait_http("bazarr", "http://bazarr:6767/api/system/status", accept=(200, 401))
    h = bazarr()
    for _ in range(20):  # the API answers before the database is ready on first start
        try:
            h.get("/system/status")
            break
        except BootstrapError:
            time.sleep(3)
    langs = STATE.get("subtitle_languages") or ["en"]
    items = [{"id": i + 1, "language": code, "hi": "False", "forced": "False",
              "audio_exclude": "False", "audio_only_include": "False"} for i, code in enumerate(langs)]
    profile = [{"profileId": 1, "name": "Tortugarr", "cutoff": None, "items": items,
                "mustContain": [], "mustNotContain": [], "originalFormat": None, "tag": None}]
    form = [("languages-enabled", code) for code in langs]
    form.append(("languages-profiles", json.dumps(profile)))
    form += [("settings-general-use_sonarr", "true"), ("settings-general-use_radarr", "true")]
    for app, port in (("sonarr", 8989), ("radarr", 7878)):
        form += [(f"settings-{app}-ip", app), (f"settings-{app}-port", str(port)),
                 (f"settings-{app}-base_url", "/"), (f"settings-{app}-ssl", "false"),
                 (f"settings-{app}-apikey", secret(f"{app}_api_key"))]
    form += [("settings-general-serie_default_enabled", "true"), ("settings-general-serie_default_profile", "1"),
             ("settings-general-movie_default_enabled", "true"), ("settings-general-movie_default_profile", "1")]
    form += [("settings-general-enabled_providers", p) for p in FREE_SUBTITLE_PROVIDERS]
    form += [("settings-auth-type", "form"), ("settings-auth-username", SECRETS["admin_user"]),
             ("settings-auth-password", SECRETS["admin_password"])]
    h.post("/system/settings", form=form)
    s = h.get("/system/settings")
    if not (s["general"]["use_sonarr"] and s["general"]["use_radarr"] and s["sonarr"]["ip"] == "sonarr"):
        raise BootstrapError("settings were not saved")
    ok(f"bazarr: linked to Sonarr and Radarr, subtitles in {', '.join(langs)}, "
       f"{len(FREE_SUBTITLE_PROVIDERS)} free providers (add OpenSubtitles.com with your own account)")


# --------------------------------------------------------------------------- torrent / usenet clients

def configure_external_qbittorrent():
    """A qBittorrent outside the stack is the user's own: only the radarr and sonarr categories
    are added when missing, next to its save folder. Its settings are left alone; a missing
    block on .exe and other program files is pointed out instead."""
    base = external_qbit()["url"].rstrip("/")
    wait_http("qBittorrent", base + "/", accept=(200, 401, 403), timeout=60)
    h = Http(base, cookies=True, headers={"Referer": base, "Origin": base})
    user, pw = download_client_login()
    if user:
        res = h.request("POST", "/api/v2/auth/login", form={"username": user, "password": pw}, raw=True)
        if b"Fails" in (res or b""):
            raise BootstrapError("your qBittorrent refused the user name or password in state.json/secrets.json "
                                 "(external_qbit). Fix them, then run: sudo tortugarr repair")
    prefs = h.get("/api/v2/app/preferences")
    save = prefs.get("save_path", "")
    sep = "\\" if re.match(r"^[A-Za-z]:", save) else "/"
    cats = h.get("/api/v2/torrents/categories") or {}
    for app in ("radarr", "sonarr"):
        cat = CATEGORY[app]
        if cat in cats:
            continue
        h.request("POST", "/api/v2/torrents/createCategory",
                  form={"category": cat, "savePath": save.rstrip("\\/") + sep + cat}, raw=True)
        ok(f"qbittorrent: category {cat} added (saves under {save})")
    if not prefs.get("excluded_file_names_enabled"):
        warn("qbittorrent: your qBittorrent downloads program files too. Turn on Tools > Options > Downloads > "
             "Excluded file names and add: " + ", ".join(BLOCKED_FILE_PATTERNS))
    ok(f"qbittorrent: yours at {base} (not managed by Tortugarr)")


def configure_qbittorrent():
    base = f"http://{client_host('qbittorrent')}:8080"
    wait_http("qbittorrent", base + "/", accept=(200, 401, 403))
    h = Http(base, cookies=True, headers={"Referer": base, "Origin": base})
    user, pw = SECRETS["admin_user"], SECRETS["admin_password"]
    # qBittorrent 4 answers "Ok." and qBittorrent 5 an empty 204; both set the SID
    # cookie. "Fails." is a wrong password. Stop early on a wrong password: five
    # failures in a row get the address banned for an hour.
    deadline = time.time() + 120
    while True:
        try:
            res = h.request("POST", "/api/v2/auth/login", form={"username": user, "password": pw}, raw=True)
        except BootstrapError:
            res = None
        if res is not None:
            if b"Fails" in res:
                raise BootstrapError("login with the admin password was refused. If the password was changed "
                                     "in the qBittorrent web UI, put the new one in secrets.json (admin_password) "
                                     "or reset it there, then run: sudo tortugarr repair")
            if any(c.name.startswith("QBT_SID") or c.name == "SID" for c in h.jar):
                break
        if time.time() > deadline:
            raise BootstrapError("the web UI did not accept a login within 2 minutes")
        time.sleep(3)
    prefs = {
        "save_path": "/data/torrents",
        # Category save paths (tv/, movies/) only apply in automatic management mode.
        "auto_tmm_enabled": True,
        "torrent_changed_tmm_enabled": True,
        "save_path_changed_tmm_enabled": True,
        "category_changed_tmm_enabled": True,
        "temp_path_enabled": False,
        "excluded_file_names_enabled": True,
        "excluded_file_names": "\n".join(BLOCKED_FILE_PATTERNS),
        "listen_port": int(STATE["ports"]["torrent_peer"]),
        "upnp": False,
        "web_ui_host_header_validation_enabled": False,
        "bypass_local_auth": False,
        "max_ratio_enabled": True,
        "max_ratio": 2,
        "max_ratio_act": 0,
    }
    h.request("POST", "/api/v2/app/setPreferences", form={"json": json.dumps(prefs)}, raw=True)
    ok("qbittorrent: save path, peer port and blocked file types (.exe, .scr, .lnk ...) set")
    cats = h.get("/api/v2/torrents/categories") or {}
    for app, cat in CATEGORY.items():
        form = {"category": cat, "savePath": f"/data/torrents/{CATEGORY_DIR[app]}"}
        endpoint = "editCategory" if cat in cats else "createCategory"
        h.request("POST", f"/api/v2/torrents/{endpoint}", form=form, raw=True)
    # The adult library's category (used only if an administrator switches it on in the plugin).
    form = {"category": "adult", "savePath": "/data/media/adult"}
    h.request("POST", f"/api/v2/torrents/{'editCategory' if 'adult' in cats else 'createCategory'}", form=form, raw=True)
    ok("qbittorrent: categories sonarr -> torrents/tv, radarr -> torrents/movies, prowlarr, adult")


def configure_transmission():
    base = f"http://{client_host('transmission')}:9091/transmission/rpc"
    wait_http("transmission", base, accept=(200, 401, 409))
    auth = base64.b64encode(f"{SECRETS['admin_user']}:{SECRETS['admin_password']}".encode()).decode()
    headers = {"Authorization": f"Basic {auth}"}
    sid = ""
    for _ in range(2):
        req = urllib.request.Request(base, method="POST", headers={**headers, "X-Transmission-Session-Id": sid,
                                                                   "Content-Type": "application/json"},
                                     data=json.dumps({"method": "session-set", "arguments": {
                                         "download-dir": "/data/torrents",
                                         "incomplete-dir-enabled": False,
                                         "peer-port": int(STATE["ports"]["torrent_peer"]),
                                         "port-forwarding-enabled": False,
                                         "seedRatioLimit": 2, "seedRatioLimited": True}}).encode())
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                if json.loads(r.read()).get("result") == "success":
                    ok("transmission: download dir and peer port set")
                    warn("transmission: cannot block .exe files itself; Sonarr/Radarr filters and import checks still apply")
                    return
        except urllib.error.HTTPError as e:
            if e.code == 409:
                sid = e.headers.get("X-Transmission-Session-Id", "")
                continue
            raise BootstrapError(f"transmission: HTTP {e.code} (wrong password?)")
    raise BootstrapError("transmission: could not configure session")


def configure_deluge():
    base = f"http://{client_host('deluge')}:8112/json"
    wait_http("deluge", f"http://{client_host('deluge')}:8112/", accept=(200,))
    h = Http(base, cookies=True)
    seq = iter(range(1, 1000))

    def call(method, *params):
        r = h.post("", {"method": method, "params": list(params), "id": next(seq)})
        if r.get("error"):
            raise BootstrapError(f"deluge {method}: {r['error']}")
        return r.get("result")

    pw = SECRETS["admin_password"]
    if not call("auth.login", pw):
        if call("auth.login", "deluge"):
            call("auth.change_password", "deluge", pw)
            ok("deluge: default web password replaced by the admin password")
        else:
            raise BootstrapError("deluge: neither the admin password nor the default works")
    if not call("web.connected"):
        hosts = call("web.get_hosts")
        if hosts:
            call("web.connect", hosts[0][0])
            time.sleep(2)
    call("core.set_config", {"download_location": "/data/torrents", "move_completed": False,
                             "listen_ports": [int(STATE["ports"]["torrent_peer"])] * 2,
                             "random_port": False, "upnp": False, "natpmp": False,
                             "stop_seed_at_ratio": True, "stop_seed_ratio": 2.0})
    if "Label" not in (call("core.get_enabled_plugins") or []):
        call("core.enable_plugin", "Label")
    ok("deluge: download dir, peer port and Label plugin set")
    warn("deluge: cannot block .exe files itself; Sonarr/Radarr filters and import checks still apply")


def configure_sabnzbd():
    base = f"http://sabnzbd:8080/api"
    wait_http("sabnzbd", "http://sabnzbd:8080/", accept=(200, 303, 401, 403))
    key = secret("sabnzbd_api_key")
    h = Http(base)
    # One category per app, each in its own folder under complete/.
    for app, cat in CATEGORY.items():
        q = urllib.parse.urlencode({"mode": "set_config", "section": "categories", "keyword": cat,
                                    "dir": CATEGORY_DIR[app], "output": "json", "apikey": key})
        h.get(f"?{q}")
    ok("sabnzbd: categories sonarr -> complete/tv, radarr -> complete/movies, prowlarr")
    r = h.get(f"?mode=get_config&section=servers&output=json&apikey={key}")
    servers = (r or {}).get("config", {}).get("servers", [])
    if servers:
        ok(f"sabnzbd: {len(servers)} usenet server(s) configured")
    else:
        warn("sabnzbd: no usenet server yet - add your provider in SABnzbd (Config > Servers)")


# --------------------------------------------------------------------------- jellyfin

def jellyfin_auth_header(token=None):
    version = os.environ.get("TORTUGARR_VERSION") or "4.20.01"
    parts = ['Client="Tortugarr Installer"', 'Device="installer"', 'DeviceId="tortugarr-installer"', f'Version="{version}"']
    if token:
        parts.append(f'Token="{token}"')
    return {"Authorization": "MediaBrowser " + ", ".join(parts)}


def jellyfin_base():
    return "http://jellyfin:8096"


# How long Jellyfin may take to start. A slow machine (a Win11 VM, 2026-10-07) answered /health
# while /Startup/* still returned 503 - Jellyfin had not finished starting.
JELLYFIN_START_TIMEOUT = 300


def jellyfin_login():
    h = Http(jellyfin_base(), headers=jellyfin_auth_header())
    r = h.post("/Users/AuthenticateByName", {"Username": SECRETS["admin_user"], "Pw": SECRETS["admin_password"]},
               retry_unavailable=120)
    return Http(jellyfin_base(), headers=jellyfin_auth_header(r["AccessToken"])), r


def jellyfin_wait_ready(timeout=JELLYFIN_START_TIMEOUT):
    """Wait until Jellyfin has really finished starting: /System/Info/Public answers 200 and,
    while the startup wizard is not done, /Startup/Configuration no longer answers 503.
    /health alone says 200 too early. Returns /System/Info/Public."""
    h = Http(jellyfin_base(), headers=jellyfin_auth_header(), timeout=10)
    deadline = time.time() + timeout
    said = False
    last = None
    while True:
        try:
            pub = h.get("/System/Info/Public")
            if pub.get("StartupWizardCompleted"):
                return pub
            try:
                h.get("/Startup/Configuration")
            except BootstrapError as e:
                # Only 503 means "still starting"; any other answer is for the wizard calls to report.
                if getattr(e, "status", None) != 503:
                    return pub
                raise
            return pub
        except (BootstrapError, urllib.error.URLError, OSError) as e:
            status = getattr(e, "status", None)
            last = f"HTTP {status}" if status else str(getattr(e, "reason", e))
        if time.time() >= deadline:
            raise BootstrapError(f"jellyfin did not finish starting within {timeout}s (last answer: {last}) - "
                                 "run 'sudo tortugarr repair' once it is up")
        if not said:
            span = f"{timeout // 60} minutes" if timeout >= 120 else f"{timeout} s"
            info(f"jellyfin: still starting ({last}) - waiting up to {span}")
            said = True
        time.sleep(3)


def jellyfin_startup():
    h = Http(jellyfin_base(), headers=jellyfin_auth_header())
    info_ = jellyfin_wait_ready()
    if info_.get("StartupWizardCompleted"):
        info("jellyfin: startup wizard already completed")
        return
    lang = STATE.get("metadata_language", "en")
    country = STATE.get("metadata_country", "US")
    # Each call tries again on 503 as well: Jellyfin can still be busy between the calls.
    wait = {"retry_unavailable": 120}
    h.post("/Startup/Configuration", {"UICulture": "en-US", "MetadataCountryCode": country,
                                      "PreferredMetadataLanguage": lang}, **wait)
    h.get("/Startup/User", **wait)
    h.post("/Startup/User", {"Name": SECRETS["admin_user"], "Password": SECRETS["admin_password"]}, **wait)
    h.post("/Startup/RemoteAccess", {"EnableRemoteAccess": True, "EnableAutomaticPortMapping": False}, **wait)
    h.post("/Startup/Complete", **wait)
    ok(f"jellyfin: startup wizard completed, admin user '{SECRETS['admin_user']}' created")


# Jellyfin library per extra-folder type (lib/extra_libs.sh). Adult folders go into the
# plugin's hidden adult library instead (jellyfin_adult_folders).
EXTRA_LIBRARY = {"movies": ("Movies", "movies"), "tv": ("TV Shows", "tvshows"),
                 "music": ("Music Videos", "musicvideos"), "other": ("Home Videos", "homevideos")}
EXTRA_PATH_RE = re.compile(r"^/data/library/[0-9]+/?$")
OWN_MEDIA_PATHS = {"/data/media/movies", "/data/media/tv"}


def extra_library_paths():
    """{library name: (collection type, [paths])} for Tortugarr's folders and the extra ones."""
    # Tortugarr's own folders only while new titles may go there: with the user's own movie or
    # series folders they stay out (on WSL they are the Linux disk; the user removed them from
    # the libraries on 2026-10-20 and repair put them back).
    wanted = {"Movies": ("movies", [p for p in ["/data/media/movies"] if p in new_title_roots("radarr")]),
              "TV Shows": ("tvshows", [p for p in ["/data/media/tv"] if p in new_title_roots("sonarr")])}
    for extra in STATE.get("extra_libraries", []):
        lib = EXTRA_LIBRARY.get(extra.get("type"))
        if lib:
            wanted.setdefault(lib[0], (lib[1], []))[1].append(extra["container_path"])
    return wanted


def jellyfin_libraries(h):
    existing = {f["Name"]: f for f in h.get("/Library/VirtualFolders")}
    wanted = extra_library_paths()
    # A folder the user put in a library of their own (renamed, or made by hand, such as
    # "Music & Conserts" on 2026-10-20) stays there: it is neither added elsewhere nor removed.
    ours = {n for n, _ in EXTRA_LIBRARY.values()}
    held = {p.rstrip("/") for n, f in existing.items() if n not in ours and not folder_is_adult(f)
            for p in f.get("Locations", [])}
    created = []
    for name, (ctype, paths) in wanted.items():
        paths = [p for p in paths if p.rstrip("/") not in held]
        if not paths:
            continue
        if name not in existing:
            opts = {"LibraryOptions": {
                "EnableRealtimeMonitor": True,
                "SaveLocalMetadata": False,
                "SaveTrickplayWithMedia": False,
                "SaveLyricsWithMedia": False,
                "EnableTrickplayImageExtraction": True,
                # The app shows a Chapters tab with a picture per chapter. Jellyfin's nightly
                # task makes them, so library scans stay fast.
                "EnableChapterImageExtraction": True,
                "ExtractChapterImagesDuringLibraryScan": False,
                # Films of one series (TMDB collection) are grouped into a collection.
                "AutomaticallyAddToCollection": ctype == "movies",
                "PathInfos": [{"Path": p} for p in paths],
            }}
            q = urllib.parse.urlencode({"name": name, "collectionType": ctype, "refreshLibrary": "true"})
            h.post(f"/Library/VirtualFolders?{q}", opts)
            created.append(name)
            ok(f"jellyfin: library '{name}' -> {', '.join(paths)}")
        else:
            have = set(existing[name].get("Locations", []))
            for p in paths:
                if p not in have:
                    h.post("/Library/VirtualFolders/Paths?refreshLibrary=true",
                           {"Name": name, "PathInfo": {"Path": p}})
                    ok(f"jellyfin: added {p} to '{name}'")
    # An extra folder whose type changed (or that was removed) leaves its old library. Only the
    # installer's own /data/library/N paths are touched, never folders added by hand.
    for name, folder in existing.items():
        if name not in ours and not folder_is_adult(folder):
            continue
        keep = set(wanted.get(name, ("", []))[1]) | set(jellyfin_adult_paths() if folder_is_adult(folder) else [])
        for p in folder.get("Locations", []):
            if (EXTRA_PATH_RE.match(p) or p.rstrip("/") in OWN_MEDIA_PATHS) \
                    and p.rstrip("/") not in {k.rstrip("/") for k in keep}:
                q = urllib.parse.urlencode({"name": name, "path": p, "refreshLibrary": "true"})
                h.delete(f"/Library/VirtualFolders/Paths?{q}")
                ok(f"jellyfin: removed {p} from '{name}' (that folder's type changed, or new titles go to your own folders)")
    jellyfin_library_access(h, created)
    jellyfin_adult_folders(h)


def jellyfin_library_access(h, names):
    """A new library is shown to the users who see the Movies library but not every library
    (EnableAllFolders off): on 2026-10-20 Home Videos and Music Videos existed, but the
    administrator's account only had its four old libraries."""
    if not names:
        return
    ids = {f["Name"]: f.get("ItemId") for f in h.get("/Library/VirtualFolders")}
    new = [ids[n] for n in names if ids.get(n)]
    for u in h.get("/Users"):
        pol = u.get("Policy") or {}
        enabled = pol.get("EnabledFolders") or []
        if pol.get("EnableAllFolders") or ids.get("Movies") not in enabled:
            continue
        add = [i for i in new if i not in enabled]
        if add:
            h.post(f"/Users/{u['Id']}/Policy", dict(pol, EnabledFolders=enabled + add))
            ok(f"jellyfin: {u['Name']} sees {', '.join(names)}")


ADULT_SAVE_PATH = "/data/media/adult"


def jellyfin_adult_paths():
    return [e["container_path"] for e in STATE.get("extra_libraries", []) if e.get("type") == "adult"]


def adult_save_path():
    """The folder of the plugin's adult library. With a qBittorrent outside the stack and an adult
    folder of the user's own, that folder: adult downloads are saved there (AdultDownloadPath) and
    nothing lands in the Linux disk. On 2026-10-20 the user took /data/media/adult out of the
    adult library, and the plugin, finding no library on it, made a second one ("Adult2")."""
    if torrent_client() == "qbittorrent-ext":
        paths = jellyfin_adult_paths()
        if paths:
            return paths[0]
    return ADULT_SAVE_PATH


def folder_is_adult(folder):
    mark = adult_save_path().rstrip("/")
    return any(l.rstrip("/") == mark for l in folder.get("Locations", []))


def drop_stale_adult_library(h):
    """Removes an empty library that only holds /data/media/adult once the adult library lives in
    the user's own folder (the "Adult2" the plugin made before). Jellyfin leaves the files alone."""
    if adult_save_path() == ADULT_SAVE_PATH:
        return
    for f in h.get("/Library/VirtualFolders"):
        locs = [l.rstrip("/") for l in f.get("Locations", [])]
        if locs != [ADULT_SAVE_PATH]:
            continue
        # The plugin hides the adult library from every account, the administrator too, so the
        # count is asked with Tortugarr's API key (no user).
        # Media only: Jellyfin counts the library's own folder as an item, and IsFolder=false
        # does not leave it out (checked on Jellyfin 12.0.0).
        path = f"/Items?ParentId={f.get('ItemId')}&Recursive=true&MediaTypes=Video,Photo,Audio&Limit=0"
        try:
            items = h.get(path)
        except BootstrapError:
            base = getattr(h, "base", "http://jellyfin:8096")
            items = Http(base, headers={"Authorization": f'MediaBrowser Token="{jellyfin_api_key(h)}"'}).get(path)
        if (items or {}).get("TotalRecordCount", 1) == 0:
            h.delete(f"/Library/VirtualFolders?{urllib.parse.urlencode({'name': f['Name'], 'refreshLibrary': 'true'})}")
            ok(f"jellyfin: removed the empty library '{f['Name']}' ({ADULT_SAVE_PATH}, replaced by your adult folder)")


def jellyfin_adult_folders(h):
    """Adult extra folders join the plugin's adult library, which the plugin creates and hides
    from everyone when an administrator switches it on. Never created here, so it cannot show
    up for everyone by accident."""
    paths = jellyfin_adult_paths()
    if not paths:
        return
    drop_stale_adult_library(h)
    adult = next((f for f in h.get("/Library/VirtualFolders") if folder_is_adult(f)), None)
    if adult is None:
        info("jellyfin: adult folders wait for the adult library - switch it on in the app "
             "(Settings > Adult library), then run: sudo tortugarr repair")
        return
    have = {l.rstrip("/") for l in adult.get("Locations", [])}
    for p in paths:
        if p.rstrip("/") not in have:
            h.post("/Library/VirtualFolders/Paths?refreshLibrary=true",
                   {"Name": adult["Name"], "PathInfo": {"Path": p}})
            ok(f"jellyfin: added {p} to the adult library '{adult['Name']}'")


def jellyfin_api_key(h):
    keys = h.get("/Auth/Keys").get("Items", [])
    for k in keys:
        if k.get("AppName") == "Tortugarr":
            return k["AccessToken"]
    h.post("/Auth/Keys?app=Tortugarr")
    for k in h.get("/Auth/Keys").get("Items", []):
        if k.get("AppName") == "Tortugarr":
            return k["AccessToken"]
    raise BootstrapError("jellyfin: could not create an API key")


def jellyfin_scan_interval(h):
    """Sonarr/Radarr cannot notify Jellyfin 10.11+/12 (they still send the removed
    X-Emby-Token header), and inotify does not fire on network or WSL /mnt drives,
    so a frequent library scan is what makes new downloads show up."""
    tasks = h.get("/ScheduledTasks?isHidden=false")
    scan = next((t for t in tasks if t.get("Key") == "RefreshLibrary"), None)
    if not scan:
        warn("jellyfin: library scan task not found")
        return
    interval = int(STATE.get("library_scan_minutes", 30)) * 60 * 10_000_000
    triggers = [{"Type": "IntervalTrigger", "IntervalTicks": interval}]
    h.post(f"/ScheduledTasks/{scan['Id']}/Triggers", triggers)
    ok(f"jellyfin: library scan every {STATE.get('library_scan_minutes', 30)} minutes")


def plugin_version_tuple(version):
    """'2.4.0.0' -> (2, 4, 0, 0); anything unreadable sorts lowest."""
    try:
        return tuple(int(part) for part in str(version).split("."))
    except ValueError:
        return (0,)


def moonfin_plugin_min_version():
    return STATE.get("moonfin_plugin_min_version") or STATE["moonfin_plugin_version"]


def moonfin_plugin_recent_enough(version):
    return plugin_version_tuple(version) >= plugin_version_tuple(moonfin_plugin_min_version())


def jellyfin_plugin(h):
    guid = STATE["moonfin_plugin_guid"]
    version = STATE["moonfin_plugin_version"]
    repo = STATE["moonfin_plugin_repo"]
    plugins = h.get("/Plugins")
    mine = [p for p in plugins if p.get("Id", "").replace("-", "") == guid.replace("-", "")]
    # Any active version from the minimum up is fine; Jellyfin's updater may
    # already have moved it past the version this release installs.
    if any(moonfin_plugin_recent_enough(p.get("Version")) and p.get("Status") == "Active" for p in mine):
        return False
    repos = h.get("/Repositories")
    if not any(r.get("Url") == repo for r in repos):
        repos.append({"Name": "Moonfin", "Url": repo, "Enabled": True})
        h.post("/Repositories", repos)
        ok("jellyfin: Moonfin plugin repository added")
    if any(moonfin_plugin_recent_enough(p.get("Version")) for p in mine):
        info(f"jellyfin: Moonfin plugin present with status {mine[0].get('Status')} - restart pending")
        return True
    # Nothing recent enough (none at all, or the 2.0.2.0 an earlier release pinned): install the
    # release's version next to it; jellyfin_plugin_pin removes the old one after the restart.
    q = urllib.parse.urlencode({"assemblyGuid": guid, "version": version, "repositoryUrl": repo})
    h.post(f"/Packages/Installed/Moonbase?{q}")
    ok(f"jellyfin: Moonfin plugin {version} installing")
    return True


def jellyfin_plugin_versions(h):
    guid = STATE["moonfin_plugin_guid"].replace("-", "")
    return [p for p in h.get("/Plugins") if p.get("Id", "").replace("-", "") == guid]


def jellyfin_plugin_pin():
    """Keep the Moonfin plugin at the minimum version or newer, and up to date.

    Versions older than the minimum (the server side of the Moonfin release the app is
    built on) are removed. Auto-update is switched on in the plugin's meta.json, so
    Jellyfin installs new Moonfin plugin releases by itself. Earlier Tortugarr releases
    pinned one exact version with auto-update off; this undoes that.
    Returns True when a restart is needed."""
    minimum = moonfin_plugin_min_version()
    root = f"{CFG}/jellyfin/plugins"
    changed = False
    if not os.path.isdir(root):
        return False
    for d in os.listdir(root):
        meta_path = os.path.join(root, d, "meta.json")
        if not os.path.isfile(meta_path):
            continue
        try:
            with open(meta_path) as f:
                meta = json.load(f)
        except ValueError:
            continue
        if meta.get("guid", "").replace("-", "") != STATE["moonfin_plugin_guid"].replace("-", ""):
            continue
        if not moonfin_plugin_recent_enough(meta.get("version")):
            import shutil
            shutil.rmtree(os.path.join(root, d), ignore_errors=True)
            info(f"jellyfin: removed Moonfin plugin {meta.get('version')} (older than {minimum})")
            changed = True
        elif not meta.get("autoUpdate", True) or meta.get("status") != "Active":
            meta["autoUpdate"] = True
            meta["status"] = "Active"
            with open(meta_path, "w") as f:
                json.dump(meta, f, indent=2)
            chown_tree(os.path.join(root, d))
            changed = True
    return changed


def jellyfin_plugin_config(h):
    guid = STATE["moonfin_plugin_guid"].replace("-", "")
    try:
        conf = h.get(f"/Plugins/{guid}/Configuration")
    except BootstrapError as e:
        warn(f"jellyfin: Moonfin plugin configuration not reachable yet ({e})")
        return
    conf.update({
        "SeerrEnabled": True,
        "SeerrUrl": "http://seerr:5055",
        "WebDefaultServerUrl": lan_url("jellyfin"),
        # The address Seerr uses to reach the plugin. Without it the plugin falls back to
        # 127.0.0.1, which inside the Seerr container is Seerr itself.
        "PublicServerUrl": "http://jellyfin:8096",
        # The app has push notifications switched off; send nothing to the upstream relay.
        "PushRelayUrl": "",
    })
    if not conf.get("SeerrWebhookSecret"):
        conf["SeerrWebhookSecret"] = uuid.uuid4().hex
    h.post(f"/Plugins/{guid}/Configuration", conf)
    ok("jellyfin: Moonfin plugin points at Seerr (push relay off)")


def jellyfin_restart_and_wait(h):
    try:
        h.post("/System/Restart")
    except BootstrapError:
        pass
    time.sleep(10)
    wait_http("jellyfin", jellyfin_base() + "/health", accept=(200,), timeout=JELLYFIN_START_TIMEOUT)
    jellyfin_wait_ready()
    time.sleep(5)


def jellyfin_server_name(h):
    """A real server name instead of the container id Jellyfin takes from its hostname (what the
    apps and Seerr show). A name the administrator chose stays."""
    conf = h.get("/System/Configuration")
    current = conf.get("ServerName") or ""
    if current and not re.fullmatch(r"[0-9a-f]{12}", current):
        return
    conf["ServerName"] = "Tortugarr"
    h.post("/System/Configuration", conf)
    ok("jellyfin: server name set to Tortugarr")


def configure_jellyfin():
    jellyfin_startup()
    h, _ = jellyfin_login()
    SECRETS["jellyfin_api_key"] = jellyfin_api_key(h)
    save_json(f"{INSTALL}/secrets.json", SECRETS)
    jellyfin_server_name(h)
    jellyfin_libraries(h)
    jellyfin_scan_interval(h)
    # An update copies a new Tortugarr plugin in while Jellyfin runs and removes the old folder.
    # Until Jellyfin restarts it still has the old version loaded, and its package catalog fails
    # on the missing folder ("Could not find a part of the path .../meta.json"), so installing
    # the Moonfin plugin fails with 404. Restart first.
    dist = tortugarr_plugin_dist()
    loaded = [p.get("Version") for p in h.get("/Plugins") if p.get("Id", "").replace("-", "") == TORTUGARR_PLUGIN_GUID]
    if dist and loaded and f"Tortugarr_{loaded[0]}" != dist[0]:
        info(f"jellyfin: restarting to load {dist[0]} (still running Tortugarr {loaded[0]})")
        jellyfin_restart_and_wait(h)
        h, _ = jellyfin_login()
    if STATE.get("moonfin_plugin", True):
        if jellyfin_plugin(h):
            jellyfin_restart_and_wait(h)
            h, _ = jellyfin_login()
        # A restart may have let Jellyfin's plugin updater install a newer version.
        for _ in range(2):
            if not jellyfin_plugin_pin():
                break
            jellyfin_restart_and_wait(h)
            h, _ = jellyfin_login()
        versions = [(p.get("Version"), p.get("Status")) for p in jellyfin_plugin_versions(h)]
        active = [v for v, st in versions if st == "Active" and moonfin_plugin_recent_enough(v)]
        if active and len(versions) == 1:
            ok(f"jellyfin: Moonfin plugin {active[0]} active (auto-update on)")
        else:
            warn(f"jellyfin: Moonfin plugin versions/status: {versions or 'not installed'}")
        jellyfin_plugin_config(h)
    # Tortugarr plugin: copied in during preseed; on repair/update a new version needs a restart.
    if install_tortugarr_plugin() or not any(p.get("Id", "").replace("-", "") == TORTUGARR_PLUGIN_GUID for p in h.get("/Plugins")):
        jellyfin_restart_and_wait(h)
        h, _ = jellyfin_login()
    if any(p.get("Id", "").replace("-", "") == TORTUGARR_PLUGIN_GUID and p.get("Status") == "Active" for p in h.get("/Plugins")):
        tortugarr_plugin_config(h)
    else:
        warn("jellyfin: the Tortugarr plugin did not load - Download Now stays off in the app (see Jellyfin's log)")


# --------------------------------------------------------------------------- seerr

def seerr():
    return Http("http://seerr:5055/api/v1", cookies=True)


def seerr_login():
    """A Seerr session as the admin (the Jellyfin admin is the Seerr owner)."""
    h = seerr()
    user, pw = SECRETS["admin_user"], SECRETS["admin_password"]
    h.post("/auth/jellyfin", {"username": user, "password": pw, "email": f"{user}@tortugarr.local"})
    return h


def arr_titles_per_root(app):
    """How many movies or series Radarr/Sonarr have in each root folder; empty on any error."""
    try:
        items = arr(app).get("/movie" if app == "radarr" else "/series")
    except BootstrapError:
        return {}
    counts = {}
    for i in items or []:
        root = (i.get("rootFolderPath") or i.get("path", "").rsplit("/", 1)[0]).rstrip("/")
        counts[root] = counts.get(root, 0) + 1
    return counts


def seerr_root(app, roots):
    """The folder Seerr adds requests to (one fixed folder): the roomiest of those new
    titles go to now. Folders on one drive have the same free space, and the one with the
    most titles is the main one (2026-10-21: E:\\-=MOVIES=- over E:\\-=Dokumentarer=-).
    The free space comes from Radarr/Sonarr themselves: Seerr's test answer has none, so
    every folder looked empty and the one with the most titles, on an 11 GB drive, won."""
    targets = set(new_title_roots(app))
    titles = arr_titles_per_root(app)
    free = arr_free_per_root(app)
    return max((r for r in roots if r["path"].rstrip("/") in targets),
               key=lambda r: (free.get(r["path"].rstrip("/"), r.get("freeSpace") or 0) // (1 << 30),
                              titles.get(r["path"].rstrip("/"), 0)),
               default=roots[0] if roots else None)


def arr_free_per_root(app):
    """Free bytes of each Radarr/Sonarr root folder; empty on any error."""
    try:
        return {r["path"].rstrip("/"): r.get("freeSpace") or 0 for r in arr(app).get("/rootfolder") or []}
    except BootstrapError:
        return {}


def seerr_sync_libraries(h):
    """Reads Jellyfin's libraries into Seerr and turns on the movie and series ones.

    Seerr 3.5 made this POST /library/sync and one PUT per library; GET ?sync=true
    and ?enable= answer 400 there ("Unknown query parameter 'sync'", 2026-10-21).
    Seerr 3.4 has only the GET form, so that stays as the fallback."""
    try:
        libs = h.post("/settings/jellyfin/library/sync", {})
    except BootstrapError as e:
        if "HTTP 404" not in str(e) and "HTTP 405" not in str(e):
            raise
        libs = h.get("/settings/jellyfin/library?sync=true")
        ids = ",".join(lib["id"] for lib in libs if lib.get("type") in ("movie", "show"))
        if ids:
            h.get(f"/settings/jellyfin/library?enable={ids}")
        return
    for lib in libs or []:
        if lib.get("type") in ("movie", "show") and not lib.get("enabled"):
            h.put(f"/settings/jellyfin/library/{lib['id']}", {"enabled": True})


def configure_seerr():
    wait_http("seerr", "http://seerr:5055/api/v1/status", accept=(200,))
    h = seerr()
    public = h.get("/settings/public")
    user, pw = SECRETS["admin_user"], SECRETS["admin_password"]
    login = {"username": user, "password": pw, "email": f"{user}@tortugarr.local"}
    # First sign-in with a server address makes the Jellyfin admin the Seerr owner.
    # If an earlier run got that far but stopped before `initialize`, Seerr refuses
    # the address a second time ("already configured") - then a plain login is right.
    signed_in = False
    if not public.get("initialized"):
        try:
            h.post("/auth/jellyfin", {**login, "hostname": "jellyfin", "port": 8096, "useSsl": False,
                                      "urlBase": "", "serverType": 2})
            ok("seerr: signed in with the Jellyfin admin (becomes the Seerr owner)")
            signed_in = True
        except BootstrapError as e:
            if "already configured" not in str(e):
                raise
            info("seerr: Jellyfin already linked by an earlier run - continuing")
    if not signed_in:
        h.post("/auth/jellyfin", {"username": user, "password": pw, "email": login["email"]})

    # Without an external address Seerr builds "Play" links to http://jellyfin:8096,
    # a container name no browser or TV can resolve.
    h.post("/settings/jellyfin", {"externalHostname": lan_url("jellyfin")})
    seerr_sync_libraries(h)
    ok("seerr: Jellyfin libraries synced")

    # Seerr 3 rejects read-only fields (apiKey, ...) in settings bodies, so only
    # the fields being changed are sent - here and below.
    h.post("/settings/main", {"applicationUrl": lan_url("seerr"), "applicationTitle": "Tortugarr"})
    # TMDB can be slow to answer; 10 s made some lookups fail.
    h.post("/settings/network", {"apiRequestTimeout": 30000})
    # Sonarr numbers episodes by TVDB, so anime requests match the right episodes when
    # Seerr uses TVDB for anime too. Seerr checks TVDB first; if it is unreachable now,
    # TMDB stays and repair tries again.
    try:
        meta = h.get("/settings/metadatas") or {}
        if meta.get("anime") != "tvdb":
            h.put("/settings/metadatas", {"tv": meta.get("tv", "tmdb"), "anime": "tvdb"})
        ok("seerr: anime metadata from TVDB (matches Sonarr), API timeout 30 s")
    except BootstrapError as e:
        warn(f"seerr: could not switch anime metadata to TVDB now ({str(e)[-120:]}) - 'tortugarr repair' tries again")

    for app, port in (("radarr", 7878), ("sonarr", 8989)):
        key = secret(f"{app}_api_key")
        test = h.post(f"/settings/{app}/test", {"hostname": app, "port": port, "apiKey": key,
                                                  "useSsl": False, "baseUrl": ""})
        profiles = test.get("profiles", [])
        roots = test.get("rootFolders", [])
        prof = next((p for p in profiles if p["name"] == STATE.get("default_quality_profile", "HD-1080p")), None) \
            or (profiles[0] if profiles else None)
        root = seerr_root(app, roots)
        if not prof or not root:
            raise BootstrapError(f"seerr: {app} returned no quality profile or root folder")
        body = {
            "name": app.capitalize(), "hostname": app, "port": port, "apiKey": key, "useSsl": False,
            "baseUrl": "", "activeProfileId": prof["id"], "activeProfileName": prof["name"],
            "activeDirectory": root["path"], "is4k": False, "isDefault": True,
            "externalUrl": lan_url(app), "syncEnabled": True, "preventSearch": False,
            "tags": [], "tagRequests": False,
        }
        if app == "radarr":
            body["minimumAvailability"] = "released"
        else:
            body.update({"activeLanguageProfileId": 1, "activeAnimeProfileId": prof["id"],
                         "activeAnimeProfileName": prof["name"], "activeAnimeDirectory": root["path"],
                         "enableSeasonFolders": True, "seriesType": "standard", "animeSeriesType": "anime"})
        current = [s for s in h.get(f"/settings/{app}") if not s.get("is4k")]
        if current:
            h.put(f"/settings/{app}/{current[0]['id']}", body)
            ok(f"seerr: {app} updated (profile {prof['name']}, {root['path']})")
        else:
            h.post(f"/settings/{app}", body)
            ok(f"seerr: {app} added (profile {prof['name']}, {root['path']})")

    if not public.get("initialized"):
        h.post("/settings/initialize")
        ok("seerr: setup marked complete")


def configure_moonfin_webhook():
    """Seerr tells the Moonfin plugin about requests (pending, approved, available ...)
    through a webhook. The plugin can register it itself, but only after an admin has
    signed in to Seerr from the app, so the installer does it right away."""
    if not STATE.get("moonfin_plugin", True):
        return
    jh, _ = jellyfin_login()
    guid = STATE["moonfin_plugin_guid"].replace("-", "")
    secret_value = jh.get(f"/Plugins/{guid}/Configuration").get("SeerrWebhookSecret")
    if not secret_value:
        raise BootstrapError("Moonfin plugin has no webhook secret yet - run repair")
    url = f"http://jellyfin:8096{MOONFIN_WEBHOOK_PATH}?secret={urllib.parse.quote(secret_value)}"
    h = seerr_login()
    cur = h.get("/settings/notifications/webhook") or {}
    existing = (cur.get("options") or {}).get("webhookUrl") or ""
    if existing and MOONFIN_WEBHOOK_PATH.lower() not in existing.lower():
        warn("seerr: a different webhook is already set up - left alone; Moonfin request updates stay off")
        return
    h.post("/settings/notifications/webhook", {
        "enabled": True,
        "types": int(cur.get("types") or 0) | MOONFIN_WEBHOOK_TYPES,
        "options": {"webhookUrl": url, "jsonPayload": MOONFIN_WEBHOOK_PAYLOAD, "authHeader": ""},
    })
    now = h.get("/settings/notifications/webhook")
    if not now.get("enabled") or now["options"].get("webhookUrl") != url:
        raise BootstrapError("seerr: webhook was not saved")
    ok("seerr: sends request updates to the Moonfin plugin")


# --------------------------------------------------------------------------- app config

def write_app_config():
    """Everything the Tortugarr app needs, for building it or for a future setup screen."""
    cfg = {
        "jellyfinUrl": lan_url("jellyfin"),
        "seerrUrl": lan_url("seerr"),
        "prowlarrBaseUrl": lan_url("prowlarr"),
        "prowlarrApiKey": secret("prowlarr_api_key"),
        "sonarrBaseUrl": lan_url("sonarr"),
        "sonarrApiKey": secret("sonarr_api_key"),
        "radarrBaseUrl": lan_url("radarr"),
        "radarrApiKey": secret("radarr_api_key"),
        "torrentClient": client_kind(),
    }
    if torrent_client() == "qbittorrent":
        cfg.update({"qbittorrentBaseUrl": lan_url("torrent_web"),
                    "qbittorrentUsername": SECRETS["admin_user"],
                    "qbittorrentPassword": SECRETS["admin_password"]})
    elif torrent_client() == "qbittorrent-ext":
        user, pw = download_client_login()
        cfg.update({"qbittorrentBaseUrl": external_qbit().get("url", ""),
                    "qbittorrentUsername": user, "qbittorrentPassword": pw})
    save_json(f"{INSTALL}/app-config.json", cfg)

    def dart(v):
        return json.dumps(v)

    lines = [
        "// Generated by the Tortugarr installer. DO NOT COMMIT.",
        "// PRIVATE BUILDS ONLY: an app built with this file carries your server's API keys and",
        "// download-client password. Never share or publish such an APK.",
        "// Copy to lib/data/services/download/download_now_secrets.dart before building the app.",
        "class DownloadNowSecrets {",
        f"  static const String prowlarrBaseUrl = {dart(cfg['prowlarrBaseUrl'])};",
        f"  static const String prowlarrApiKey = {dart(cfg['prowlarrApiKey'])};",
        f"  static const String sonarrBaseUrl = {dart(cfg['sonarrBaseUrl'])};",
        f"  static const String sonarrApiKey = {dart(cfg['sonarrApiKey'])};",
        f"  static const String qbittorrentBaseUrl = {dart(cfg.get('qbittorrentBaseUrl', ''))};",
        f"  static const String qbittorrentUsername = {dart(cfg.get('qbittorrentUsername', ''))};",
        f"  static const String qbittorrentPassword = {dart(cfg.get('qbittorrentPassword', ''))};",
        f"  static const String radarrBaseUrl = {dart(cfg['radarrBaseUrl'])};",
        f"  static const String radarrApiKey = {dart(cfg['radarrApiKey'])};",
        "}",
    ]
    path = f"{INSTALL}/download_now_secrets.dart"
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(path, 0o600)
    ok("app: app-config.json and download_now_secrets.dart written")


# --------------------------------------------------------------------------- commands

# Steps that cannot work when another step failed (Seerr signs in through Jellyfin; the
# plugin links need both).
STEP_NEEDS = {
    "seerr": ("jellyfin",),
    "tortugarr-seerr": ("jellyfin", "seerr"),
    "moonfin-webhook": ("jellyfin", "seerr"),
}
FAILED_STEPS = set()


def cmd_configure():
    steps = [("jellyfin", configure_jellyfin)]
    # Download clients first: the *arrs validate categories against them when added.
    client = torrent_client()
    if client == "qbittorrent":
        steps.append(("qbittorrent", configure_qbittorrent))
    elif client == "qbittorrent-ext":
        steps.append(("qbittorrent", configure_external_qbittorrent))
    elif client == "transmission":
        steps.append(("transmission", configure_transmission))
    elif client == "deluge":
        steps.append(("deluge", configure_deluge))
    if STATE.get("usenet"):
        steps.append(("sabnzbd", configure_sabnzbd))
    steps += [("sonarr", lambda: configure_arr("sonarr")), ("radarr", lambda: configure_arr("radarr")),
              ("prowlarr", configure_prowlarr), ("bazarr", configure_bazarr), ("seerr", configure_seerr),
              ("tortugarr-seerr", configure_tortugarr_seerr), ("moonfin-webhook", configure_moonfin_webhook), ("app", write_app_config)]
    only = os.environ.get("TORTUGARR_ONLY")
    failures = skipped = 0
    FAILED_STEPS.clear()
    for name, fn in steps:
        if only and name not in only.split(","):
            continue
        info(f"--- {name}")
        # A step whose base failed is skipped with that reason, not run into its own follow-on
        # errors (no Jellyfin admin -> Seerr 401, no webhook secret ...).
        failed_need = next((n for n in STEP_NEEDS.get(name, ()) if n in FAILED_STEPS), None)
        if failed_need:
            skipped += 1
            FAILED_STEPS.add(name)
            warn(f"{name}: skipped: {failed_need.capitalize()} setup failed")
            continue
        try:
            fn()
        except BootstrapError as e:
            failures += 1
            FAILED_STEPS.add(name)
            fail(f"{name}: {e}")
        except Exception as e:  # noqa: BLE001 - report and keep going with the other services
            failures += 1
            FAILED_STEPS.add(name)
            fail(f"{name}: unexpected {type(e).__name__}: {e}")
    if failures:
        extra = f", {skipped} skipped because of it" if skipped else ""
        fail(f"configure finished with {failures} failed step(s){extra} - run 'sudo tortugarr repair'")
        return 1
    ok("configure complete")
    return 0


def check(name, fn):
    try:
        msg = fn()
        ok(f"{name}: {msg}" if msg else name)
        return True
    except BootstrapError as e:
        fail(f"{name}: {e}")
    except Exception as e:  # noqa: BLE001
        fail(f"{name}: {type(e).__name__}: {e}")
    return False


def cmd_doctor():
    bad = 0

    def arr_health(app):
        h = arr(app)
        st = h.get("/system/status")
        # Health results are cached; re-run them so a client added a minute ago counts.
        try:
            cmd = h.post("/command", {"name": "CheckHealth"})
            for _ in range(15):
                if h.get(f"/command/{cmd['id']}").get("status") in ("completed", "failed"):
                    break
                time.sleep(1)
        except BootstrapError:
            pass
        issues = [i for i in h.get("/health") if i.get("type") in ("error", "warning")
                  and "update is available" not in i.get("message", "").lower()]
        real = 0
        for i in issues:
            msg = i.get("message", "")
            if "indexer" in msg.lower():
                # Expected until the user adds indexers in Prowlarr; said once, below.
                continue
            real += 1
            (fail if i["type"] == "error" else warn)(f"{app}: {msg}")
            if i["type"] == "error":
                raise BootstrapError(msg)
        return f"v{st['version']} API ok" + (f", {real} warning(s)" if real else "")

    def arr_clients(app):
        h = arr(app)
        msgs = []
        for c in h.get("/downloadclient"):
            try:
                h.post("/downloadclient/test", c)
                msgs.append(f"{c['name']} reachable")
            except BootstrapError as e:
                raise BootstrapError(f"download client {c['name']} test failed: {e}")
        return ", ".join(msgs) or "no download client configured"

    for app in ("sonarr", "radarr", "prowlarr"):
        bad += not check(f"{app} api", lambda a=app: arr_health(a))
    try:
        if not arr("prowlarr").get("/indexer"):
            warn("no indexers yet: nothing can be searched or downloaded until you add indexers in Prowlarr")
            important(CLOUDFLARE_TIP)
    except BootstrapError:
        pass
    for app in ("sonarr", "radarr"):
        bad += not check(f"{app} download client", lambda a=app: arr_clients(a))

    def path_mappings(app):
        """Every remote path mapping must land in a folder the container can see; one that does
        not leaves finished downloads stuck with "No files found are eligible for import"."""
        h = arr(app)
        maps = h.get("/remotepathmapping")
        if not maps:
            if torrent_client() == "qbittorrent-ext":
                raise BootstrapError("no remote path mapping for your qBittorrent - run repair")
            return "none needed"
        mounted = [x["container_path"].rstrip("/") for x in external_qbit().get("mounts", [])]
        bad_maps = []
        for m in maps:
            local = m["localPath"].rstrip("/")
            if mounted and not any(local == c or local.startswith(c + "/") for c in mounted):
                bad_maps.append(f"{m['remotePath']} -> {m['localPath']} (outside the folders mounted from your qBittorrent)")
                continue
            parent = local.rsplit("/", 1)[0] or "/"
            listing = h.get(f"/filesystem?path={urllib.parse.quote(parent + '/')}&includeFiles=false"
                            f"&allowFoldersWithoutTrailingSlashes=true")
            if not any(d.get("path", "").rstrip("/") == local for d in listing.get("directories", [])):
                bad_maps.append(f"{m['remotePath']} -> {m['localPath']}")
        if bad_maps:
            raise BootstrapError("mapped to a folder this container cannot see: " + "; ".join(bad_maps)
                                 + " - run repair, or fix the mapping in " + app.capitalize())
        return f"{len(maps)} mapping(s), all visible"

    def client_matches(app):
        """Radarr/Sonarr download to the client Tortugarr set up. A client switched by hand (the
        container stopped for a qBittorrent on the host) needs reconfigure, which mounts that
        client's folders and maps its paths; otherwise its downloads are never imported."""
        if torrent_client() in ("none", "qbittorrent-ext"):
            return "ok"
        want = client_host(torrent_client())
        hosts = {next((f.get("value") for f in c.get("fields", []) if f.get("name") == "host"), "")
                 for c in arr(app).get("/downloadclient")
                 if c.get("enable") and c.get("implementation") == CLIENT_IMPL[torrent_client()]}
        other = sorted(h for h in hosts if h and h != want)
        if other:
            raise BootstrapError(f"downloads go to {', '.join(other)}, not to Tortugarr's {torrent_client()} "
                                 f"({want}). If that is your own qBittorrent, run: sudo tortugarr reconfigure "
                                 f"and choose the qBittorrent you already have")
        return f"{want}"

    def root_folders(app):
        """Root folders outside the ones Tortugarr gives this app (a folder of another type, or one
        not mounted into it) are never picked for new titles; titles already there keep working
        only if the folder is really there. Reported, never removed."""
        allowed = {p.rstrip("/") for p in arr_roots(app)}
        odd = [r["path"] for r in arr(app).get("/rootfolder") if r["path"].rstrip("/") not in allowed]
        if odd:
            warn(f"{app}: root folder(s) {', '.join(odd)} are not {app.capitalize()} folders in Tortugarr's setup "
                 f"(another type, or not mounted there) - new titles do not go there. Move their titles in "
                 f"{app.capitalize()} (Movies/Series > Edit > Root Folder) and remove the folder there")
        return f"{len(allowed)} in use"

    for app in ("sonarr", "radarr"):
        bad += not check(f"{app} root folders", lambda a=app: root_folders(a))
        bad += not check(f"{app} path mappings", lambda a=app: path_mappings(a))
        bad += not check(f"{app} uses Tortugarr's download client", lambda a=app: client_matches(a))

    def jf():
        h, r = jellyfin_login()
        i = h.get("/System/Info")
        libs = h.get("/Library/VirtualFolders")
        versions = [(p.get("Version"), p.get("Status")) for p in jellyfin_plugin_versions(h)]
        moon = "missing"
        if versions:
            moon = ", ".join(f"{v} {st}" for v, st in versions)
        if STATE.get("moonfin_plugin", True) and not any(
            st == "Active" and moonfin_plugin_recent_enough(v) for v, st in versions
        ):
            warn(f"jellyfin: Moonfin plugin {moonfin_plugin_min_version()} or newer not active ({moon}) - run repair")
        return f"v{i['Version']}, admin login ok, {len(libs)} libraries, Moonfin plugin {moon}"

    bad += not check("jellyfin", jf)

    def tp():
        h, _ = jellyfin_login()
        caps = h.get("/Tortugarr/v1/Capabilities")
        # The adult library is off until an administrator switches it on - not a fault.
        off = [k for k, v in (caps.get("features") or {}).items() if not v and k != "adult"]
        if off:
            raise BootstrapError(f"features off for the admin: {', '.join(off)} - run repair")
        adult = "on" if (caps.get("features") or {}).get("adult") else "off (switch it on in the plugin's page if wanted)"
        conf = h.get(f"/Plugins/{TORTUGARR_PLUGIN_GUID}/Configuration")
        if not (conf.get("SeerrUrl") and conf.get("SeerrApiKey")):
            raise BootstrapError("not linked to Seerr (deletes would leave titles 'available' there) - run repair")
        return f"plugin {caps.get('pluginVersion')}, all features on for administrators, linked to Seerr; adult library {adult}"

    if tortugarr_plugin_dist():
        bad += not check("tortugarr plugin", tp)

    def sr():
        st = Http("http://seerr:5055/api/v1").get("/status")
        pub = Http("http://seerr:5055/api/v1").get("/settings/public")
        if not pub.get("initialized"):
            raise BootstrapError("setup not completed")
        msg = f"v{st.get('version')} initialized"
        if STATE.get("moonfin_plugin", True):
            hook = (seerr_login().get("/settings/notifications/webhook") or {})
            target = (hook.get("options") or {}).get("webhookUrl") or ""
            if hook.get("enabled") and target.startswith("http://jellyfin:8096" + MOONFIN_WEBHOOK_PATH):
                msg += ", request updates go to the Moonfin plugin"
            else:
                warn("seerr: request updates do not reach the Moonfin plugin - run repair")
        return msg

    bad += not check("seerr", sr)

    def bz():
        h = bazarr()
        st = h.get("/system/status")
        s = h.get("/system/settings")
        if not (s["general"]["use_sonarr"] and s["general"]["use_radarr"]):
            raise BootstrapError("not linked to Sonarr/Radarr - run repair")
        return f"v{st.get('data', st).get('bazarr_version', '?')}, linked to Sonarr and Radarr"

    bad += not check("bazarr", bz)
    ok("doctor api checks done") if not bad else fail(f"{bad} api check(s) failed")
    return 1 if bad else 0


def cmd_backup_db():
    """Online, consistent copies of every SQLite database under /cfg into $DEST."""
    dest = os.environ.get("DEST", f"{INSTALL}/backups/.db-snapshot")
    n = 0
    for root, _, files in os.walk(CFG):
        if "/cache" in root or "/logs" in root or "/log" in root.split(CFG, 1)[1]:
            continue
        for f in files:
            if not (f.endswith(".db") or f.endswith(".sqlite3") or f.endswith(".sqlite")) or f.startswith("logs."):
                continue
            src = os.path.join(root, f)
            rel = os.path.relpath(src, CFG)
            dst = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            try:
                with sqlite3.connect(f"file:{src}?mode=ro", uri=True, timeout=30) as s, sqlite3.connect(dst) as d:
                    s.backup(d)
                with sqlite3.connect(dst) as d:
                    res = d.execute("PRAGMA integrity_check").fetchone()[0]
                (ok if res == "ok" else fail)(f"db {rel}: {res}")
                n += 1
            except sqlite3.Error as e:
                fail(f"db {rel}: {e}")
    ok(f"{n} database(s) snapshotted")
    return 0


def cmd_summary():
    s = STATE
    user, pw = SECRETS.get("admin_user"), SECRETS.get("admin_password")
    rows = [("Jellyfin", "jellyfin"), ("Seerr (requests)", "seerr"), ("Sonarr (TV)", "sonarr"),
            ("Radarr (movies)", "radarr"), ("Prowlarr (indexers)", "prowlarr"),
            ("Bazarr (subtitles)", "bazarr")]
    if torrent_client() not in ("none", "qbittorrent-ext"):
        rows.append((torrent_client().capitalize(), "torrent_web"))
    if s.get("usenet"):
        rows.append(("SABnzbd", "sabnzbd"))
    for label, key in rows:
        print(f"URL\t{label}\t{lan_url(key)}")
    if torrent_client() == "qbittorrent-ext":
        print(f"URL\tqBittorrent (yours)\t{external_qbit().get('url', '')}")
    print(f"CRED\tusername\t{user}")
    print(f"CRED\tpassword\t{pw}")
    # Things only the user can do, repeated until they are done.
    try:
        if not arr("prowlarr").get("/indexer"):
            print(f"NOTE\tno_indexers\t{lan_url('prowlarr')}")
    except BootstrapError:
        pass
    if s.get("vpn") and torrent_client() not in ("none", "qbittorrent-ext"):
        vpn_env = {}
        try:
            with open(f"{INSTALL}/overrides/vpn.env") as f:
                vpn_env = dict(l.strip().split("=", 1) for l in f if "=" in l and not l.startswith("#"))
        except OSError:
            pass
        if not (vpn_env.get("WIREGUARD_PRIVATE_KEY") or vpn_env.get("OPENVPN_USER")):
            print(f"NOTE\tvpn_incomplete\t{s['install_dir']}/overrides/vpn.env")
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    commands = {"preseed": lambda: cmd_preseed() or 0, "configure": cmd_configure, "doctor": cmd_doctor,
                "backup-db": cmd_backup_db, "summary": cmd_summary}
    cmd = commands.get(sys.argv[1])
    if cmd is None:
        print(f"unknown command {sys.argv[1]}")
        return 2
    try:
        load_state()
        return cmd()
    except BootstrapError as e:
        fail(str(e))
        return 1


if __name__ == "__main__":
    sys.exit(main())
