# Tests

End-to-end tests run on a **clean virtual machine** (Hyper-V, VirtualBox, a cloud VM),
never in a container next to a running media stack: on WSL2 every distro shares one
network, so a test install there can collide with a real installation's ports, Docker
networks and firewall rules. Reset the VM to a clean snapshot before every run.

```bash
# On the clean VM (Ubuntu 24.04), with this folder copied to ~/tortugarr-server:
cd ~/tortugarr-server && sudo ./install.sh install --answers tests/answers.lab.env   # test-only login inside
```

Checks that need no installation run anywhere:

```bash
for f in install.sh lib/*.sh i18n/*.sh tests/*.sh; do bash -n "$f"; done
python3 -m py_compile bootstrap/tortugarr_bootstrap.py
python3 -I tests/unit/test_jellyfin_start.py    # slow Jellyfin start: wait, 503 retries, skipped steps
tests/windows/crash-test.sh                     # Windows helper on a fake Windows (PowerShell 7 for Linux)
```

| Script | Proves |
|---|---|
| `e2e-seerr-request.sh` | A request in Seerr lands in Radarr with the right profile and folder |
| `e2e-download.sh` + `e2e-manual-import.sh` | Radarr -> qBittorrent -> hardlinked import -> Jellyfin, with a freely licensed torrent (Big Buck Bunny, CC-BY) |
| `e2e-backup-restore.sh` | Backup, damage settings, restore: the settings come back and the doctor is green |
| `test-vpn-render.sh` | The gluetun override is valid for every torrent client (client inside the VPN, no own ports) |
| `reconf-*.env` | Answers for `tortugarr reconfigure`: switch between qBittorrent, Transmission and Deluge, usenet on/off, extra library folder |

Also exercised: resuming a half-finished install, `repair` after partial failures,
`update` with automatic backup, `update` rollback with a deliberately broken image,
`uninstall --purge` (media left intact, backup kept in `/var/backups/tortugarr`), and
a fresh install that is fully green on the first run.

