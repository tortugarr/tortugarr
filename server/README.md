# Tortugarr server

The server side of Tortugarr, version 4.20.0 (the same version as the app):

- **The installer** (`install.sh`, `lib/`, `bootstrap/`, `compose/`, `i18n/`): one command that
  sets up Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr and a download client on a Linux
  machine, wires them together and keeps them running. Users install from a tar file made from
  this folder - see [docs/install.md](docs/install.md) for what it does and how to use it.
- **The Tortugarr Jellyfin plugin** (`plugin/`): the server side of the app's Download Now,
  delete, subtitles and free-space features, so the app holds no keys. Its contract with the
  app: [docs/design/tortugarr-plugin-api.md](docs/design/tortugarr-plugin-api.md).
- **The Windows helper** (`windows/`): optional, for an install inside WSL2 (not supported,
  best effort).

## Build the plugin

Needs the .NET 10 SDK. Runs the unit tests, then builds `plugin/dist/Tortugarr_<version>/`
(the DLL, its `meta.json` and the logo), which the installer copies into Jellyfin:

```bash
plugin/build.sh
```

`plugin/dist/` is not kept in git; the installer warns and leaves Download Now off when it is
missing.

## Make the tar file users install from

From the folder above this one, after building the plugin:

```bash
server/plugin/build.sh
tar -cf tortugarr-server-4.20.0.tar --exclude=bin --exclude=obj \
    --transform 's,^server,tortugarr-server,' server
```

Users then run:

```bash
tar -xf tortugarr-server-4.20.0.tar
cd tortugarr-server
sudo ./install.sh
```

## Tests

Without an install: `bash -n` on the shell files, `python3 -I tests/unit/test_jellyfin_start.py`,
the plugin's unit tests (in `plugin/build.sh`), and `tests/windows/crash-test.sh` (the Windows
helper against a fake Windows, PowerShell 7 for Linux). With an install, on a clean test VM
only: see [tests/README.md](tests/README.md). The answers files in `tests/` hold a throwaway
test login - never use them for a real server.

## License

GNU General Public License v2 - see [LICENSE](LICENSE). Please read
[DISCLAIMER.md](DISCLAIMER.md).
