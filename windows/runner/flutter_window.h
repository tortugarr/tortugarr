#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include <flutter/plugin_registrar_windows.h>

#include "hdr_overlay_window.h"
#include "hdr_video_window.h"
#include "native_game.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  LRESULT RouteMessage(HWND window, UINT const message, WPARAM const wparam,
                       LPARAM const lparam) noexcept;

  void SizeChildToClientArea();

  // WM_SIZE re-entrancy - see MessageHandler.
  int size_depth_ = 0;
  bool nested_size_ = false;

  // Starts and stops the position heartbeat with the HDR windows, so a
  // session that never plays HDR never pays for it.
  void UpdateHdrSyncTimer();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Native HDR video output: mpv's own D3D11 window, and the layered windows
  // the player controls are composited into above it.
  std::unique_ptr<flutter::PluginRegistrarWindows> hdr_video_registrar_;
  std::unique_ptr<HdrVideoWindow> hdr_video_;
  std::unique_ptr<HdrOverlayWindow> hdr_overlay_;

  bool hdr_sync_timer_running_ = false;

  // Native retro-game playback.
  std::unique_ptr<flutter::PluginRegistrarWindows> native_game_registrar_;
  std::unique_ptr<NativeGame> native_game_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
