import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import '../../native_controller_mapping.dart';
import '../../platform_detection.dart';
import 'android_gamepad_channel.dart';
import 'controller_diagnostics.dart';

/// Streams live [ControllerDiagnosticsSnapshot]s for the controller test
/// panel while it is open.
///
/// Mirrors `ControllerMappingCapture`: one platform-independent interface,
/// implementations that know how each platform reports its own events, and a
/// lifecycle the panel drives explicitly (`begin`/`end`/`dispose`) so nothing
/// is sampled while the panel is closed. See
/// `docs/superpowers/specs/2026-08-20-controller-test-panel-design.md`,
/// "Platform sources".
abstract class ControllerDiagnosticsSource {
  /// The implementation for the current platform, or null where unsupported
  /// (Apple platforms: the panel hides, matching how remapping already
  /// behaves there).
  static ControllerDiagnosticsSource? forPlatform() {
    if (PlatformDetection.isAndroid) {
      return _AndroidControllerDiagnosticsSource();
    }
    if (PlatformDetection.isWindows || PlatformDetection.isLinux) {
      return GamepadsControllerDiagnosticsSource();
    }
    return null;
  }

  /// Registers the sink for snapshots. Called once, before [begin].
  void attach(void Function(ControllerDiagnosticsSnapshot) onSnapshot);

  /// Starts streaming snapshots for [connectionId].
  Future<void> begin(String connectionId);

  /// Stops streaming. Safe to call when [begin] was never called.
  Future<void> end();

  /// Releases anything [attach] or [begin] set up.
  void dispose();
}

/// Windows and Linux: folds `Gamepads.normalizedEvents` into a snapshot.
///
/// No native work needed here -- `NormalizedGamepadEvent` already carries
/// platform-independent axis/button identifiers with the conventions the
/// model wants (sticks -1..1, triggers 0..1).
///
/// Deliberately does NOT synthesise a 'hat' StickChannel: the gamepads
/// package normalises the D-pad into buttons (dpadUp/Down/Left/Right) before
/// Dart ever sees it, so there is no axis pair to classify as analog or
/// digital on desktop. The analog/digital verdict is therefore an Android
/// capability in practice; see the design's "No hat channel on desktop".
class GamepadsControllerDiagnosticsSource
    implements ControllerDiagnosticsSource {
  // ~30Hz, matching the design's "Cost" section. Button transitions bypass
  // this and are emitted immediately since they are rare.
  static const Duration _throttleInterval = Duration(milliseconds: 33);

  void Function(ControllerDiagnosticsSnapshot)? _onSnapshot;
  StreamSubscription<NormalizedGamepadEvent>? _subscription;
  ControllerDiagnosticsFolder? _folder;
  Timer? _throttleTimer;
  bool _dirty = false;

  @override
  void attach(void Function(ControllerDiagnosticsSnapshot) onSnapshot) {
    _onSnapshot = onSnapshot;
  }

  @override
  Future<void> begin(String connectionId) async {
    // Subscribed per panel-open rather than for the source's lifetime, same
    // reasoning as capture: nothing should be sampled while the panel (and
    // therefore this source) is not in use.
    await _subscription?.cancel();
    _throttleTimer?.cancel();
    _folder = ControllerDiagnosticsFolder(connectionId);
    _dirty = false;
    _subscription = Gamepads.normalizedEvents.listen(_onEvent);
    _throttleTimer = Timer.periodic(_throttleInterval, (_) => _flushIfDirty());
  }

  void _onEvent(NormalizedGamepadEvent event) {
    final folder = _folder;
    if (folder == null) return;
    if (!folder.fold(event)) return;
    if (event.button != null) {
      _emit();
    } else {
      _dirty = true;
    }
  }

  void _flushIfDirty() {
    if (_dirty) _emit();
  }

  void _emit() {
    final folder = _folder;
    if (folder == null) return;
    _dirty = false;
    _onSnapshot?.call(folder.snapshot());
  }

  @override
  Future<void> end() async {
    await _subscription?.cancel();
    _subscription = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _folder = null;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _folder = null;
    _onSnapshot = null;
  }
}

