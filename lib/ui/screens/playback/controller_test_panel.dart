import 'package:flutter/material.dart';

import '../../../util/focus/gamepad/controller_diagnostics.dart';

/// Read-only diagnostic view for the currently selected controller, shown as a
/// sub-view of [NativeControllerMappingScreen].
///
/// See `docs/superpowers/specs/2026-08-20-controller-test-panel-design.md`.
/// Rebuilds up to ~30x/sec while a live [ControllerDiagnosticsSource] is
/// streaming, so everything here is kept cheap: no animations, no images, just
/// small painted widgets driven directly by the latest snapshot.
class ControllerTestPanel extends StatelessWidget {
  const ControllerTestPanel({
    super.key,
    required this.snapshot,
    required this.deviceName,
    this.exitHoldProgress = 0,
    this.port,
  });

  /// The latest reading, or null before the first snapshot has arrived.
  final ControllerDiagnosticsSnapshot? snapshot;

  /// The name of the controller being tested, for the header.
  final String deviceName;

  /// How far through the hold-to-exit gesture the user is, 0..1. Rendered as a
  /// countdown ring so the wait is visible instead of guesswork.
  final double exitHoldProgress;

  /// The controller's player slot, for the header tag; null shows
  /// "Unassigned" rather than omitting the slot silently.
  final int? port;

  static const _accent = Color(0xFF3F8CFF);
  static const _dim = Colors.white54;
  static const _bright = Colors.white;

  List<ControllerChannel> get _channels => snapshot?.channels ?? const [];

  StickChannel? _stick(String id) {
    for (final channel in _channels) {
      if (channel is StickChannel && channel.id == id) return channel;
    }
    return null;
  }

  TriggerChannel? _trigger(String id) {
    for (final channel in _channels) {
      if (channel is TriggerChannel && channel.id == id) return channel;
    }
    return null;
  }

  /// The most recently pressed button, per the design's "Last button" panel.
  /// The folder reinserts on update, so the last pressed match is the latest.
  ButtonChannel? get _lastPressed {
    ButtonChannel? found;
    for (final channel in _channels) {
      if (channel is ButtonChannel && channel.pressed) found = channel;
    }
    return found;
  }

  String get _portTag => port != null ? 'P${port! + 1}' : 'Unassigned';

  static String _verdictLabel(DiagnosticVerdict verdict) => switch (verdict) {
    DiagnosticVerdict.analog => 'ANALOG',
    DiagnosticVerdict.digital => 'DIGITAL',
    DiagnosticVerdict.unknown => '--',
  };

