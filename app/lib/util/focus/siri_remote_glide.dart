import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_tvos/flutter_tvos.dart'
    show TvRemoteController, TvRemoteTouchEvent, TvRemoteTouchPhase;

import 'gamepad/gamepad_key_synthesizer.dart';

/// Turns Siri Remote touchpad gestures into focus navigation that feels like
/// the native tvOS focus engine: a slow drag steps focus one item at a time as
/// the finger travels, and a quick flick keeps gliding a few more items with
/// deceleration after the finger lifts. Touching the pad again brakes a glide,
/// the same way it catches a scroll on a native screen.
///
/// The engine's own swipe detectors are switched off by config, since one
/// emits a single arrow per gesture and the other latches while the finger
/// rests and runs focus away. Clicks and buttons stay native. Steps go out as
/// real arrow key events through [GamepadKeySynthesizer], so every existing
/// key handler and focus widget behaves exactly as it does for a click.
///
/// While a native view controller covers Flutter the engine stops forwarding
/// touches, so this layer goes quiet on its own.
class SiriRemoteGlide {
  SiriRemoteGlide._();

  static final SiriRemoteGlide instance = SiriRemoteGlide._();

  /// Finger travel in normalized pad units before the first focus step. The
  /// pad is 2.0 units across, so a full slow drag moves about five items.
  static const double _firstStepTravel = 0.28;

  /// Travel between steps after the first.
  static const double _stepTravel = 0.36;

  /// Release velocity, in pad units per second, below which the gesture is a
  /// drag and stops where the finger stopped.
  static const double _flickMinVelocity = 1.6;

  /// Additional glide steps granted per unit of velocity beyond the minimum.
  static const double _flickStepsPerUnit = 1.4;

  static const int _maxGlideSteps = 7;

  /// First glide step fires this long after release, and each following step
  /// waits [_glideDecay] times longer than the last, which reads as the focus
  /// decelerating.
  static const Duration _glideInitialInterval = Duration(milliseconds: 75);
  static const double _glideDecay = 1.38;

  /// Velocity is measured over this trailing window so it reflects how the
  /// gesture ended, not its average.
  static const Duration _velocityWindow = Duration(milliseconds: 90);

  final GamepadKeySynthesizer _synthesizer = GamepadKeySynthesizer();
  final List<_TouchSample> _samples = <_TouchSample>[];
  final Stopwatch _clock = Stopwatch()..start();

  /// Fixed timestamps for tests. The velocity math reads wall-clock time,
  /// which a fake-async test can't control through the Stopwatch.
  @visibleForTesting
  static Duration? debugNowOverride;

  Duration get _now => debugNowOverride ?? _clock.elapsed;

  bool _attached = false;
  bool _touching = false;
  double _lastX = 0;
  double _lastY = 0;
  double _accX = 0;
  double _accY = 0;
  bool _steppedThisGesture = false;
  Timer? _glideTimer;
  int _glideStepsLeft = 0;
  GamepadNavKey? _glideDirection;
  Duration _glideInterval = _glideInitialInterval;

  void attach() {
    if (_attached) return;
    _attached = true;
    TvRemoteController.instance.addRawListener(_onTouch);
  }

  @visibleForTesting
  void debugReset() {
    _cancelGlide();
    _synthesizer.releaseAll();
    _touching = false;
    _samples.clear();
  }

  @visibleForTesting
  void debugHandleTouch(TvRemoteTouchEvent event) => _onTouch(event);

  void _onTouch(TvRemoteTouchEvent event) {
    switch (event.phase) {
      case TvRemoteTouchPhase.started:
        _cancelGlide();
        _beginGesture(event.x, event.y);
      case TvRemoteTouchPhase.move:
        if (!_touching) {
          _beginGesture(event.x, event.y);
          return;
        }
        _onMove(event.x, event.y);
      case TvRemoteTouchPhase.ended:
        _onRelease();
      case TvRemoteTouchPhase.cancelled:
        _touching = false;
        _samples.clear();
      case TvRemoteTouchPhase.clickStart:
        _cancelGlide();
      case TvRemoteTouchPhase.loc:
      case TvRemoteTouchPhase.clickEnd:
        break;
    }
  }