/// Folds one gamepad's [NormalizedGamepadEvent] stream into a running
/// [ControllerDiagnosticsSnapshot].
///
/// Kept separate from the stream subscription and throttle timer in
/// [GamepadsControllerDiagnosticsSource] so the folding rules -- which axis
/// pair becomes which channel, which events are filtered out -- can be
/// unit-tested without a real gamepad stream.
class ControllerDiagnosticsFolder {
  ControllerDiagnosticsFolder(this.connectionId);

  final String connectionId;

  final Map<String, StickChannel> _sticks = {};
  final Map<String, TriggerChannel> _triggers = {};
  final Map<String, ButtonChannel> _buttons = {};
  final Map<String, AxisVerdictTracker> _axisTrackers = {};

  static const Map<GamepadAxis, (String id, bool isX)> _stickAxes = {
    GamepadAxis.leftStickX: ('left', true),
    GamepadAxis.leftStickY: ('left', false),
    GamepadAxis.rightStickX: ('right', true),
    GamepadAxis.rightStickY: ('right', false),
  };

  static const Map<GamepadAxis, String> _triggerAxes = {
    GamepadAxis.leftTrigger: 'l2',
    GamepadAxis.rightTrigger: 'r2',
  };

  /// Folds one event into the running snapshot. Returns whether it changed
  /// anything, so the source knows whether to bother emitting.
  bool fold(NormalizedGamepadEvent event) {
    // A different gamepad waggling nearby must not bleed into the panel for
    // the one the user selected, same filter as capture uses.
    if (desktopControllerDeviceId(event.gamepadId) != connectionId) {
      return false;
    }
    final axis = event.axis;
    if (axis != null) return _foldAxis(axis, event.value);
    final button = event.button;
    if (button != null) {
      // Remove before reinserting: a LinkedHashMap keeps a reassigned key's
      // original position, so an in-place update would not move it to the
      // end and `snapshot()` would stop emitting latest-last.
      _buttons.remove(button.name);
      _buttons[button.name] = ButtonChannel(
        rawName: button.name,
        pressed: event.value != 0,
      );
      return true;
    }
    return false;
  }

  bool _foldAxis(GamepadAxis axis, double value) {
    final stick = _stickAxes[axis];
    if (stick != null) {
      final (id, isX) = stick;
      _axisTrackers
          .putIfAbsent(_trackerKey(id, isX), AxisVerdictTracker.new)
          .sample(value);
      final existing = _sticks[id];
      _sticks[id] = StickChannel(
        id: id,
        x: isX ? value : (existing?.x ?? 0),
        y: isX ? (existing?.y ?? 0) : value,
        verdict: _combinedVerdict(
          _axisTrackers[_trackerKey(id, true)],
          _axisTrackers[_trackerKey(id, false)],
        ),
      );
      return true;
    }
    final triggerId = _triggerAxes[axis];
    if (triggerId != null) {
      final tracker = _axisTrackers.putIfAbsent(
        triggerId,
        AxisVerdictTracker.new,
      );
      tracker.sample(value);
      _triggers[triggerId] = TriggerChannel(
        id: triggerId,
        value: value,
        verdict: tracker.verdict,
      );
      return true;
    }
    // An axis this source has no channel for (none exist today, but the
    // enum could grow); nothing changed.
    return false;
  }

  static String _trackerKey(String id, bool isX) => '$id.${isX ? 'x' : 'y'}';

  /// A stick's verdict combines its two axis trackers: either proving analog
  /// is enough (a MODE swap can turn only one axis of the pair into a
  /// switch), digital requires both legs to have settled digital.
  static DiagnosticVerdict _combinedVerdict(
    AxisVerdictTracker? x,
    AxisVerdictTracker? y,
  ) {
    final vx = x?.verdict ?? DiagnosticVerdict.unknown;
    final vy = y?.verdict ?? DiagnosticVerdict.unknown;
    if (vx == DiagnosticVerdict.analog || vy == DiagnosticVerdict.analog) {
      return DiagnosticVerdict.analog;
    }
    if (vx == DiagnosticVerdict.digital && vy == DiagnosticVerdict.digital) {
      return DiagnosticVerdict.digital;
    }
    return DiagnosticVerdict.unknown;
  }

