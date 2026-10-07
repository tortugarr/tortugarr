#!/usr/bin/env python3
"""Make a single-file .torrent whose only source is an HTTP web seed (BEP 19).

  make_torrent.py <file> <web-seed base URL ending in /> <output.torrent>

No tracker and no peers are needed: the client fetches the pieces from the web seed,
which the acceptance test runs inside the test machine. Standard library only.
"""
import hashlib
import os
import sys

PIECE = 1 << 18  # 256 KiB


def bencode(v):
    if isinstance(v, int):
        return b"i%de" % v
    if isinstance(v, str):
        v = v.encode()
    if isinstance(v, bytes):
        return b"%d:%s" % (len(v), v)
    if isinstance(v, list):
        return b"l" + b"".join(bencode(x) for x in v) + b"e"
    if isinstance(v, dict):
        return b"d" + b"".join(bencode(k) + bencode(v[k]) for k in sorted(v)) + b"e"
    raise TypeError(type(v))


def main():
    path, seed, out = sys.argv[1:4]
    pieces = []
    with open(path, "rb") as f:
        while chunk := f.read(PIECE):
            pieces.append(hashlib.sha1(chunk).digest())
    info = {"name": os.path.basename(path), "length": os.path.getsize(path),
            "piece length": PIECE, "pieces": b"".join(pieces)}
    with open(out, "wb") as f:
        f.write(bencode({"info": info, "url-list": [seed], "created by": "tortugarr acceptance test"}))
    print(hashlib.sha1(bencode(info)).hexdigest())


if __name__ == "__main__":
    main()
