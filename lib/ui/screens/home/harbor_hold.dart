import 'dart:async';

/// Hold-to-glide for Harbor: one step on press, then steps by themselves for
/// as long as the key is held, stopping the moment it is let go.
///
/// The glide runs on its own clock from key down to key up instead of the
/// remote's key repeat, so it feels the same on every remote, including the
/// ones whose repeats arrive late or not at all.
class HarborHold {
  HarborHold({
    required this.onStep,
    this.onRelease,
    this.delay = const Duration(milliseconds: 320),
    this.startInterval = const Duration(milliseconds: 165),
    this.endInterval = const Duration(milliseconds: 65),
    this.rampUp = const Duration(milliseconds: 2000),
  });

  /// Moves one step in [direction] (-1 or 1). Returns false when there is
  /// nothing more to move to; the glide then stops.
  final bool Function(int direction) onStep;

  /// Called once when a held key is let go (also after a plain tap).
  final void Function()? onRelease;

  /// How long the key must stay down before the glide starts.
  final Duration delay;

  /// The step interval when the glide starts and after [rampUp].
  final Duration startInterval;
  final Duration endInterval;
  final Duration rampUp;

  Timer? _timer;
  int _direction = 0;
  Duration _gliding = Duration.zero;
  Duration _pause = Duration.zero;
  bool _started = false;
  bool _braked = false;

  /// True from key down to key up.
  bool get holding => _direction != 0;

  /// True once the glide has started stepping by itself.
  bool get gliding => holding && _started;

  /// The step interval right now; a glide speeds up the longer it is held.
  Duration get interval {
    if (rampUp <= Duration.zero) return endInterval;
    final t = (_gliding.inMicroseconds / rampUp.inMicroseconds).clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t);
    final us =
        startInterval.inMicroseconds +
        (endInterval.inMicroseconds - startInterval.inMicroseconds) * eased;
    return Duration(microseconds: us.round());
  }

  /// Key down. A second press in the same direction while held (a remote's
  /// own key repeat) is ignored.
  void press(int direction) {
    if (direction == _direction) return;
    _cancel();
    _direction = direction;
    _gliding = Duration.zero;
    if (!onStep(direction)) {
      return;
    }
    _timer = Timer(delay, _tick);
  }

  /// Key up.
  void release() {
    if (!holding) return;
    _cancel();
    onRelease?.call();
  }

  /// Brakes the glide: holds it still for [duration] before the next step
  /// and drops it back to its starting speed to build up again, so a new deck
  /// is seen before the cards rush on.
  void brake(Duration duration) {
    _pause = duration;
    _gliding = Duration.zero;
    _braked = true;
  }

  void dispose() => _cancel();

  void _tick() {
    if (!holding) return;
    _started = true;
    if (!onStep(_direction)) {
      _timer = null;
      return;
    }
    final next = interval;
    // A brake from inside this step keeps the ramp at its start.
    if (_braked) {
      _braked = false;
    } else {
      _gliding += next;
    }
    final wait = next + _pause;
    _pause = Duration.zero;
    _timer = Timer(wait, _tick);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _direction = 0;
    _gliding = Duration.zero;
    _pause = Duration.zero;
    _started = false;
    _braked = false;
  }
}
