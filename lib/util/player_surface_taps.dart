import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Tells a single tap on the player surface from a double tap without a
/// [DoubleTapGestureRecognizer].
///
/// That recognizer holds the gesture arena after every first tap, so each
/// button under it only fires once the double-tap timeout runs out. Here the
/// controls win their taps straight away, and only a tap that reached the
/// surface waits to see whether a second one follows.
///
/// Every pointer down, up and cancel under the surface goes to [pointerDown]
/// and [pointerUp] through a [Listener], and the surface's own taps go to
/// [tapUp].
class PlayerSurfaceTaps {
  PlayerSurfaceTaps({required this.onSingleTap, required this.onDoubleTap});

  final VoidCallback onSingleTap;

  /// Gets the second tap's position, local to the surface.
  final ValueChanged<Offset> onDoubleTap;

  Timer? _timer;
  Offset? _firstTap;
  bool _secondDown = false;

  void pointerDown(PointerDownEvent event) {
    final first = _firstTap;
    if (first == null || _secondDown) return;
    // Same rule as the recognizer: a press near the first tap stops the clock
    // and the first tap waits on how it ends. One further away doesn't count.
    if ((event.position - first).distance > kDoubleTapSlop) return;
    _timer?.cancel();
    _timer = null;
    _secondDown = true;
  }

  void pointerUp(PointerEvent event) {
    if (!_secondDown) return;
    // A press that ends as a surface tap reaches tapUp later in this same
    // dispatch. One that went to a control or turned into a drag never does,
    // which leaves the first tap a single tap.
    scheduleMicrotask(() {
      if (!_secondDown) return;
      _secondDown = false;
      _resolveSingle();
    });
  }

  void tapUp(TapUpDetails details) {
    if (_secondDown) {
      _secondDown = false;
      _firstTap = null;
      onDoubleTap(details.localPosition);
      return;
    }
    // A tap too far from a waiting one settles that one and starts over.
    _resolveSingle();
    _firstTap = details.globalPosition;
    _timer = Timer(kDoubleTapTimeout, _resolveSingle);
  }

  /// Drops a tap that is still waiting on a second one.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _firstTap = null;
    _secondDown = false;
  }

  void _resolveSingle() {
    _timer?.cancel();
    _timer = null;
    if (_firstTap == null) return;
    _firstTap = null;
    onSingleTap();
  }
}
