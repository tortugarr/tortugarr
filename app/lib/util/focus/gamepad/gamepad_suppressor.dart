import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gamepad_key_synthesizer.dart';

/// Turns gamepad UI navigation off while something else owns the controller.
///
/// A depth counter rather than a flag, so overlapping owners can't
/// un-suppress each other on the way out.
class GamepadSuppressor {
  GamepadSuppressor._();

  static final ValueNotifier<int> depth = ValueNotifier<int>(0);

  static bool get suppressed => depth.value > 0;

  static void push() => depth.value++;

  static void pop() {
    if (depth.value > 0) depth.value--;
  }
}

/// Guards against the same physical input arriving twice.
///
/// Some setups mirror a pad onto a virtual keyboard device, so the d-pad also
/// shows up as arrow keys. The Steam Deck does this by default in desktop
/// mode. Without a guard, one press moves focus twice, once as a real key
/// event and once through our own stream.
///
/// Rather than trying to enumerate such devices, drop a synthetic direction
/// that lands within [_window] of a real one for the same key. The mirrored
/// case then just works once instead of double moving.
class GamepadDuplicateGuard {
  static const Duration _window = Duration(milliseconds: 50);

  final Map<LogicalKeyboardKey, Stopwatch> _lastReal =
      <LogicalKeyboardKey, Stopwatch>{};

  void start() => HardwareKeyboard.instance.addHandler(_onKey);

  void stop() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lastReal.clear();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    // Our own output comes back through here too, so skip it.
    if (GamepadKeySynthesizer.isSynthetic(event.physicalKey)) return false;
    (_lastReal[event.logicalKey] ??= Stopwatch())
      ..reset()
      ..start();
    // Observe only. Consuming here would break the real keyboard.
    return false;
  }

  /// Whether a real key event for [key] arrived too recently to also honour a
  /// synthetic one.
  bool shouldDrop(LogicalKeyboardKey key) {
    final seen = _lastReal[key];
    return seen != null && seen.elapsed < _window;
  }
}
