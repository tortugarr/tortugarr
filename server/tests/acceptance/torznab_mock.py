#!/usr/bin/env python3
"""A tiny Torznab indexer for the acceptance test: it lists the test releases in
/seed/torrents (served by the test's web seed) and nothing else.

Prowlarr adds it as a "Generic Torznab" indexer and syncs it to Sonarr and Radarr, so a
request in Seerr is found and grabbed the normal way - by an automatic search - without
any public tracker. Standard library only; listens on port 8080.
"""
import email.utils
import http.server
import os
import re
import urllib.parse
from xml.sax.saxutils import escape

SEED = "/seed"
SEED_URL = "http://tortugarr-test-seed"

CAPS = """<?xml version="1.0" encoding="UTF-8"?>
<caps>
  <server title="Tortugarr acceptance test indexer"/>
  <limits max="100" default="100"/>
  <searching>
    <search available="yes" supportedParams="q"/>
    <tv-search available="yes" supportedParams="q,season,ep"/>
    <movie-search available="yes" supportedParams="q"/>
  </searching>
  <categories>
    <category id="2000" name="Movies"/>
    <category id="5000" name="TV"/>
    <category id="6000" name="XXX"/>
  </categories>
</caps>
"""


def releases():
    for name in sorted(os.listdir(f"{SEED}/files")):
        rel = os.path.splitext(name)[0]
        size = os.path.getsize(f"{SEED}/files/{name}")
        cat = 6000 if rel.startswith("Adult-Test.") else 5000 if re.search(r"\bS\d\dE\d\d\b", rel, re.I) else 2000
        yield rel, name, size, cat


def words(s):
    return [w for w in re.split(r"[^a-z0-9]+", s.lower()) if w]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        t = q.get("t", ["search"])[0]
        if t == "caps":
            return self.reply(CAPS)
        want = words(q.get("q", [""])[0])
        season, ep = q.get("season", [""])[0], q.get("ep", [""])[0]
        cats = {int(c) // 1000 * 1000 for c in ",".join(q.get("cat", [])).split(",") if c.isdigit()}
        now = email.utils.formatdate(usegmt=True)
        items = []
        for rel, name, size, cat in releases():
            have = words(rel)
            if want and not all(w in have for w in want):
                continue
            if cats and cat not in cats:
                continue
            if season and not re.search(rf"\bS0*{int(season)}E", rel, re.I):
                continue
            if ep and not re.search(rf"E0*{int(ep)}\b", rel, re.I):
                continue
            url = escape(f"{SEED_URL}/torrents/{name}.torrent")
            items.append(
                f"<item><title>{escape(rel)}</title><guid>{escape(rel)}</guid><link>{url}</link>"
                f"<pubDate>{now}</pubDate><size>{size}</size>"
                f'<enclosure url="{url}" length="{size}" type="application/x-bittorrent"/>'
                f'<torznab:attr name="category" value="{cat}"/>'
                f'<torznab:attr name="seeders" value="10"/><torznab:attr name="peers" value="10"/></item>')
        self.reply('<?xml version="1.0" encoding="UTF-8"?>'
                   '<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2015/feed">'
                   '<channel><title>Tortugarr acceptance test indexer</title>' + "".join(items) +
                   "</channel></rss>")

    def reply(self, body):
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/xml; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    http.server.ThreadingHTTPServer((os.environ.get("BIND", ""), port), Handler).serve_forever()
