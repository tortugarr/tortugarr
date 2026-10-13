/// Platform-independent data model and verdict inference for the controller
/// test panel.
///
/// See `docs/superpowers/specs/2026-08-20-controller-test-panel-design.md`
/// for the design this implements. This file holds only the model and the
/// inference; platform sources that produce [ControllerDiagnosticsSnapshot]s
/// live in `controller_diagnostics_source.dart`.
library;

/// Whether a channel has been proven to be a real potentiometer, proven to be
/// a switch, or not yet decided. See [AxisVerdictTracker] for how this is
/// inferred.
enum DiagnosticVerdict { unknown, analog, digital }

/// One input on a controller, as shown by the test panel.
///
/// A snapshot is a list of these rather than a fixed-shape object so that
/// input domains we do not support yet (paddles, lightguns) can be added as
/// new subclasses without changing the transport or the panel's structure.
sealed class ControllerChannel {
  const ControllerChannel();
}

/// An analog stick, or the D-pad reported as an axis pair (Android's 'hat').
class StickChannel extends ControllerChannel {
  /// 'left', 'right', or 'hat'. There is no 'hat' channel on desktop -- see
  /// `controller_diagnostics_source.dart`.
  final String id;
  final double x;
  final double y;
  final DiagnosticVerdict verdict;

  /// What the game's stick snap setting makes of [x]/[y], for the test panel.
  /// Null when the platform reports no snapped value.
  final double? snapX;
  final double? snapY;
  final String? snapMode;

  const StickChannel({
    required this.id,
    required this.x,
    required this.y,
    required this.verdict,
    this.snapX,
    this.snapY,
    this.snapMode,
  });

  StickChannel copyWith({
    double? x,
    double? y,
    DiagnosticVerdict? verdict,
    double? snapX,
    double? snapY,
    String? snapMode,
  }) => StickChannel(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    verdict: verdict ?? this.verdict,
    snapX: snapX ?? this.snapX,
    snapY: snapY ?? this.snapY,
    snapMode: snapMode ?? this.snapMode,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StickChannel &&
          other.id == id &&
          other.x == x &&
          other.y == y &&
          other.verdict == verdict &&
          other.snapX == snapX &&
          other.snapY == snapY &&
          other.snapMode == snapMode);

  @override
  int get hashCode => Object.hash(id, x, y, verdict, snapX, snapY, snapMode);

  @override
  String toString() => 'StickChannel($id, x: $x, y: $y, verdict: $verdict)';
}

/// An analog trigger (L2/R2).
class TriggerChannel extends ControllerChannel {
  /// 'l2' or 'r2'.
  final String id;
  final double value;
  final DiagnosticVerdict verdict;

  const TriggerChannel({
    required this.id,
    required this.value,
    required this.verdict,
  });

  TriggerChannel copyWith({double? value, DiagnosticVerdict? verdict}) =>
      TriggerChannel(
        id: id,
        value: value ?? this.value,
        verdict: verdict ?? this.verdict,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TriggerChannel &&
          other.id == id &&
          other.value == value &&
          other.verdict == verdict);

  @override
  int get hashCode => Object.hash(id, value, verdict);

  @override
  String toString() => 'TriggerChannel($id, value: $value, verdict: $verdict)';
}

/// A single button, carrying every link of the naming chain that is
/// available. Links that cannot be resolved (yet) are left null; the panel
/// renders what exists and omits the rest.
class ButtonChannel extends ControllerChannel {
  /// Platform keycode where available (Android). Null on desktop.
  final int? rawCode;

  /// Platform-independent button identifier's name, e.g. 'a', 'dpadUp', or
  /// (on Android) `KeyEvent.keyCodeToString`.
  final String? rawName;

  /// The RetroPad button this maps to, from the active mapping table.
  final String? retroPad;

  /// The RetroPad index the platform resolved this key to, when it could.
  final int? retroPadIndex;

  /// The core's own description of the button, from
  /// `CoreInputDescriptors.describe`.
  final String? label;