  @override
  Widget build(BuildContext context) {
    final hat = _stick('hat');
    final left = _stick('left');
    final right = _stick('right');
    final l2 = _trigger('l2');
    final r2 = _trigger('r2');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Controller test',
                style: TextStyle(
                  color: _bright,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '[$deviceName - $_portTag]',
                style: const TextStyle(color: _dim, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StickField(label: 'Left stick', stick: left),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _StickField(label: 'Right stick', stick: right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DpadRow(hat: hat),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _TriggerMeter(label: 'L2', trigger: l2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TriggerMeter(label: 'R2', trigger: r2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Last button',
            style: TextStyle(color: _bright, fontSize: 16),
          ),
          const SizedBox(height: 4),
          // Two lines' worth, always: a press turns the placeholder into a raw
          // code plus a button name, and the panel must not grow to fit it.
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.topLeft,
              child: _LastButton(button: _lastPressed),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: Row(
              children: [
                // The ring only appears while B is actually held, so the footer
                // stays quiet during normal testing.
                if (exitHoldProgress > 0) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: exitHoldProgress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(_bright),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keep holding B to go back...',
                    style: const TextStyle(color: _bright, fontSize: 12),
                  ),
                ] else
                  const Text(
                    'Hold B to go back      [ unsupported: paddle / lightgun ]',
                    style: TextStyle(color: _dim, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One analog stick: a small square field with a dot at the live position,
/// the raw numbers beneath it, and the inferred verdict.
class _StickField extends StatelessWidget {
  const _StickField({required this.label, required this.stick});

  final String label;
  final StickChannel? stick;

  @override
  Widget build(BuildContext context) {
    final x = stick?.x ?? 0.0;
    final y = stick?.y ?? 0.0;
    final verdict = stick?.verdict ?? DiagnosticVerdict.unknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 46,
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0)),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: ControllerTestPanel._accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${x.toStringAsFixed(2)}/${y.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (stick?.snapX != null && stick?.snapY != null)
          Text(
            'snap ${stick!.snapX!.toStringAsFixed(2)}/'
            '${stick!.snapY!.toStringAsFixed(2)}'
            '${stick!.snapMode == null ? '' : ' (${stick!.snapMode!})'}',
            style: const TextStyle(
              color: ControllerTestPanel._accent,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        Text(
          ControllerTestPanel._verdictLabel(verdict),
          style: const TextStyle(
            color: ControllerTestPanel._dim,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// The D-pad row. When [hat] is null (desktop, where the gamepads package
/// normalises the D-pad into buttons before Dart ever sees it) this states the
/// platform difference instead of silently omitting the row -- see the
/// design's "Platform differences to state, not hide".
class _DpadRow extends StatelessWidget {
  const _DpadRow({required this.hat});

  final StickChannel? hat;

  @override
  Widget build(BuildContext context) {
    if (hat == null) {
      return const Row(
        children: [
          Text('D-pad', style: TextStyle(color: Colors.white70, fontSize: 14)),
          SizedBox(width: 12),
          Text(
            'reported as buttons',
            style: TextStyle(
              color: ControllerTestPanel._dim,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    final left = hat!.x < -0.5;
    final right = hat!.x > 0.5;
    final up = hat!.y < -0.5;
    final down = hat!.y > 0.5;
    final glyphs = [
      left ? '<' : '-',
      up ? '^' : '-',
      right ? '>' : '-',
      down ? 'v' : '-',
    ].join(' ');
    return Row(
      children: [
        // There might be a better graphical display option here but this works.
        const Text(
          'D-pad',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Text(
          glyphs,
          style: const TextStyle(
            color: ControllerTestPanel._bright,
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          ControllerTestPanel._verdictLabel(hat!.verdict),
          style: const TextStyle(color: ControllerTestPanel._dim, fontSize: 12),
        ),
      ],
    );
  }
}

/// An analog trigger rendered as a text bar meter, matching the design's
/// ASCII (`L2 ###..... `).
class _TriggerMeter extends StatelessWidget {
  const _TriggerMeter({required this.label, required this.trigger});

  final String label;
  final TriggerChannel? trigger;

  static const _barLength = 10;

  @override
  Widget build(BuildContext context) {
    final value = (trigger?.value ?? 0.0).clamp(0.0, 1.0);
    final verdict = trigger?.verdict ?? DiagnosticVerdict.unknown;
    final filled = (value * _barLength).round();
    final bar = '#' * filled + '.' * (_barLength - filled);
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Text(
          bar,
          style: const TextStyle(
            color: ControllerTestPanel._bright,
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ControllerTestPanel._verdictLabel(verdict),
          style: const TextStyle(color: ControllerTestPanel._dim, fontSize: 12),
        ),
      ],
    );
  }
}

/// The naming chain for the most recently pressed button. Per the design's
/// "Button naming chain", each link is shown only when it resolved; missing
/// links are omitted rather than rendered as "null".
class _LastButton extends StatelessWidget {
  const _LastButton({required this.button});

  final ButtonChannel? button;

  @override
  Widget build(BuildContext context) {
    final b = button;
    if (b == null) {
      return const Text(
        'No button pressed yet.',
        style: TextStyle(color: ControllerTestPanel._dim, fontSize: 14),
      );
    }

    final lines = <String>[];
    if (b.rawCode != null || b.rawName != null) {
      final parts = <String>[
        if (b.rawCode != null) 'key ${b.rawCode}',
        if (b.rawName != null) '(${b.rawName})',
      ];
      lines.add(parts.join(' '));
    }
    // The user's POV: the button they know, and what the core/game calls it.
    // The raw code stays on the line above, since that is what diagnoses a pad
    // reporting something unexpected.
    if (b.retroPad != null) {
      lines.add(
        b.label != null
            ? 'Button ${b.retroPad} (${b.label})'
            : 'Button ${b.retroPad}',
      );
    } else if (b.label != null) {
      lines.add('(${b.label})');
    }

    if (lines.isEmpty) {
      return const Text(
        'No button pressed yet.',
        style: TextStyle(color: ControllerTestPanel._dim, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: const TextStyle(
                color: ControllerTestPanel._bright,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}
