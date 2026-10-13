#ifndef RUNNER_HDR_WINDOW_SUPPORT_H_
#define RUNNER_HDR_WINDOW_SUPPORT_H_

#include <windows.h>

// Shared pieces of the two native HDR companion windows (hdr_video_window,
// hdr_overlay_window). The click-through window proc in particular must stay
// identical between them - it is what keeps the player's mouse input working.
namespace hdr_window_support {

// Registers |name| against |proc| once per process. Returns false only if the
// registration itself failed. |background| becomes the class brush: the video
// window passes black, so any moment mpv is not covering it - the renderer
// cycle on a monitor crossing, above all - reads as a brief black blink
// rather than the desktop showing through the transparent runner (behind
// arrangement) or a stale strip (child arrangement, where black is simply the
// letterbox colour). The overlay passes null; UpdateLayeredWindow owns its
// every pixel. Any class registered with a real brush must create its windows
// with WS_CLIPCHILDREN, or the erase paints straight over mpv's child during
// playback.
bool EnsureWindowClass(const wchar_t* name, WNDPROC proc, HBRUSH background);

// The top-level window's client area in screen coordinates - what a
// behind-the-window companion has to cover to line up with the Flutter view.
RECT ClientRectInScreenSpace(HWND top_level);

// Makes the top-level window composite with per-pixel alpha against whatever
// sits behind it, per `technique`:
//   1  DwmExtendFrameIntoClientArea(-1) - the classic sheet-of-glass call
//   2  SetWindowCompositionAttribute ACCENT_ENABLE_TRANSPARENTGRADIENT
//   3  both
//   4  accent state 6, past the documented enum - flutter_native_view's call
//
// flutter_acrylic uses the same calls. They only work over a genuinely
// transparent Flutter frame: any opaque widget under the video paints it out.
bool ApplyTransparencyComposition(HWND top_level, int technique);

// Puts the window back to normal opaque composition.
void RevertTransparencyComposition(HWND top_level);

// Appends a printf-style line to %TEMP%\moonfin_hdr_dwm.log. The runner is
// detached from any console, so this is the only way to see what the native
// half actually did. Volume discipline: a handful of lines per playback is
// fine; nothing may log on the heartbeat while healthy.
void Log(const wchar_t* format, ...);

// The window procedure both companions use.
//
// The load-bearing case is WM_NCHITTEST returning HTTRANSPARENT. Neither
// window may take a hit test: the widgets that handle the click are in the
// Flutter view underneath, still laid out at the same coordinates - only the
// pixels moved. WS_EX_TRANSPARENT covers this for a layered top-level window
// but not for a child, where hit-testing walks the child chain and stops at
// the first window regardless. Without this the video window swallows every
// mouse event and the player looks dead while the keyboard still works,
// because keyboard follows focus, which never moved.
LRESULT CALLBACK ClickThroughWndProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) noexcept;

}  // namespace hdr_window_support

#endif  // RUNNER_HDR_WINDOW_SUPPORT_H_