  /// The current snapshot. [port] is left to the caller: resolving a
  /// connection id to a port/player is the registry's job, out of scope
  /// here.
  ControllerDiagnosticsSnapshot snapshot({int? port}) =>
      ControllerDiagnosticsSnapshot(
        connectionId: connectionId,
        port: port,
        channels: [..._sticks.values, ..._triggers.values, ..._buttons.values],
      );
}

/// Android: arms `NativePadInput`'s monitor mode over the gamepad channel and
/// folds the axis-snapshot / button-transition payloads it sends back.
///
/// Mirrors `_AndroidControllerMappingCapture` in `controller_mapping_capture.dart`
/// for the channel plumbing (`ensureInstalled`, arm on [begin], disarm on
/// [end]/[dispose]) -- monitor mode is the read-only sibling of capture mode,
/// see the design doc's "Placement and lifecycle" invariants.
class _AndroidControllerDiagnosticsSource
    implements ControllerDiagnosticsSource {
  void Function(ControllerDiagnosticsSnapshot)? _onSnapshot;
  AndroidControllerDiagnosticsFolder? _folder;

  @override
  void attach(void Function(ControllerDiagnosticsSnapshot) onSnapshot) {
    _onSnapshot = onSnapshot;
    AndroidGamepadChannel.ensureInstalled();
    AndroidGamepadChannel.setControllerDiagnosticsAxesHandler(_onAxes);
    AndroidGamepadChannel.setControllerDiagnosticsButtonHandler(_onButton);
  }

  @override
  Future<void> begin(String connectionId) async {
    // A fresh folder per panel-open, same reasoning as capture: nothing
    // carries over from a previous device or a previous time the panel was
    // open, including verdict trackers -- the design requires a reset on
    // device change.
    _folder = AndroidControllerDiagnosticsFolder(connectionId);
    await AndroidGamepadChannel.setControllerDiagnostics(
      true,
      connectionId: connectionId,
    );
  }

  Future<dynamic> _onAxes(MethodCall call) async {
    final folder = _folder;
    if (folder == null) return;
    final args = (call.arguments as Map).cast<String, dynamic>();
    if (!folder.foldAxes(args)) return;
    _onSnapshot?.call(folder.snapshot());
  }

  Future<dynamic> _onButton(MethodCall call) async {
    final folder = _folder;
    if (folder == null) return;
    final args = (call.arguments as Map).cast<String, dynamic>();
    if (!folder.foldButton(args)) return;
    _onSnapshot?.call(folder.snapshot());
  }

  @override
  Future<void> end() async {
    _folder = null;
    await AndroidGamepadChannel.setControllerDiagnostics(false);
  }

  @override
  void dispose() {
    _folder = null;
    unawaited(AndroidGamepadChannel.setControllerDiagnostics(false));
    AndroidGamepadChannel.setControllerDiagnosticsAxesHandler(null);
    AndroidGamepadChannel.setControllerDiagnosticsButtonHandler(null);
    _onSnapshot = null;
  }
}

/// Folds Android's diagnostics payloads into a running
/// [ControllerDiagnosticsSnapshot].
///
/// Deliberately a separate type from [ControllerDiagnosticsFolder] rather
/// than a reuse of it: the desktop folder consumes one axis or one button at
/// a time off `Gamepads.normalizedEvents`, while `NativePadInput` reports a
/// whole axis snapshot (all four stick axes, the hat, both triggers) per
/// payload and buttons by raw keycode, not a shared enum. Forcing one shape
/// onto the other would distort whichever one loses. What *is* shared is the
/// model this folds into and the verdict-tracking rule, both already
/// platform-independent in `controller_diagnostics.dart`.
///
/// Android reports a real 'hat' axis pair (the D-pad, as an axis on this
/// platform) -- unlike desktop, where the gamepads package has already
/// normalised the D-pad into buttons before Dart sees it. See the design
/// doc's "No hat channel on desktop".
class AndroidControllerDiagnosticsFolder {
  AndroidControllerDiagnosticsFolder(this.connectionId);

  final String connectionId;

  final Map<String, StickChannel> _sticks = {};
  final Map<String, TriggerChannel> _triggers = {};
  final Map<int, ButtonChannel> _buttons = {};
  final Map<String, AxisVerdictTracker> _axisTrackers = {};

  // Every payload echoes all six channels, so only a changed value is evidence.
  final Map<String, double> _lastAxisValue = {};

