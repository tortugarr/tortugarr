// Phase 0 go/no-go probe for native HDR video output on Windows.
//
// Answers three of the four gate questions from the HDR plan against the exact
// libmpv-2.dll that Moonfin ships, without needing the Flutter app:
//
//   Q1  Does this libmpv build have vo=gpu-next, gpu-api=d3d11 and
//       target-colorspace-hint?
//   Q2  Is `wid` settable after mpv_initialize, or does it have to go in
//       before init (which would mean patching the media-kit fork)?
//   Q3  With mpv owning a real HWND and a D3D11 swapchain, does HDR actually
//       reach the display?
//
// Q4 (per-pixel alpha on the Flutter window over this one) is a Flutter-side
// question and is not covered here.
//
// libmpv is loaded dynamically, so no import library or headers are required.
// The declarations below mirror libmpv/client.h; that ABI is versioned and
// stable, and mpv_client_api_version() is checked at startup.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

// ---------------------------------------------------------------------------
// Minimal libmpv ABI
// ---------------------------------------------------------------------------

struct mpv_handle;

enum mpv_event_id {
  MPV_EVENT_NONE = 0,
  MPV_EVENT_SHUTDOWN = 1,
  MPV_EVENT_LOG_MESSAGE = 2,
  MPV_EVENT_START_FILE = 6,
  MPV_EVENT_END_FILE = 7,
  MPV_EVENT_FILE_LOADED = 8,
  MPV_EVENT_VIDEO_RECONFIG = 17,
  MPV_EVENT_PLAYBACK_RESTART = 21,
};

struct mpv_event {
  mpv_event_id event_id;
  int error;
  uint64_t reply_userdata;
  void* data;
};

struct mpv_event_log_message {
  const char* prefix;
  const char* level;
  const char* text;
  int log_level;
};

typedef unsigned long (*fn_client_api_version)(void);
typedef mpv_handle* (*fn_create)(void);
typedef int (*fn_initialize)(mpv_handle*);
typedef void (*fn_terminate_destroy)(mpv_handle*);
typedef int (*fn_set_option_string)(mpv_handle*, const char*, const char*);
typedef int (*fn_set_property_string)(mpv_handle*, const char*, const char*);
typedef char* (*fn_get_property_string)(mpv_handle*, const char*);
typedef void (*fn_free)(void*);
typedef int (*fn_command)(mpv_handle*, const char**);
typedef int (*fn_request_log_messages)(mpv_handle*, const char*);
typedef mpv_event* (*fn_wait_event)(mpv_handle*, double);
typedef const char* (*fn_error_string)(int);

struct Mpv {
  HMODULE dll = nullptr;
  fn_client_api_version client_api_version = nullptr;
  fn_create create = nullptr;
  fn_initialize initialize = nullptr;
  fn_terminate_destroy terminate_destroy = nullptr;
  fn_set_option_string set_option_string = nullptr;
  fn_set_property_string set_property_string = nullptr;
  fn_get_property_string get_property_string = nullptr;
  fn_free free = nullptr;
  fn_command command = nullptr;
  fn_request_log_messages request_log_messages = nullptr;
  fn_wait_event wait_event = nullptr;
  fn_error_string error_string = nullptr;
};

static Mpv g_mpv;

template <typename T>
static bool Resolve(T& slot, const char* name) {
  slot = reinterpret_cast<T>(GetProcAddress(g_mpv.dll, name));
  if (!slot) {
    std::printf("  FAIL  missing export: %s\n", name);
    return false;
  }
  return true;
}

