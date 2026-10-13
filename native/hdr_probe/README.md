# HDR probe

Standalone Windows tool that checks the exact `libmpv-2.dll` Moonfin ships can
drive native HDR output: renderer options (Q1), post-init `wid` (Q2), and HDR
actually reaching the display (Q3). Run it against a new DLL after a
`libmpv-2.dll` upgrade, before trusting it with the native HDR path.

## Build

Needs Visual Studio (the same toolchain `build-windows.ps1` already requires).

```powershell
cmake -S native/hdr_probe -B build/hdr_probe
cmake --build build/hdr_probe --config Release
```

The binary lands at `build\hdr_probe\Release\hdr_probe.exe`.

## Run

`libmpv-2.dll` is downloaded by the `media_kit_libs_windows_video` fork during a
Flutter build and installed next to the app. Either path works:

```
build\windows\x64\libmpv\libmpv-2.dll
build\windows\x64\runner\Release\libmpv-2.dll
```

Q1 and Q2 need no media and no HDR display:

```powershell
.\build\hdr_probe\Release\hdr_probe.exe --libmpv build\windows\x64\libmpv\libmpv-2.dll
```

Q3 needs a real HDR10 file **and the display already switched into HDR mode**
(Settings → System → Display → Use HDR):

```powershell
.\build\hdr_probe\Release\hdr_probe.exe `
  --libmpv build\windows\x64\libmpv\libmpv-2.dll `
  --media "D:\media\some-hdr10-movie.mkv" `
  --seconds 20
```

A window opens and plays for the requested duration. Watch the display's own
HDR indicator while it does.

## What each question decides

### Q1 — renderer options

Does this libmpv have `vo=gpu-next`, `gpu-api=d3d11` and
`target-colorspace-hint`? Options are validated at parse time, so a build
without libplacebo fails here rather than at runtime.

- **All three PASS** → the shipped DLL is sufficient, no libmpv work needed.
- **`gpu-next` FAILs** → the fork needs a newer shinchiro build in
  `media_kit_libs_windows_video`.

### Q2 — when can `wid` be set?

media_kit applies every property *after* `mpv_initialize` (`real.dart:2319-2364`
is its only pre-init block).

- **Post-init property PASSes** → the Android TV pattern ports directly:
  `vo=null` at init, then `wid` + `vo=gpu-next` once the HWND exists. No
  media-kit change.
- **Post-init FAILs, pre-init PASSes** → `PlayerConfiguration` needs an
  `extraOptions` passthrough in the media-kit fork. Cheap, since
  `media_kit_video` and `media_kit_libs_windows_video` are already forked at the
  same ref — `media_kit` itself would need adding to `dependency_overrides`.

### Q3 — does HDR reach the display?

Reads the negotiated parameters and greps mpv's verbose log for the D3D11
swapchain lines.

**Passing** looks like:

- `video-params/gamma` → `pq` (or `hlg`)
- `video-params/primaries` → `bt.2020`
- a d3d11 log line showing a 10-bit or fp16 swapchain in a BT.2020/PQ colorspace
- the display's HDR indicator engaging

**Failing** looks like `gamma` coming back as `bt.1886`, or an 8-bit swapchain —
that means mpv tone-mapped to SDR and the DLL is not fit for the native path.