  void _beginGesture(double x, double y) {
    _touching = true;
    _lastX = x;
    _lastY = y;
    _accX = 0;
    _accY = 0;
    _steppedThisGesture = false;
    _samples
      ..clear()
      ..add(_TouchSample(_now, x, y));
  }

  void _onMove(double x, double y) {
    final dx = x - _lastX;
    final dy = y - _lastY;
    _lastX = x;
    _lastY = y;

    // A reversal replaces the accumulator instead of unwinding it, so
    // changing direction mid drag responds immediately.
    _accX = dx.sign != 0 && dx.sign != _accX.sign ? dx : _accX + dx;
    _accY = dy.sign != 0 && dy.sign != _accY.sign ? dy : _accY + dy;

    final now = _now;
    _samples.add(_TouchSample(now, x, y));
    _samples.removeWhere((s) => now - s.time > _velocityWindow);

    final threshold = _steppedThisGesture ? _stepTravel : _firstStepTravel;
    final horizontal = _accX.abs() >= _accY.abs();
    final travel = horizontal ? _accX : _accY;
    if (travel.abs() < threshold) return;

    final direction = horizontal
        ? (travel > 0 ? GamepadNavKey.right : GamepadNavKey.left)
        // The pad reports up as positive y.
        : (travel > 0 ? GamepadNavKey.up : GamepadNavKey.down);
    _step(direction);
    _steppedThisGesture = true;
    if (horizontal) {
      _accX -= travel.sign * threshold;
      _accY = 0;
    } else {
      _accY -= travel.sign * threshold;
      _accX = 0;
    }
  }

  void _onRelease() {
    if (!_touching) return;
    _touching = false;

    if (_samples.length < 2) {
      _samples.clear();
      return;
    }
    final first = _samples.first;
    final last = _samples.last;
    _samples.clear();
    final seconds = (last.time - first.time).inMicroseconds / 1e6;
    if (seconds <= 0) return;

    final vx = (last.x - first.x) / seconds;
    final vy = (last.y - first.y) / seconds;
    final horizontal = vx.abs() >= vy.abs();
    final speed = horizontal ? vx.abs() : vy.abs();
    if (speed < _flickMinVelocity) return;

    final direction = horizontal
        ? (vx > 0 ? GamepadNavKey.right : GamepadNavKey.left)
        : (vy > 0 ? GamepadNavKey.up : GamepadNavKey.down);
    final extra = ((speed - _flickMinVelocity) * _flickStepsPerUnit).round() + 1;
    _startGlide(direction, extra.clamp(1, _maxGlideSteps));
  }

  void _startGlide(GamepadNavKey direction, int steps) {
    _cancelGlide();
    _glideDirection = direction;
    _glideStepsLeft = steps;
    _glideInterval = _glideInitialInterval;
    _glideTimer = Timer(_glideInterval, _onGlideTick);
  }

  void _onGlideTick() {
    final direction = _glideDirection;
    if (direction == null) return;
    _step(direction);
    _glideStepsLeft--;
    if (_glideStepsLeft <= 0) {
      _cancelGlide();
      return;
    }
    _glideInterval = Duration(
      microseconds: (_glideInterval.inMicroseconds * _glideDecay).round(),
    );
    _glideTimer = Timer(_glideInterval, _onGlideTick);
  }

  void _cancelGlide() {
    _glideTimer?.cancel();
    _glideTimer = null;
    _glideStepsLeft = 0;
    _glideDirection = null;
  }

  void _step(GamepadNavKey direction) {
    _synthesizer.press(direction);
    _synthesizer.release(direction);
  }
}

class _TouchSample {
  const _TouchSample(this.time, this.x, this.y);

  final Duration time;
  final double x;
  final double y;
}
