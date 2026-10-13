import 'package:flutter/services.dart';

import '../preference/preference_constants.dart';
import 'platform_detection.dart';

class AutoHdrSwitcher {
  static const MethodChannel _channel = MethodChannel('moonfin/hdr_display');

  bool _engaged = false;
  bool _restoreToSdr = false;
  bool _channelUnavailable = false;

  Future<void> sync({
    required AutoHdrSwitchingBehavior behavior,
    required bool isHdrContent,
    required bool isDesktopFullscreen,
  }) async {
    if (!PlatformDetection.isWindows) {
      return;
    }

    final shouldEnable = switch (behavior) {
      AutoHdrSwitchingBehavior.disabled => false,
      AutoHdrSwitchingBehavior.whenFullscreen =>
        isHdrContent && isDesktopFullscreen,
      AutoHdrSwitchingBehavior.always => isHdrContent,
    };

    if (shouldEnable) {
      await _engage();
      return;
    }

    await restore();
  }

  Future<void> _engage() async {
    if (_engaged || _channelUnavailable) return;

    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('getHdrState');
      if (state == null) return;

      final supported = state['supported'] == true;
      final enabled = state['enabled'] == true;
      if (!supported) {
        return;
      }

      _engaged = true;
      _restoreToSdr = !enabled;

      if (_restoreToSdr) {
        final ok = await _channel.invokeMethod<bool>('setHdrEnabled', true);
        if (ok != true) {
          _engaged = false;
          _restoreToSdr = false;
        }
      }
    } on MissingPluginException {
      _channelUnavailable = true;
    } catch (_) {}
  }

  Future<void> restore() async {
    if (!_engaged) return;

    final restoreToSdr = _restoreToSdr;
    _engaged = false;
    _restoreToSdr = false;

    if (!restoreToSdr || !PlatformDetection.isWindows || _channelUnavailable) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('setHdrEnabled', false);
    } on MissingPluginException {
      _channelUnavailable = true;
    } catch (_) {}
  }
}
