import 'package:flutter/services.dart';

import 'platform_detection.dart';

/// Asks Android to move the app's task to the front. Used when a remote
/// "play now" arrives while the app sits in the background, so the player
/// has a visible surface to draw on. Best effort: returns false when the
/// platform refuses or the method is unavailable.
class AppForeground {
  static const MethodChannel _channel = MethodChannel(
    'org.moonfin.androidtv/platform',
  );

  static Future<bool> bringToFront() async {
    if (!PlatformDetection.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('bringToFront') ?? false;
    } catch (_) {
      return false;
    }
  }
}
