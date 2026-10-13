import 'package:flutter/services.dart';

import '../preference/preference_constants.dart';
import 'platform_detection.dart';

class AutoHdrSwitcher {
  static const MethodChannel _channel = MethodChannel('moonfin/hdr_display');

  /// Whether the display the window is on is currently in HDR mode.
  ///
  /// Native HDR output needs this before deciding to give mpv its own window:
  /// tagging a swapchain BT.2020/PQ against an SDR display just makes mpv
  /// tone-map twice.
  static Future<bool> isDisplayHdrEnabled() async =>
      await displayHdrState() ?? false;

  /// Tri-state variant of [isDisplayHdrEnabled]: null when the answer could
  /// not be determined.
  ///
  /// The distinction matters to the monitor-crossing renegotiation skip: the
  /// display query can legitimately fail mid-topology-change - exactly when a
  /// crossing fires - and a failure read as "SDR" would wrongly skip the
  /// cycle and stick playback on the old colorspace with no retry.
  /// Engagement keeps the collapsed bool, where unknown conservatively means
  /// "do not engage".
  static Future<bool?> displayHdrState() async {
    if (!PlatformDetection.isWindows) return false;
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>(
        'getHdrState',
      );
      if (state == null) return null;
      return state['enabled'] == true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return null;
    }
  }

  bool _engaged = false;
  bool _restoreToSdr = false;
  bool _channelUnavailable = false;

  /// Returns whether the display's HDR mode was actually changed. Callers run
  /// this on every bringup phase and queue change, where it does nothing, so
  /// react to the return value rather than to the call.
  Future<bool> sync({
    required AutoHdrSwitchingBehavior behavior,
    required bool isHdrContent,
    required bool isDesktopFullscreen,
  }) async {
    if (!PlatformDetection.isWindows) {
      return false;
    }

    final shouldEnable = switch (behavior) {
      AutoHdrSwitchingBehavior.disabled => false,
      AutoHdrSwitchingBehavior.whenFullscreen =>
        isHdrContent && isDesktopFullscreen,
      AutoHdrSwitchingBehavior.always => isHdrContent,
    };

    if (shouldEnable) {
      return _engage();
    }

    return restore();
  }

  /// True only when it actually switched the display into HDR.
  Future<bool> _engage() async {
    if (_engaged || _channelUnavailable) return false;

    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('getHdrState');
      if (state == null) return false;

      final supported = state['supported'] == true;
      final enabled = state['enabled'] == true;
      if (!supported) {
        return false;
      }

      _engaged = true;
      _restoreToSdr = !enabled;

      if (_restoreToSdr) {
        final ok = await _channel.invokeMethod<bool>('setHdrEnabled', true);
        if (ok != true) {
          _engaged = false;
          _restoreToSdr = false;
          return false;
        }
        return true;
      }
    } on MissingPluginException {
      _channelUnavailable = true;
    } catch (_) {}
    return false;
  }

  /// True only when it actually switched the display back to SDR.
  Future<bool> restore() async {
    if (!_engaged) return false;

    final restoreToSdr = _restoreToSdr;
    _engaged = false;
    _restoreToSdr = false;

    if (!restoreToSdr || !PlatformDetection.isWindows || _channelUnavailable) {
      return false;
    }

    try {
      // The runner reports a refusal (another process owning the output, a
      // config call that failed) rather than throwing, same as _engage.
      final ok = await _channel.invokeMethod<bool>('setHdrEnabled', false);
      return ok == true;
    } on MissingPluginException {
      _channelUnavailable = true;
    } catch (_) {}
    return false;
  }
}