static bool LoadMpv(const std::wstring& path) {
  g_mpv.dll = LoadLibraryW(path.c_str());
  if (!g_mpv.dll) {
    std::printf("  FAIL  LoadLibrary failed (error %lu)\n", GetLastError());
    return false;
  }
  bool ok = true;
  ok &= Resolve(g_mpv.client_api_version, "mpv_client_api_version");
  ok &= Resolve(g_mpv.create, "mpv_create");
  ok &= Resolve(g_mpv.initialize, "mpv_initialize");
  ok &= Resolve(g_mpv.terminate_destroy, "mpv_terminate_destroy");
  ok &= Resolve(g_mpv.set_option_string, "mpv_set_option_string");
  ok &= Resolve(g_mpv.set_property_string, "mpv_set_property_string");
  ok &= Resolve(g_mpv.get_property_string, "mpv_get_property_string");
  ok &= Resolve(g_mpv.free, "mpv_free");
  ok &= Resolve(g_mpv.command, "mpv_command");
  ok &= Resolve(g_mpv.request_log_messages, "mpv_request_log_messages");
  ok &= Resolve(g_mpv.wait_event, "mpv_wait_event");
  ok &= Resolve(g_mpv.error_string, "mpv_error_string");
  return ok;
}

static const char* Err(int code) {
  return code >= 0 ? "ok" : g_mpv.error_string(code);
}

// ---------------------------------------------------------------------------
// Host window
// ---------------------------------------------------------------------------

static const wchar_t kWindowClass[] = L"MoonfinHdrProbe";

static HWND CreateHostWindow() {
  WNDCLASSW wc = {};
  wc.lpfnWndProc = DefWindowProcW;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kWindowClass;
  wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  RegisterClassW(&wc);

  HWND hwnd = CreateWindowExW(
      0, kWindowClass, L"Moonfin HDR probe", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
      CW_USEDEFAULT, 1280, 720, nullptr, nullptr, wc.hInstance, nullptr);
  if (hwnd) {
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
  }
  return hwnd;
}

static void PumpWindowMessages() {
  MSG msg;
  while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
}

// ---------------------------------------------------------------------------
// Q1 — option availability
// ---------------------------------------------------------------------------

// Options are validated when they are parsed, so a build without libplacebo
// rejects vo=gpu-next here rather than failing later at runtime.
static void ProbeOptions() {
  std::printf("\n=== Q1  Renderer options in this libmpv build ===\n\n");

  struct Probe {
    const char* key;
    const char* value;
    const char* why;
  };
  const Probe probes[] = {
      {"vo", "gpu-next", "libplacebo renderer - REQUIRED for HDR passthrough"},
      {"vo", "gpu", "old renderer, what the texture path uses today"},
      {"gpu-api", "d3d11", "D3D11 context - REQUIRED, owns the swapchain"},
      {"gpu-api", "vulkan", "alternative context that also supports the hint"},
      {"target-colorspace-hint", "yes", "tags the swapchain - REQUIRED"},
      {"target-colorspace-hint", "auto", "newer tri-state form of the above"},
      {"tone-mapping", "bt.2390", "tone curve used when falling back to SDR"},
      {"hdr-compute-peak", "yes", "dynamic peak detection"},
      {"target-contrast", "inf", "black point handling on OLED"},
      {"dither-depth", "auto", "banding control (media_kit ships dither=no)"},
  };

  for (const Probe& p : probes) {
    mpv_handle* ctx = g_mpv.create();
    if (!ctx) {
      std::printf("  FAIL  mpv_create returned null\n");
      return;
    }
    int rc = g_mpv.set_option_string(ctx, p.key, p.value);
    std::printf("  %-5s %s=%-22s  %-52s %s\n", rc >= 0 ? "PASS" : "FAIL", p.key,
                p.value, p.why, rc >= 0 ? "" : Err(rc));
    g_mpv.terminate_destroy(ctx);
  }
}

// ---------------------------------------------------------------------------
// Q2 — when can `wid` be set?
// ---------------------------------------------------------------------------

