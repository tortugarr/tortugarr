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

  // Handles both onButton and onKeyboard despite the name; not button-only.
  static Future<dynamic> Function(MethodCall)? _emulatorInputHandler;
  static Future<dynamic> Function(MethodCall)? _controllerMappingKeyHandler;
  static Future<dynamic> Function(MethodCall)?
  _controllerDiagnosticsAxesHandler;
  static Future<dynamic> Function(MethodCall)?
  _controllerDiagnosticsButtonHandler;
  static AndroidStickNavigator? _navigator;
  static bool _installed = false;

  /// Start routing. Safe to call more than once.
  static void ensureInstalled() {
    if (_installed || !PlatformDetection.isAndroid) return;
    _installed = true;
    _channel.setMethodCallHandler(_dispatch);
    _navigator = AndroidStickNavigator();
  }

  /// Register the emulator's input handler (onButton and onKeyboard) for the
  /// lifetime of a game. Pass null on teardown.
  static void setEmulatorInputHandler(
    Future<dynamic> Function(MethodCall)? handler,
  ) => _emulatorInputHandler = handler;

  /// Tell the native side whether a game currently owns the pad.
  static Future<void> setGameActive(bool active) async {
    if (!PlatformDetection.isAndroid) return;
    _navigator?.reset();
    await _channel.invokeMethod('setActive', {'active': active});
  }

  /// Tell the native side whether a pad may drive the UI at all. Pad buttons
  /// reach Flutter as real key events on Android, so the gate has to sit in
  /// the Activity, ahead of anything Dart sees.
  static Future<void> setNavigationEnabled(bool enabled) async {
    if (!PlatformDetection.isAndroid) return;
    _navigator?.reset();
    await _channel.invokeMethod('setNavigationEnabled', {'enabled': enabled});
  }

  static Future<void> setEmulatorControlsActive(bool active) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setEmulatorControlsActive', {
      'active': active,
    });
  }

  /// Applies per-controller native RetroPad overrides for the active session.
  static Future<void> setControllerMapping(String mappingJson) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setControllerMapping', {
      'mapping': mappingJson,
    });
  }

  /// Applies the durable Player 1-4 assignment to the native port registry.
  /// Sent before a session starts and again on every edit, reallocating ports
  /// immediately.
  static Future<void> setControllerAssignments(String assignmentsJson) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setControllerAssignments', {
      'assignments': assignmentsJson,
    });
  }

  /// Captures the next physical button from [deviceId] instead of forwarding
  /// it to libretro. Used only while the native mapping overlay is rebinding.
  static Future<void> setControllerMappingCapture(
    bool active, {
    String? connectionId,
  }) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setControllerMappingCapture', {
      'active': active,
      'connectionId': ?connectionId,
    });
  }

  static void setControllerMappingKeyHandler(
    Future<dynamic> Function(MethodCall)? handler,
  ) => _controllerMappingKeyHandler = handler;

  /// Arms or disarms monitor mode for the controller test panel. Mirrors
  /// [setControllerMappingCapture]'s shape: observation only, never binds
  /// anything native-side. See the design doc's "Placement and lifecycle".
  static Future<void> setControllerDiagnostics(
    bool active, {
    String? connectionId,
  }) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setControllerDiagnostics', {
      'active': active,
      'connectionId': ?connectionId,
    });
  }

  static void setControllerDiagnosticsAxesHandler(
    Future<dynamic> Function(MethodCall)? handler,
  ) => _controllerDiagnosticsAxesHandler = handler;

  static void setControllerDiagnosticsButtonHandler(
    Future<dynamic> Function(MethodCall)? handler,
  ) => _controllerDiagnosticsButtonHandler = handler;

  /// Tells NativePadInput whether the in-game pause overlay is showing, so
  /// Start switches between its gameplay gesture and overlay navigation, and
  /// LibretroBridge only sends "button" EventChannel messages while paused.
  /// Stick snap mode per controller profile id, for the loaded game.
  static Future<void> setStickSnap(Map<String, String> modes) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setStickSnap', {'modes': modes});
  }

  static Future<void> setOverlayOpen(bool open) async {
    if (!PlatformDetection.isAndroid) return;
    await _channel.invokeMethod('setOverlayOpen', {'open': open});
  }

  /// Physical pads known to Android. The native side returns privacy-safe,
  /// stable profile ids rather than raw device descriptors.
  static Future<List<Map<String, dynamic>>> getEmulatorGamepads() async {
    if (!PlatformDetection.isAndroid) return const [];
    final result = await _channel.invokeListMethod<dynamic>(
      'getGamepadDevices',
    );
    return result
            ?.whereType<Map>()
            .map((value) => value.cast<String, dynamic>())
            .toList(growable: false) ??
        const [];
  }

  /// Native-libretro controller snapshot. Unlike [getEmulatorGamepads], this
  /// route reports runtime connection/port metadata and is never used by the
  /// EmulatorJS backend.
  static Future<List<Map<String, dynamic>>> getNativeGamepadDevices() async {
    if (!PlatformDetection.isAndroid) return const [];
    final result = await _channel.invokeListMethod<dynamic>(
      'getNativeGamepadDevices',
    );
    return result
            ?.whereType<Map>()
            .map((value) => value.cast<String, dynamic>())
            .toList(growable: false) ??
        const [];
  }

  static Future<dynamic> _dispatch(MethodCall call) async {
    switch (call.method) {
      case 'onButton':
      case 'onKeyboard':
        return _emulatorInputHandler?.call(call);
      case 'onControllerMappingKey':
        return _controllerMappingKeyHandler?.call(call);
      case 'onControllerDiagnosticsAxes':
        return _controllerDiagnosticsAxesHandler?.call(call);
      case 'onControllerDiagnosticsButton':
        return _controllerDiagnosticsButtonHandler?.call(call);
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
