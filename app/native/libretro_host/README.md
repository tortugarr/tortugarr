# libretro host

Portable C host that runs one libretro core. Shared by the Android app and the
Windows, macOS, and Linux runners so the emulation core, run loop, pixel
conversion, audio ring, save states, options, and SRAM live in one place. It
ports the tvOS bridge in `tvos/Runner/Games/` to platforms where cores are
downloaded rather than bundled.

## What the host owns

- Loading the core (RTLD_LOCAL / LoadLibrary so duplicate `retro_*` symbols stay
  isolated) and resolving its entry points.
- The environment callback, mirroring the tvOS `GameSession` switch: pixel
  format, system and save directories, legacy `SET_VARIABLES` options, geometry.
- A run-loop thread with two pacing modes: wall clock by default, or audio-buffer
  paced once the platform's audio device is pulling (`lh_set_audio_paced`), so
  audio drives frame timing.
- Converting the core's 0RGB1555 / XRGB8888 / RGB565 output into RGBA or BGRA in
  a double buffer, pulled with `lh_get_frame`.
- An interleaved S16 audio ring, drained by `lh_read_audio`.
- Save states, core options, and periodic SRAM flushes, run between frames so
  they never race `retro_run`.

libretro's C callbacks carry no user pointer, so only one host runs per process.

## What the platform provides

Through `lh_callbacks`: a frame-ready signal, a per-port RetroPad input poll, a
controller count, and a geometry-changed notification. The platform also creates
the texture the frame is copied into and the audio device that calls
`lh_read_audio`. See `libretro_host.h` for the full API.

## Build

CMake, linked into each runner:

```
add_subdirectory(native/libretro_host)
target_link_libraries(<runner> PRIVATE libretro_host)
```

## Self-test

A stub core and a headless harness exercise loading, the environment callback,
the run loop, pixel conversion for both output formats, input, audio, options,
and a save-state round trip.

```
cmake -S native/libretro_host -B build -DLIBRETRO_HOST_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

Without CMake, compile directly:

```
cc -std=c11 -Wall -Wextra -c native/libretro_host/libretro_host.c -o host.o
cc -std=c11 -shared -fPIC native/libretro_host/test/stub_core.c -o stub.so
cc -std=c11 native/libretro_host/test/test_harness.c host.o -o harness
./harness ./stub.so /tmp
```

The harness prints `PASS` with no failures, and runs clean under
`-fsanitize=address,undefined` and `-fsanitize=thread`.