// This decides whether the media-kit fork needs a pre-init options map.
// media_kit applies every property AFTER mpv_initialize (real.dart:2319-2364
// is its only pre-init block), so if `wid` is init-only, the fork has to carry
// a PlayerConfiguration.extraOptions passthrough.
static void ProbeWid(HWND hwnd) {
  std::printf("\n=== Q2  Can `wid` be set after mpv_initialize? ===\n\n");

  char wid_str[32];
  std::snprintf(wid_str, sizeof(wid_str), "%lld",
                static_cast<long long>(reinterpret_cast<intptr_t>(hwnd)));

  // Control: as a pre-init option, which is how mpv documents it.
  {
    mpv_handle* ctx = g_mpv.create();
    int rc = g_mpv.set_option_string(ctx, "wid", wid_str);
    std::printf("  %-5s wid as pre-init option            %s\n",
                rc >= 0 ? "PASS" : "FAIL", rc >= 0 ? "" : Err(rc));
    g_mpv.terminate_destroy(ctx);
  }

  // The case that matters: after init, the way media_kit would do it.
  {
    mpv_handle* ctx = g_mpv.create();
    g_mpv.set_option_string(ctx, "vo", "null");
    g_mpv.set_option_string(ctx, "force-window", "yes");
    int init_rc = g_mpv.initialize(ctx);
    if (init_rc < 0) {
      std::printf("  FAIL  mpv_initialize: %s\n", Err(init_rc));
      g_mpv.terminate_destroy(ctx);
      return;
    }
    int rc = g_mpv.set_property_string(ctx, "wid", wid_str);
    std::printf("  %-5s wid as post-init property         %s\n",
                rc >= 0 ? "PASS" : "FAIL", rc >= 0 ? "" : Err(rc));

    int vo_rc = g_mpv.set_property_string(ctx, "vo", "gpu-next");
    std::printf("  %-5s vo=gpu-next swap after init       %s\n",
                vo_rc >= 0 ? "PASS" : "FAIL", vo_rc >= 0 ? "" : Err(vo_rc));

    if (rc < 0) {
      std::printf(
          "\n  => `wid` is init-only. The media-kit fork needs a pre-init\n"
          "     options passthrough on PlayerConfiguration.\n");
    } else {
      std::printf(
          "\n  => `wid` is runtime-settable. The Android TV pattern ports\n"
          "     directly: vo=null at init, then wid + vo once the HWND exists.\n");
    }
    g_mpv.terminate_destroy(ctx);
  }
}

// ---------------------------------------------------------------------------
// Q3 — does HDR reach the display?
// ---------------------------------------------------------------------------

static bool LineIsInteresting(const std::string& lower) {
  static const char* kNeedles[] = {
      "d3d11",     "swapchain", "colorspace", "colour",  "color space",
      "hdr",       "pq",        "bt.2020",    "2084",    "st2084",
      "feature level", "gpu-next", "placebo",  "hlg",    "peak",
      "metadata",  "10 bit",    "r10g10b10",  "fp16",    "r16g16b16",
  };
  for (const char* needle : kNeedles) {
    if (lower.find(needle) != std::string::npos) {
      return true;
    }
  }
  return false;
}

static void PrintProperty(mpv_handle* ctx, const char* name) {
  char* value = g_mpv.get_property_string(ctx, name);
  if (value) {
    std::printf("  %-28s %s\n", name, value);
    g_mpv.free(value);
  } else {
    std::printf("  %-28s (unavailable)\n", name);
  }
}

