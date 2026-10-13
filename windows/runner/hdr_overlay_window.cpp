#include "hdr_overlay_window.h"

#include <flutter/standard_method_codec.h>

#include "hdr_window_support.h"
#include "method_call_args.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"MOONFIN_HDR_OVERLAY";

}  // namespace

HdrOverlayWindow::HdrOverlayWindow(flutter::BinaryMessenger* messenger,
                                   HWND top_level,
                                   std::function<void()> on_window_changed)
    : on_window_changed_(std::move(on_window_changed)),
      top_level_(top_level) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "moonfin/hdr_overlay",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethod(call, std::move(result));
  });
}

HdrOverlayWindow::~HdrOverlayWindow() {
  ReleaseSurface();
  if (window_ != nullptr) {
    DestroyWindow(window_);
    window_ = nullptr;
  }
}

void HdrOverlayWindow::HandleMethod(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  const flutter::EncodableMap empty;
  const flutter::EncodableMap& map = args != nullptr ? *args : empty;
  const std::string& method = call.method_name();

  if (method == "push") {
    const int width = method_call_args::GetInt(map, "width", 0);
    const int height = method_call_args::GetInt(map, "height", 0);
    const int x = method_call_args::GetInt(map, "x", 0);
    const int y = method_call_args::GetInt(map, "y", 0);

    const auto it = map.find(flutter::EncodableValue(std::string("bytes")));
    const std::vector<uint8_t>* pixels =
        it != map.end() ? std::get_if<std::vector<uint8_t>>(&it->second)
                        : nullptr;
    if (pixels == nullptr || width <= 0 || height <= 0) {
      result->Error("bad_args", "push needs bytes, width and height");
      return;
    }
    if (pixels->size() <
        static_cast<size_t>(width) * static_cast<size_t>(height) * 4) {
      result->Error("short_buffer", "bytes is smaller than width * height * 4");
      return;
    }

    const RECT rect = {x, y, x + width, y + height};
    if (!Push(rect, *pixels, width, height)) {
      result->Error("push_failed", "could not update the overlay window");
      return;
    }
    if (on_window_changed_) on_window_changed_();
    result->Success();
    return;
  }

  if (method == "hide") {
    Hide();
    result->Success();
    return;
  }

  result->NotImplemented();
}

bool HdrOverlayWindow::Push(const RECT& rect,
                            const std::vector<uint8_t>& pixels, int width,
                            int height) {
  if (top_level_ == nullptr) {
    return false;
  }

  client_rect_ = rect;

  // The rect arrives in the top-level's client coordinates, but a layered
  // window is top-level itself and positioned in screen space.
  POINT origin = {rect.left, rect.top};
  ClientToScreen(top_level_, &origin);

  if (window_ == nullptr) {
    if (!hdr_window_support::EnsureWindowClass(
            kWindowClassName, hdr_window_support::ClickThroughWndProc,
            nullptr)) {
      return false;
    }
    // WS_EX_TRANSPARENT keeps the overlay out of hit-testing, so clicks pass
    // through to the Flutter view where the real widgets still are, and
    // WS_EX_NOACTIVATE keeps focus there too.
    window_ = CreateWindowEx(
        WS_EX_LAYERED | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW |
            WS_EX_TRANSPARENT,
        kWindowClassName, L"", WS_POPUP, origin.x, origin.y, width, height,
        top_level_, nullptr, GetModuleHandle(nullptr), nullptr);
    if (window_ == nullptr) {
      return false;
    }
  }

  HDC screen_dc = GetDC(nullptr);

  if (bitmap_ == nullptr || width_ != width || height_ != height) {
    ReleaseSurface();

    // Top-down 32-bit DIB, which is the layout UpdateLayeredWindow wants.
    BITMAPINFO info = {};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    bitmap_ =
        CreateDIBSection(screen_dc, &info, DIB_RGB_COLORS, &bits_, nullptr, 0);
    if (bitmap_ == nullptr || bits_ == nullptr) {
      ReleaseSurface();
      ReleaseDC(nullptr, screen_dc);
      return false;
    }
    memory_dc_ = CreateCompatibleDC(screen_dc);
    previous_bitmap_ = SelectObject(memory_dc_, bitmap_);
    width_ = width;
    height_ = height;
  }

  // Flutter's rawRgba is already premultiplied, which is what AC_SRC_ALPHA
  // needs, so only the channel order differs. Done here rather than in Dart
  // to keep it off the UI isolate. Word-at-a-time: RGBA in memory order reads
  // as 0xAABBGGRR and BGRA wants 0xAARRGGBB, so only the outer two bytes move
  // and the loop vectorises.
  const auto* source = reinterpret_cast<const uint32_t*>(pixels.data());
  auto* destination = static_cast<uint32_t*>(bits_);
  const size_t count = static_cast<size_t>(width) * static_cast<size_t>(height);
  for (size_t i = 0; i < count; ++i) {
    const uint32_t p = source[i];
    destination[i] = (p & 0xFF00FF00u) |          // alpha and green stay put
                     ((p & 0x00FF0000u) >> 16) |  // blue to the low byte
                     ((p & 0x000000FFu) << 16);   // red up to byte two
  }

  POINT destination_point = {origin.x, origin.y};
  SIZE size = {width, height};
  POINT source_point = {0, 0};
  BLENDFUNCTION blend = {};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;

  const BOOL ok = UpdateLayeredWindow(window_, screen_dc, &destination_point,
                                      &size, memory_dc_, &source_point, 0,
                                      &blend, ULW_ALPHA);
  ReleaseDC(nullptr, screen_dc);
  if (ok == FALSE) {
    return false;
  }

  if (!visible_) {
    ShowWindow(window_, SW_SHOWNOACTIVATE);
    // Only on the transition; re-asserting the z-order per push is a window
    // manager round trip for an ordering that has not changed.
    SetWindowPos(window_, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    visible_ = true;
  }
  return true;
}

void HdrOverlayWindow::SyncPosition() {
  if (window_ == nullptr || top_level_ == nullptr || !visible_) {
    return;
  }
  POINT origin = {client_rect_.left, client_rect_.top};
  ClientToScreen(top_level_, &origin);
  SetWindowPos(window_, HWND_TOP, origin.x, origin.y, 0, 0,
               SWP_NOSIZE | SWP_NOACTIVATE);
}

void HdrOverlayWindow::Hide() {
  if (window_ == nullptr || !visible_) {
    return;
  }
  ShowWindow(window_, SW_HIDE);
  visible_ = false;
  if (on_window_changed_) on_window_changed_();
}

void HdrOverlayWindow::ReleaseSurface() {
  if (memory_dc_ != nullptr) {
    SelectObject(memory_dc_, previous_bitmap_);
    DeleteDC(memory_dc_);
    memory_dc_ = nullptr;
  }
  if (bitmap_ != nullptr) {
    DeleteObject(bitmap_);
    bitmap_ = nullptr;
  }
  previous_bitmap_ = nullptr;
  bits_ = nullptr;
  width_ = 0;
  height_ = 0;
}

