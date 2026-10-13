import 'dart:async';

import 'package:gamepads/gamepads.dart';

/// Which side of the deadzone [value] sits on, as -1, 0 or 1.
int quantiseAxis(double value, double deadzone) => value <= -deadzone
    ? -1
    : value >= deadzone
    ? 1
    : 0;

/// Admits axis events only once their axis has proven it can rest centred.
///
/// The Linux fallback mapping guesses axis roles for pads the controller
/// database does not know, and a trigger it mislabels as a stick rests at full
/// deflection, which reads as a stick held hard over from launch. A real stick
/// reports centred as soon as the pad connects, so one that never has is not a
/// stick.
class GamepadAxisGate {
  GamepadAxisGate({required this.deadzone});

  final double deadzone;
  final Set<(String, GamepadAxis)> _settled = <(String, GamepadAxis)>{};

  bool admit(String gamepadId, GamepadAxis axis, double value) {
    if (value.abs() < deadzone) {
      _settled.add((gamepadId, axis));
      return true;
    }
    return _settled.contains((gamepadId, axis));
  }
}

/// Turns a held scroll axis into scroll steps at a steady pace.
///
/// One step fires on the edge into a direction and a timer carries it while the
/// stick stays held, so the rate is set here rather than by however often the
/// pad happens to report.
class GamepadScrollRepeater {
  GamepadScrollRepeater({required this.deadzone, required this.onStep});

  static const Duration _interval = Duration(milliseconds: 50);

  final double deadzone;
  final void Function(GamepadAxis axis, int direction) onStep;

  final Map<GamepadAxis, int> _direction = <GamepadAxis, int>{};
  final Map<GamepadAxis, Timer> _timers = <GamepadAxis, Timer>{};

  void onAxis(GamepadAxis axis, double value) {
    final direction = quantiseAxis(value, deadzone);
    if (direction == (_direction[axis] ?? 0)) return;
    _direction[axis] = direction;
    _timers.remove(axis)?.cancel();
    if (direction == 0) return;
    onStep(axis, direction);
    _timers[axis] = Timer.periodic(_interval, (_) => onStep(axis, direction));
  }

  void stop() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _direction.clear();
  }
}
