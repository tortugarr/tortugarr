import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:moonfin/util/focus/gamepad/controller_diagnostics.dart';
import 'package:moonfin/util/focus/gamepad/controller_diagnostics_source.dart';

NormalizedGamepadEvent _axisEvent(
  String gamepadId,
  GamepadAxis axis,
  double value,
) => NormalizedGamepadEvent(
  gamepadId: gamepadId,
  timestamp: 0,
  value: value,
  axis: axis,
  rawEvent: GamepadEvent(
    gamepadId: gamepadId,
    timestamp: 0,
    type: KeyType.analog,
    key: axis.name,
    value: value,
  ),
);

NormalizedGamepadEvent _buttonEvent(
  String gamepadId,
  GamepadButton button,
  double value,
) => NormalizedGamepadEvent(
  gamepadId: gamepadId,
  timestamp: 0,
  value: value,
  button: button,
  rawEvent: GamepadEvent(
    gamepadId: gamepadId,
    timestamp: 0,
    type: KeyType.button,
    key: button.name,
    value: value,
  ),
);

void main() {
  group('AxisVerdictTracker', () {
    test('starts unknown', () {
      expect(AxisVerdictTracker().verdict, DiagnosticVerdict.unknown);
    });

    test('one intermediate value proves analog immediately', () {
      final tracker = AxisVerdictTracker()..sample(0.42);
      expect(tracker.verdict, DiagnosticVerdict.analog);
    });

    test('40+ samples of only -1/0/+1 settle digital', () {
      final tracker = AxisVerdictTracker();
      for (var i = 0; i < 40; i++) {
        tracker.sample(i.isEven ? -1 : (i % 3 == 0 ? 0 : 1));
      }
      expect(tracker.verdict, DiagnosticVerdict.digital);
    });

    test('fewer than the threshold of switch-like samples stays unknown', () {
      final tracker = AxisVerdictTracker();
      for (var i = 0; i < 39; i++) {
        tracker.sample(0);
      }
      expect(tracker.verdict, DiagnosticVerdict.unknown);
    });

    test('once analog, later -1/0/+1 samples do not revert it', () {
      final tracker = AxisVerdictTracker()..sample(0.5);
      for (var i = 0; i < 100; i++) {
        tracker.sample(0);
      }
      expect(tracker.verdict, DiagnosticVerdict.analog);
    });

    test('digital then an intermediate value flips to analog (MODE swap)', () {
      final tracker = AxisVerdictTracker();
      for (var i = 0; i < 40; i++) {
        tracker.sample(0);
      }
      expect(tracker.verdict, DiagnosticVerdict.digital);
      tracker.sample(0.33);
      expect(tracker.verdict, DiagnosticVerdict.analog);
    });

    test('values within tolerance count as switch-like, not analog', () {
      final tracker = AxisVerdictTracker();
      for (var i = 0; i < 40; i++) {
        tracker.sample(i.isEven ? 0.999 : -0.005);
      }
      expect(tracker.verdict, DiagnosticVerdict.digital);
    });

    test('reset() returns to unknown and zeroes the counter', () {
      final tracker = AxisVerdictTracker();
      for (var i = 0; i < 39; i++) {
        tracker.sample(0);
      }
      tracker.reset();
      expect(tracker.verdict, DiagnosticVerdict.unknown);
      // Counter was zeroed: one more switch-like sample should not be
      // enough on its own to reach the threshold.
      tracker.sample(0);
      expect(tracker.verdict, DiagnosticVerdict.unknown);
    });
  });

  group('ControllerDiagnosticsFolder', () {
    test('leftStickX then leftStickY produce one left StickChannel', () {
      final folder = ControllerDiagnosticsFolder('pad:0');
      folder.fold(_axisEvent('0', GamepadAxis.leftStickX, 0.5));
      folder.fold(_axisEvent('0', GamepadAxis.leftStickY, -0.25));

      final channels = folder.snapshot().channels;
      final sticks = channels.whereType<StickChannel>().toList();
      expect(sticks.length, 1);
      expect(sticks.single.id, 'left');
      expect(sticks.single.x, 0.5);
      expect(sticks.single.y, -0.25);
    });

    test('a trigger event produces an l2/r2 TriggerChannel', () {
      final folder = ControllerDiagnosticsFolder('pad:0');
      folder.fold(_axisEvent('0', GamepadAxis.leftTrigger, 0.75));
      folder.fold(_axisEvent('0', GamepadAxis.rightTrigger, 0.1));

      final triggers = folder
          .snapshot()
          .channels
          .whereType<TriggerChannel>()
          .toList();
      expect(triggers.length, 2);
      final l2 = triggers.firstWhere((t) => t.id == 'l2');
      final r2 = triggers.firstWhere((t) => t.id == 'r2');
      expect(l2.value, 0.75);
      expect(r2.value, 0.1);
    });

    test('a button event produces a ButtonChannel with pressed true/false', () {
      final folder = ControllerDiagnosticsFolder('pad:0');
      folder.fold(_buttonEvent('0', GamepadButton.a, 1.0));

      var buttons = folder
          .snapshot()
          .channels
          .whereType<ButtonChannel>()
          .toList();
      expect(buttons.single.pressed, true);
      expect(buttons.single.rawName, 'a');

      folder.fold(_buttonEvent('0', GamepadButton.a, 0.0));
      buttons = folder.snapshot().channels.whereType<ButtonChannel>().toList();
      expect(buttons.single.pressed, false);
    });

    test('re-pressing a button moves it to the end, latest last', () {
      final folder = ControllerDiagnosticsFolder('pad:0');
      folder.fold(_buttonEvent('0', GamepadButton.a, 1.0)); // A pressed
      folder.fold(_buttonEvent('0', GamepadButton.a, 0.0)); // A released
      folder.fold(_buttonEvent('0', GamepadButton.b, 1.0)); // B held
      folder.fold(_buttonEvent('0', GamepadButton.a, 1.0)); // A pressed again

      final pressedOrder = folder
          .snapshot()
          .channels
          .whereType<ButtonChannel>()
          .where((b) => b.pressed)
          .map((b) => b.rawName)
          .toList();
      // Both A and B are held, but A was the more recent press, so it must
      // be last -- a LinkedHashMap reassignment alone would leave B last.
      expect(pressedOrder, ['b', 'a']);
    });

    test('events from a different gamepadId than begun are ignored', () {
      final folder = ControllerDiagnosticsFolder('pad:0');
      final changed = folder.fold(_axisEvent('1', GamepadAxis.leftStickX, 0.5));

      expect(changed, false);
      expect(folder.snapshot().channels, isEmpty);
    });
  });

  group('AndroidControllerDiagnosticsFolder', () {
    test('an axis payload produces left/right/hat StickChannels and l2/r2 '
        'TriggerChannels with the right values', () {
      final folder = AndroidControllerDiagnosticsFolder('android-connection-3');
      final changed = folder.foldAxes({
        'connectionId': 'android-connection-3',
        'port': 0,
        'lx': 0.5,
        'ly': -0.25,
        'rx': -0.6,
        'ry': 0.1,
        'hatX': 1.0,
        'hatY': -1.0,
        'l2': 0.75,
        'r2': 0.2,
      });

      expect(changed, true);
      final channels = folder.snapshot().channels;

      final sticks = {
        for (final s in channels.whereType<StickChannel>()) s.id: s,
      };
      expect(sticks.keys.toSet(), {'left', 'right', 'hat'});
      expect(sticks['left']!.x, 0.5);
      expect(sticks['left']!.y, -0.25);
      expect(sticks['right']!.x, -0.6);
      expect(sticks['right']!.y, 0.1);
      expect(sticks['hat']!.x, 1.0);
      expect(sticks['hat']!.y, -1.0);

      final triggers = {
        for (final t in channels.whereType<TriggerChannel>()) t.id: t,
      };
      expect(triggers['l2']!.value, 0.75);
      expect(triggers['r2']!.value, 0.2);
    });

    test('the hat channel IS produced on Android, unlike desktop', () {
      final folder = AndroidControllerDiagnosticsFolder('android-connection-1');
      folder.foldAxes({
        'connectionId': 'android-connection-1',
        'lx': 0.0,
        'ly': 0.0,
        'rx': 0.0,
        'ry': 0.0,
        'hatX': 1.0,
        'hatY': 0.0,
        'l2': 0.0,
        'r2': 0.0,
      });

      final sticks = folder.snapshot().channels.whereType<StickChannel>();
      expect(sticks.any((s) => s.id == 'hat'), true);
    });

    test(
      'a button payload converts to a ButtonChannel with keyCode/keyName/pressed',
      () {
        final folder = AndroidControllerDiagnosticsFolder(
          'android-connection-2',
        );
        final changed = folder.foldButton({
          'connectionId': 'android-connection-2',
          'port': 1,
          'keyCode': 96,
          'keyName': 'KEYCODE_BUTTON_A',
          'pressed': true,
        });

        expect(changed, true);
        final buttons = folder
            .snapshot()
            .channels
            .whereType<ButtonChannel>()
            .toList();
        expect(buttons.single.rawCode, 96);
        expect(buttons.single.rawName, 'KEYCODE_BUTTON_A');
        expect(buttons.single.pressed, true);

        folder.foldButton({
          'connectionId': 'android-connection-2',
          'keyCode': 96,
          'keyName': 'KEYCODE_BUTTON_A',
          'pressed': false,
        });
        final updated = folder
            .snapshot()
            .channels
            .whereType<ButtonChannel>()
            .toList();
        expect(updated.single.pressed, false);
      },
    );

    test('re-pressing a button moves it to the end, latest last', () {
      final folder = AndroidControllerDiagnosticsFolder('android-connection-1');
      folder.foldButton({
        'connectionId': 'android-connection-1',
        'keyCode': 96, // A
        'pressed': true,
      });
      folder.foldButton({
        'connectionId': 'android-connection-1',
        'keyCode': 96, // A released
        'pressed': false,
      });
      folder.foldButton({
        'connectionId': 'android-connection-1',
        'keyCode': 97, // B held
        'pressed': true,
      });
      folder.foldButton({
        'connectionId': 'android-connection-1',
        'keyCode': 96, // A pressed again
        'pressed': true,
      });

      final pressedOrder = folder
          .snapshot()
          .channels
          .whereType<ButtonChannel>()
          .where((b) => b.pressed)
          .map((b) => b.rawCode)
          .toList();
      expect(pressedOrder, [97, 96]);
    });

    test(
      'an axes payload for a different connectionId than begun is ignored',
      () {
        final folder = AndroidControllerDiagnosticsFolder(
          'android-connection-1',
        );
        final changed = folder.foldAxes({
          'connectionId': 'android-connection-9',
          'lx': 0.5,
          'ly': 0.0,
          'rx': 0.0,
          'ry': 0.0,
          'hatX': 0.0,
          'hatY': 0.0,
          'l2': 0.0,
          'r2': 0.0,
        });

        expect(changed, false);
        expect(folder.snapshot().channels, isEmpty);
      },
    );

    test('a channel echoed unchanged alongside another axis moving never '
        'earns a DIGITAL verdict', () {
      final folder = AndroidControllerDiagnosticsFolder('android-connection-1');
      // Every payload carries all six channels; only the left stick actually
      // moves (through switch-like -1/0/1 values on both its axes), while
      // right/hat/l2/r2 are echoed back resting at a constant 0 in every
      // payload.
      for (var i = 0; i < 60; i++) {
        folder.foldAxes({
          'connectionId': 'android-connection-1',
          'lx': i.isEven ? -1.0 : 1.0,
          'ly': i.isEven ? 1.0 : -1.0,
          'rx': 0.0,
          'ry': 0.0,
          'hatX': 0.0,
          'hatY': 0.0,
          'l2': 0.0,
          'r2': 0.0,
        });
      }

      final sticks = {
        for (final s in folder.snapshot().channels.whereType<StickChannel>())
          s.id: s,
      };
      expect(sticks['left']!.verdict, DiagnosticVerdict.digital);
      // These never moved: a constant, repeatedly-echoed 0 must not count as
      // switch-like evidence, or waggling only the left stick would brand
      // the untouched channels DIGITAL too.
      expect(sticks['right']!.verdict, DiagnosticVerdict.unknown);
      expect(sticks['hat']!.verdict, DiagnosticVerdict.unknown);
      final triggers = {
        for (final t in folder.snapshot().channels.whereType<TriggerChannel>())
          t.id: t,
      };
      expect(triggers['l2']!.verdict, DiagnosticVerdict.unknown);
      expect(triggers['r2']!.verdict, DiagnosticVerdict.unknown);
    });

    test(
      'a button payload for a different connectionId than begun is ignored',
      () {
        final folder = AndroidControllerDiagnosticsFolder(
          'android-connection-1',
        );
        final changed = folder.foldButton({
          'connectionId': 'android-connection-9',
          'keyCode': 96,
          'keyName': 'KEYCODE_BUTTON_A',
          'pressed': true,
        });

        expect(changed, false);
        expect(folder.snapshot().channels, isEmpty);
      },
    );
  });
}
