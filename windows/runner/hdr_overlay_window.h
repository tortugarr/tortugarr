#ifndef RUNNER_HDR_OVERLAY_WINDOW_H_
#define RUNNER_HDR_OVERLAY_WINDOW_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

// The player chrome, drawn over the HDR video window in the overlay-capture
// fallback (MOONFIN_HDR_DWM=0), where mpv's child window sits above the
// Flutter view. UpdateLayeredWindow is the only Win32 API that gives per-pixel
// alpha over an arbitrary window, which the player's scrim gradients need.
// The default behind-the-window arrangement does not use this; see
// hdr_video_window.h.
//
// Flutter renders the chrome off-screen and pushes it here as premultiplied
// pixels covering the whole player. Readback cost tracks area, so capturing
// only the top and bottom bands would be cheaper; that needs the player's
// layout refactored first.
class HdrOverlayWindow {
 public:
  // |top_level| is the runner window the overlay is positioned against. It is
  // passed explicitly for the same reason as HdrVideoWindow: at construction
  // time the Flutter view is not yet parented into the runner, so deriving
  // the root from a registrar would land on the view itself.
  // |on_window_changed| fires whenever the overlay appears or goes away. See
  // the same parameter on HdrVideoWindow.
  HdrOverlayWindow(flutter::BinaryMessenger* messenger, HWND top_level,
                   std::function<void()> on_window_changed);
  ~HdrOverlayWindow();

  HdrOverlayWindow(const HdrOverlayWindow&) = delete;
  HdrOverlayWindow& operator=(const HdrOverlayWindow&) = delete;

  // Re-derives the window's screen position from the client rect it was last
  // given. The overlay is top-level, so it is positioned in screen space and
  // does not follow the runner window on its own when that window is dragged.
  void SyncPosition();

  // A hidden overlay has no position to keep, so it does not need the
  // runner's heartbeat.
  bool NeedsPositionSync() const { return window_ != nullptr && visible_; }

 private:
  void HandleMethod(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Blits |pixels| - premultiplied RGBA, row-primary, as Flutter's
  // ImageByteFormat.rawRgba produces it - into the overlay, creating and
  // sizing it as needed. |rect| is in client coordinates of the top-level.
  bool Push(const RECT& rect, const std::vector<uint8_t>& pixels, int width,
            int height);
  void Hide();

  // Drops the cached GDI objects. They are rebuilt on the next push.
  void ReleaseSurface();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::function<void()> on_window_changed_;
  HWND top_level_ = nullptr;
  HWND window_ = nullptr;
  bool visible_ = false;

  // The DIB and its DC are kept between pushes and rebuilt only on a size
  // change; recreating ~30 MB per frame costs milliseconds on the thread that
  // pumps the message loop.
  HDC memory_dc_ = nullptr;
  HBITMAP bitmap_ = nullptr;
  HGDIOBJ previous_bitmap_ = nullptr;
  void* bits_ = nullptr;
  int width_ = 0;
  int height_ = 0;

  // Last client rect, so SyncPosition can re-derive the screen origin.
  RECT client_rect_ = {};
};

#endif  // RUNNER_HDR_OVERLAY_WINDOW_H_