static void ProbePlayback(HWND hwnd, const std::string& media, int seconds) {
  std::printf("\n=== Q3  Live playback into a D3D11 HDR swapchain ===\n\n");
  std::printf("  media   : %s\n", media.c_str());
  std::printf("  duration: %d seconds\n\n", seconds);
  std::printf(
      "  Put Windows into HDR mode BEFORE running this, and watch the\n"
      "  display's own HDR indicator while it plays.\n\n");

  char wid_str[32];
  std::snprintf(wid_str, sizeof(wid_str), "%lld",
                static_cast<long long>(reinterpret_cast<intptr_t>(hwnd)));

  mpv_handle* ctx = g_mpv.create();
  if (!ctx) {
    std::printf("  FAIL  mpv_create returned null\n");
    return;
  }

  struct Opt {
    const char* key;
    const char* value;
  };
  const Opt opts[] = {
      {"wid", wid_str},
      {"vo", "gpu-next"},
      {"gpu-api", "d3d11"},
      {"target-colorspace-hint", "yes"},
      {"hwdec", "auto"},
      {"keep-open", "yes"},
      {"osc", "no"},
      {"input-default-bindings", "no"},
  };
  for (const Opt& o : opts) {
    int rc = g_mpv.set_option_string(ctx, o.key, o.value);
    if (rc < 0) {
      std::printf("  WARN  %s=%s rejected: %s\n", o.key, o.value, Err(rc));
    }
  }

  g_mpv.request_log_messages(ctx, "v");

  int init_rc = g_mpv.initialize(ctx);
  if (init_rc < 0) {
    std::printf("  FAIL  mpv_initialize: %s\n", Err(init_rc));
    g_mpv.terminate_destroy(ctx);
    return;
  }

  const char* cmd[] = {"loadfile", media.c_str(), nullptr};
  int load_rc = g_mpv.command(ctx, cmd);
  if (load_rc < 0) {
    std::printf("  FAIL  loadfile: %s\n", Err(load_rc));
    g_mpv.terminate_destroy(ctx);
    return;
  }

  std::printf("  --- relevant mpv log lines ---\n");

  const ULONGLONG deadline =
      GetTickCount64() + static_cast<ULONGLONG>(seconds) * 1000ULL;
  bool reported_params = false;

  while (GetTickCount64() < deadline) {
    PumpWindowMessages();

    mpv_event* ev = g_mpv.wait_event(ctx, 0.05);
    if (!ev || ev->event_id == MPV_EVENT_NONE) {
      continue;
    }
    if (ev->event_id == MPV_EVENT_SHUTDOWN) {
      break;
    }
    if (ev->event_id == MPV_EVENT_LOG_MESSAGE) {
      auto* msg = static_cast<mpv_event_log_message*>(ev->data);
      std::string text = msg->text ? msg->text : "";
      std::string lower = text;
      for (char& c : lower) {
        c = static_cast<char>(::tolower(static_cast<unsigned char>(c)));
      }
      if (LineIsInteresting(lower)) {
        while (!text.empty() && (text.back() == '\n' || text.back() == '\r')) {
          text.pop_back();
        }
        std::printf("  [%s] %s\n", msg->prefix ? msg->prefix : "?",
                    text.c_str());
      }
      continue;
    }
    if ((ev->event_id == MPV_EVENT_VIDEO_RECONFIG ||
         ev->event_id == MPV_EVENT_PLAYBACK_RESTART) &&
        !reported_params) {
      reported_params = true;
      std::printf("\n  --- negotiated video parameters ---\n");
      PrintProperty(ctx, "current-vo");
      PrintProperty(ctx, "video-params/pixelformat");
      PrintProperty(ctx, "video-params/colormatrix");
      PrintProperty(ctx, "video-params/primaries");
      PrintProperty(ctx, "video-params/gamma");
      PrintProperty(ctx, "video-params/sig-peak");
      PrintProperty(ctx, "video-params/max-luma");
      PrintProperty(ctx, "video-params/w");
      PrintProperty(ctx, "video-params/h");
      PrintProperty(ctx, "hwdec-current");
      std::printf("\n  --- continuing log capture ---\n");
    }
  }

  std::printf("\n  --- how to read this ---\n");
  std::printf(
      "  HDR passthrough is working when video-params/gamma is pq (or hlg)\n"
      "  AND video-params/primaries is bt.2020 AND the d3d11 log lines show a\n"
      "  10-bit or fp16 swapchain in a BT.2020/PQ colorspace. If gamma comes\n"
      "  back as bt.1886 or the swapchain is 8-bit, mpv tone-mapped to SDR and\n"
      "  the gate has NOT been met.\n");

  g_mpv.terminate_destroy(ctx);
}