  final bool pressed;

  const ButtonChannel({
    this.rawCode,
    this.rawName,
    this.retroPad,
    this.retroPadIndex,
    this.label,
    required this.pressed,
  });

  ButtonChannel copyWith({
    int? rawCode,
    String? rawName,
    String? retroPad,
    int? retroPadIndex,
    String? label,
    bool? pressed,
  }) => ButtonChannel(
    rawCode: rawCode ?? this.rawCode,
    rawName: rawName ?? this.rawName,
    retroPad: retroPad ?? this.retroPad,
    retroPadIndex: retroPadIndex ?? this.retroPadIndex,
    label: label ?? this.label,
    pressed: pressed ?? this.pressed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ButtonChannel &&
          other.rawCode == rawCode &&
          other.rawName == rawName &&
          other.retroPad == retroPad &&
          other.retroPadIndex == retroPadIndex &&
          other.label == label &&
          other.pressed == pressed);

  @override
  int get hashCode =>
      Object.hash(rawCode, rawName, retroPad, retroPadIndex, label, pressed);

  @override
  String toString() =>
      'ButtonChannel(rawName: $rawName, pressed: $pressed, retroPad: $retroPad)';
}

/// The full state of a controller as observed by the test panel at one
/// moment.
class ControllerDiagnosticsSnapshot {
  final String connectionId;
  final int? port;
  final List<ControllerChannel> channels;

  const ControllerDiagnosticsSnapshot({
    required this.connectionId,
    required this.port,
    required this.channels,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerDiagnosticsSnapshot &&
          other.connectionId == connectionId &&
          other.port == port &&
          _listEquals(other.channels, channels));

  @override
  int get hashCode => Object.hash(connectionId, port, Object.hashAll(channels));

  @override
  String toString() =>
      'ControllerDiagnosticsSnapshot(connectionId: $connectionId, port: $port, channels: $channels)';
}

bool _listEquals(List<ControllerChannel> a, List<ControllerChannel> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Infers whether an axis is a real potentiometer or a switch.
///
/// Proving analog takes ONE sample: a switch physically cannot report an
/// intermediate value. Proving digital is absence of evidence, so it stays
/// [DiagnosticVerdict.unknown] until enough samples have been seen.
///
/// Once [DiagnosticVerdict.analog] is reached it is permanent -- there is no
/// hardware event that would make a real potentiometer stop being one.
/// [DiagnosticVerdict.digital], on the other hand, is only ever the panel's
/// best guess from the samples seen so far, so it can still flip back to
/// analog if an intermediate value shows up later. This is what makes a
/// Logitech F310/F710 `MODE` swap self-evident mid-session: the tracker was
/// confidently digital, then a mode swap turns the stick's channel analog
/// (or vice versa for the hat) and the panel shows it happening live.
class AxisVerdictTracker {
  static const double tolerance = 0.02;
  static const int digitalSampleThreshold = 40;

  DiagnosticVerdict _verdict = DiagnosticVerdict.unknown;
  int _switchLikeSamples = 0;

  DiagnosticVerdict get verdict => _verdict;

  /// Folds one observed value into the running verdict.
  void sample(double value) {
    if (_isSwitchLike(value)) {
      if (_verdict == DiagnosticVerdict.analog) {
        // Analog is permanent; switch-like samples afterward (e.g. a
        // resting stick reporting exactly 0) prove nothing either way.
        return;
      }
      _switchLikeSamples++;
      if (_switchLikeSamples >= digitalSampleThreshold) {
        _verdict = DiagnosticVerdict.digital;
      }
      return;
    }
    // Any intermediate value is proof: a switch cannot produce one.
    _verdict = DiagnosticVerdict.analog;
  }

  void reset() {
    _verdict = DiagnosticVerdict.unknown;
    _switchLikeSamples = 0;
  }

  static bool _isSwitchLike(double value) =>
      (value - -1).abs() <= tolerance ||
      value.abs() <= tolerance ||
      (value - 1).abs() <= tolerance;
}