  /// Folds one axis-snapshot payload. Returns false (nothing folded) when the
  /// payload is for a different connection than [connectionId], same filter
  /// capture and the desktop folder both apply.
  bool foldAxes(Map<String, dynamic> payload) {
    if (payload['connectionId']?.toString() != connectionId) return false;

    _foldStick(
      'left',
      payload['lx'],
      payload['ly'],
      snapX: (payload['snapLx'] as num?)?.toDouble(),
      snapY: (payload['snapLy'] as num?)?.toDouble(),
      snapMode: payload['snap']?.toString(),
    );
    _foldStick('right', payload['rx'], payload['ry']);
    _foldStick('hat', payload['hatX'], payload['hatY']);
    _foldTrigger('l2', payload['l2']);
    _foldTrigger('r2', payload['r2']);
    return true;
  }

  /// Folds one button-transition payload. Returns false when it is for a
  /// different connection than [connectionId].
  bool foldButton(Map<String, dynamic> payload) {
    if (payload['connectionId']?.toString() != connectionId) return false;
    final keyCode = (payload['keyCode'] as num?)?.toInt();
    if (keyCode == null) return false;
    // Reinsert to keep latest-last; see the desktop folder.
    _buttons.remove(keyCode);
    _buttons[keyCode] = ButtonChannel(
      rawCode: keyCode,
      rawName: payload['keyName']?.toString(),
      retroPadIndex: (payload['retroPadIndex'] as num?)?.toInt(),
      pressed: payload['pressed'] == true,
    );
    return true;
  }

  void _foldStick(
    String id,
    dynamic rawX,
    dynamic rawY, {
    double? snapX,
    double? snapY,
    String? snapMode,
  }) {
    final x = (rawX as num?)?.toDouble() ?? 0.0;
    final y = (rawY as num?)?.toDouble() ?? 0.0;
    _sampleIfChanged(_trackerKey(id, true), x);
    _sampleIfChanged(_trackerKey(id, false), y);
    _sticks[id] = StickChannel(
      id: id,
      x: x,
      y: y,
      verdict: _combinedVerdict(
        _axisTrackers[_trackerKey(id, true)],
        _axisTrackers[_trackerKey(id, false)],
      ),
      snapX: snapX,
      snapY: snapY,
      snapMode: snapMode,
    );
  }

  void _foldTrigger(String id, dynamic rawValue) {
    final value = (rawValue as num?)?.toDouble() ?? 0.0;
    _sampleIfChanged(id, value);
    _triggers[id] = TriggerChannel(
      id: id,
      value: value,
      verdict: _axisTrackers[id]!.verdict,
    );
  }

  /// Samples only a changed value: a resting channel is echoed, not evidence.
  void _sampleIfChanged(String key, double value) {
    final tracker = _axisTrackers.putIfAbsent(key, AxisVerdictTracker.new);
    if (_lastAxisValue[key] != value) {
      tracker.sample(value);
    }
    _lastAxisValue[key] = value;
  }

  static String _trackerKey(String id, bool isX) => '$id.${isX ? 'x' : 'y'}';

  /// A stick's verdict combines its two axis trackers, same rule as the
  /// desktop folder: either leg proving analog is enough, both legs must
  /// settle digital.
  static DiagnosticVerdict _combinedVerdict(
    AxisVerdictTracker? x,
    AxisVerdictTracker? y,
  ) {
    final vx = x?.verdict ?? DiagnosticVerdict.unknown;
    final vy = y?.verdict ?? DiagnosticVerdict.unknown;
    if (vx == DiagnosticVerdict.analog || vy == DiagnosticVerdict.analog) {
      return DiagnosticVerdict.analog;
    }
    if (vx == DiagnosticVerdict.digital && vy == DiagnosticVerdict.digital) {
      return DiagnosticVerdict.digital;
    }
    return DiagnosticVerdict.unknown;
  }

  /// The current snapshot. [port] is left to the caller, same as the desktop
  /// folder.
  ControllerDiagnosticsSnapshot snapshot({int? port}) =>
      ControllerDiagnosticsSnapshot(
        connectionId: connectionId,
        port: port,
        channels: [..._sticks.values, ..._triggers.values, ..._buttons.values],
      );
}