// ---------------------------------------------------------------------------

static std::wstring Widen(const std::string& s) {
  if (s.empty()) {
    return std::wstring();
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
  std::wstring out(static_cast<size_t>(n ? n - 1 : 0), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, out.data(), n);
  return out;
}

static std::wstring DefaultLibmpvPath() {
  wchar_t exe[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exe, MAX_PATH) == 0) {
    return L"libmpv-2.dll";
  }
  std::wstring dir(exe);
  size_t slash = dir.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return L"libmpv-2.dll";
  }
  return dir.substr(0, slash + 1) + L"libmpv-2.dll";
}

static void Usage() {
  std::printf(
      "Moonfin HDR probe - Phase 0 gate for native HDR video output\n"
      "\n"
      "Usage:\n"
      "  hdr_probe.exe [--libmpv <path to libmpv-2.dll>]\n"
      "                [--media <path to an HDR10 file>]\n"
      "                [--seconds <n, default 15>]\n"
      "\n"
      "Without --media only Q1 and Q2 run. Q3 needs a real HDR file and a\n"
      "display already switched into HDR mode.\n"
      "\n"
      "The shipped libmpv lands at:\n"
      "  build\\windows\\x64\\libmpv\\libmpv-2.dll        (after a flutter build)\n"
      "  build\\windows\\x64\\runner\\Release\\libmpv-2.dll\n");
}

int main(int argc, char** argv) {
  std::wstring libmpv_path;
  std::string media;
  int seconds = 15;

  for (int i = 1; i < argc; i++) {
    std::string arg = argv[i];
    if ((arg == "--libmpv") && i + 1 < argc) {
      libmpv_path = Widen(argv[++i]);
    } else if ((arg == "--media") && i + 1 < argc) {
      media = argv[++i];
    } else if ((arg == "--seconds") && i + 1 < argc) {
      seconds = std::atoi(argv[++i]);
    } else if (arg == "--help" || arg == "-h") {
      Usage();
      return 0;
    } else {
      std::printf("Unknown argument: %s\n\n", arg.c_str());
      Usage();
      return 2;
    }
  }

  if (libmpv_path.empty()) {
    libmpv_path = DefaultLibmpvPath();
  }

  std::printf("=== Moonfin HDR probe ===\n\n");
  std::printf("  libmpv: %ls\n", libmpv_path.c_str());

  if (!LoadMpv(libmpv_path)) {
    std::printf(
        "\nCould not load libmpv. Pass --libmpv with the path to the DLL that\n"
        "ships with Moonfin.\n");
    return 1;
  }

  const unsigned long api = g_mpv.client_api_version();
  std::printf("  client API version: %lu.%lu\n", api >> 16, api & 0xFFFF);

  mpv_handle* probe = g_mpv.create();
  if (probe) {
    char* version = g_mpv.get_property_string(probe, "mpv-version");
    if (version) {
      std::printf("  mpv version: %s\n", version);
      g_mpv.free(version);
    }
    g_mpv.terminate_destroy(probe);
  }

  ProbeOptions();

  HWND hwnd = CreateHostWindow();
  if (!hwnd) {
    std::printf("\n  FAIL  could not create host window (error %lu)\n",
                GetLastError());
    return 1;
  }

  ProbeWid(hwnd);

  if (!media.empty()) {
    ProbePlayback(hwnd, media, seconds);
  } else {
    std::printf(
        "\n=== Q3  skipped ===\n\n"
        "  Pass --media <path to an HDR10 file> to run the live playback\n"
        "  test. Switch the display into HDR mode first.\n");
  }

  DestroyWindow(hwnd);
  std::printf("\n=== done ===\n");
  return 0;
}
