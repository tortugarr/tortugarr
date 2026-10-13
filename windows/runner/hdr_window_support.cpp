#include "hdr_window_support.h"

#include <dwmapi.h>

#include <cstdarg>
#include <cstdio>
#include <cwchar>
#include <iterator>
#include <set>
#include <string>

namespace hdr_window_support {

bool EnsureWindowClass(const wchar_t* name, WNDPROC proc, HBRUSH background) {
  static std::set<std::wstring> registered;
  if (registered.count(name) != 0) {
    return true;
  }
  WNDCLASS window_class = {};
  window_class.lpfnWndProc = proc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = name;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.hbrBackground = background;
  if (RegisterClass(&window_class) == 0) {
    return false;
  }
  registered.insert(name);
  return true;
}

void Log(const wchar_t* format, ...) {
  wchar_t path[MAX_PATH] = {};
  if (GetTempPathW(static_cast<DWORD>(std::size(path)), path) == 0) {
    return;
  }
  wcsncat_s(path, L"moonfin_hdr_dwm.log", _TRUNCATE);
  FILE* file = nullptr;
  if (_wfopen_s(&file, path, L"a, ccs=UTF-8") != 0 || file == nullptr) {
    return;
  }
  SYSTEMTIME now = {};
  GetLocalTime(&now);
  fwprintf(file, L"%02u:%02u:%02u.%03u ", now.wHour, now.wMinute, now.wSecond,
           now.wMilliseconds);
  va_list args;
  va_start(args, format);
  vfwprintf(file, format, args);
  va_end(args);
  fwprintf(file, L"\n");
  fclose(file);
}

RECT ClientRectInScreenSpace(HWND top_level) {
  RECT client = {};
  GetClientRect(top_level, &client);
  POINT origin = {client.left, client.top};
  ClientToScreen(top_level, &origin);
  return RECT{origin.x, origin.y, origin.x + (client.right - client.left),
              origin.y + (client.bottom - client.top)};
}

namespace {

// SetWindowCompositionAttribute is undocumented, so its shapes are declared
// here. Same layout flutter_acrylic and flutter_native_view use.
struct AccentPolicy {
  int accent_state;
  int accent_flags;
  unsigned int gradient_color;
  int animation_id;
};

struct WindowCompositionAttributeData {
  int attribute;  // WCA_ACCENT_POLICY = 19
  void* data;
  size_t size;
};

using SetWindowCompositionAttributePtr =
    BOOL(WINAPI*)(HWND, WindowCompositionAttributeData*);

bool SetAccentState(HWND top_level, int state) {
  // user32 is already loaded by any process with a window and never unloads,
  // so no LoadLibrary/FreeLibrary round trip is needed.
  const HMODULE user32 = GetModuleHandleW(L"user32.dll");
  if (user32 == nullptr) {
    return false;
  }
  const auto set_attribute = reinterpret_cast<SetWindowCompositionAttributePtr>(
      GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (set_attribute == nullptr) {
    return false;
  }
  AccentPolicy policy = {};
  policy.accent_state = state;
  // 2 = honour the gradient colour, which is fully transparent AABBGGRR so
  // whatever sits behind the window shows through unmodified.
  policy.accent_flags = 2;
  policy.gradient_color = 0x00000000;
  WindowCompositionAttributeData data = {19, &policy, sizeof(policy)};
  return set_attribute(top_level, &data) != FALSE;
}

}  // namespace

bool ApplyTransparencyComposition(HWND top_level, int technique) {
  if (top_level == nullptr) {
    return false;
  }
  bool ok = true;
  if (technique == 1 || technique == 3) {
    MARGINS margins = {-1, -1, -1, -1};
    ok = SUCCEEDED(DwmExtendFrameIntoClientArea(top_level, &margins)) && ok;
  }
  if (technique == 2 || technique == 3) {
    // ACCENT_ENABLE_TRANSPARENTGRADIENT
    ok = SetAccentState(top_level, 2) && ok;
  }
  if (technique == 4) {
    // Past the documented end of the accent enum; what flutter_native_view
    // sets to show an embedded HWND through the Flutter window.
    ok = SetAccentState(top_level, 6) && ok;
  }
  return ok;
}

void RevertTransparencyComposition(HWND top_level) {
  if (top_level == nullptr) {
    return;
  }
  MARGINS margins = {0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(top_level, &margins);
  // ACCENT_DISABLED
  SetAccentState(top_level, 0);
}

LRESULT CALLBACK ClickThroughWndProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) noexcept {
  switch (message) {
    // WM_ERASEBKGND is deliberately unhandled: DefWindowProc erases with the
    // class brush, which is where the two windows differ - see
    // EnsureWindowClass.

    // Send the hit test on to the window underneath - see the header.
    case WM_NCHITTEST:
      return HTTRANSPARENT;
    // Never take activation from the Flutter view either.
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    default:
      break;
  }
  return DefWindowProc(window, message, wparam, lparam);
}

}  // namespace hdr_window_support
