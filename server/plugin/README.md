# Tortugarr Jellyfin plugin

Server side of the Tortugarr app's Download Now, downloads, disk space, video check and
subtitles, so the app never holds a Sonarr/Radarr/Prowlarr/Bazarr key. Contract:
[docs/design/tortugarr-plugin-api.md](../docs/design/tortugarr-plugin-api.md).

Build and test (.NET 10 SDK; Jellyfin 12 packages are provided by the server at run time):

```bash
dotnet test tests/Tortugarr.Tests
dotnet publish Jellyfin.Plugin.Tortugarr -c Release -o out
```
