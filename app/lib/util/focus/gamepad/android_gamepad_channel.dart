import 'dart:async';

import 'package:flutter/services.dart';

import '../../platform_detection.dart';
import 'gamepad_key_synthesizer.dart';
import 'gamepad_suppressor.dart';

/// Sole owner of the native gamepad channel on Android.
///
/// The channel carries two unrelated conversations, onButton for the emulator
/// and onNavigate for UI focus, and a channel only allows one handler. Without
/// routing here, whichever registered last would silently starve the other.
class AndroidGamepadChannel {
  AndroidGamepadChannel._();

  static const MethodChannel _channel = MethodChannel(
    'org.moonfin.androidtv/gamepad',
  );

  static Future<dynamic> Function(MethodCall)? _buttonHandler;
  static AndroidStickNavigator? _navigator;
  static bool _installed = false;

  /// Start routing. Safe to call more than once.
  static void ensureInstalled() {
    if (_installed || !PlatformDetection.isAndroid) return;
    _installed = true;
    _channel.setMethodCallHandler(_dispatch);
    _navigator = AndroidStickNavigator();
  }

  /// Register the emulator's button handler for the lifetime of a game.
  /// Pass null on teardown.
  static void setButtonHandler(Future<dynamic> Function(MethodCall)? handler) =>
      _buttonHandler = handler;

  /// Tell the native side whether a game currently owns the pad.
  static Future<void> setGameActive(bool active) async {
    if (!PlatformDetection.isAndroid) return;
    _navigator?.reset();
    await _channel.invokeMethod('setActive', {'active': active});
  }

  static Future<dynamic> _dispatch(MethodCall call) async {
    switch (call.method) {
      case 'onButton':
        return _buttonHandler?.call(call);
      case 'onNavigate':
        final args = (call.arguments as Map).cast<String, dynamic>();
        _navigator?.handle(
          axis: args['axis'] as String? ?? '',
          direction: args['direction'] as String? ?? 'none',
        );
        return null;
      default:
        return null;
    }
  }
}

/// Turns Android left-stick motion into focus movement.
///
/// Pad buttons and the d-pad already arrive as real key events on Android, so
/// nothing else needs bridging. The analog stick is the one input that comes
/// through as a motion event, invisible to Flutter's key pipeline, so it gets
/// fed to the same synthesizer the desktop path uses.
class AndroidStickNavigator {
  final GamepadKeyRepeater _keys = GamepadKeyRepeater(GamepadKeySynthesizer());
  final Map<String, GamepadNavKey> _heldByAxis = <String, GamepadNavKey>{};

  void handle({required String axis, required String direction}) {
    // Let go of whatever this axis was holding first, so flicking straight
    // from left to right can't strand the left key down.
    final previous = _heldByAxis.remove(axis);
    if (previous != null) _keys.release(previous);

    if (direction == 'none' || GamepadSuppressor.suppressed) return;

    final key = switch (direction) {
      'up' => GamepadNavKey.up,
      'down' => GamepadNavKey.down,
      'left' => GamepadNavKey.left,
      'right' => GamepadNavKey.right,
      _ => null,
    };
    if (key == null) return;

    _heldByAxis[axis] = key;
    _keys.press(key);
  }

  /// Drops all held state, so a direction held while a game takes or releases
  /// the pad can't stay logically pressed.
  void reset() {
    _heldByAxis.clear();
    _keys.releaseAll();
  }
}
