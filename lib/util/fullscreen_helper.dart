import 'fullscreen_helper_io.dart'
    if (dart.library.js_interop) 'fullscreen_helper_web.dart' as impl;
import 'platform_detection.dart';

abstract class FullscreenHelper {
  static Future<bool> isFullscreen() => impl.isFullscreen();
  static Future<void> setFullscreen(bool value) => impl.setFullscreen(value);
  static Future<void> toggle() async {
    final current = await isFullscreen();
    await setFullscreen(!current);
  }

  static bool maximizedAfterWindowEvent(String eventName, bool maximized) =>
      switch (eventName) {
        'maximize' => true,
        'unmaximize' => false,
        // On Windows a maximized window stays maximized through fullscreen,
        // and window_manager then reports its next restore as leaving
        // fullscreen instead of unmaximize. It only sends this for a restore.
        'leave-full-screen' when PlatformDetection.isWindows => false,
        _ => maximized,
      };
}
