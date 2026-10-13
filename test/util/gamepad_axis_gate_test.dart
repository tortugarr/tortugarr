import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:moonfin/util/focus/gamepad/gamepad_axis_gate.dart';

void main() {
  group('GamepadAxisGate', () {
    late GamepadAxisGate gate;

    setUp(() => gate = GamepadAxisGate(deadzone: 0.5));

    test('drops an axis that rests past the deadzone from its first event', () {
      // A trigger the fallback mapping mislabelled as a stick rests at full
      // deflection and never reports centred.
      expect(gate.admit('pad', GamepadAxis.rightStickY, 1.0), isFalse);
      expect(gate.admit('pad', GamepadAxis.rightStickY, 1.0), isFalse);
      expect(gate.admit('pad', GamepadAxis.rightStickY, 0.98), isFalse);
    });

    test('admits an axis from its first centred report onward', () {
      expect(gate.admit('pad', GamepadAxis.rightStickY, 0.0), isTrue);
      expect(gate.admit('pad', GamepadAxis.rightStickY, 1.0), isTrue);
      expect(gate.admit('pad', GamepadAxis.rightStickY, -1.0), isTrue);
    });

    test('admits a flick whose ramp passes through the deadzone', () {
      expect(gate.admit('pad', GamepadAxis.leftStickY, 0.2), isTrue);
      expect(gate.admit('pad', GamepadAxis.leftStickY, 0.9), isTrue);
    });

    test('tracks each axis on each pad on its own', () {
      expect(gate.admit('a', GamepadAxis.rightStickY, 0.0), isTrue);
      expect(gate.admit('a', GamepadAxis.rightStickX, 0.8), isFalse);
      expect(gate.admit('b', GamepadAxis.rightStickY, 0.8), isFalse);
      expect(gate.admit('a', GamepadAxis.rightStickY, 0.8), isTrue);
    });
  });

  group('GamepadScrollRepeater', () {
    testWidgets('a held direction steps at the timer pace, not the pad', (
      tester,
    ) async {
      final steps = <(GamepadAxis, int)>[];
      final repeater = GamepadScrollRepeater(
        deadzone: 0.5,
        onStep: (axis, direction) => steps.add((axis, direction)),
      );

      // A jittering pad reports far faster than anyone wants to scroll.
      for (var i = 0; i < 25; i++) {
        repeater.onAxis(GamepadAxis.rightStickY, 0.95);
      }
      expect(steps, [(GamepadAxis.rightStickY, 1)]);

      await tester.pump(const Duration(milliseconds: 500));
      expect(steps.length, 11);
      expect(steps.every((s) => s.$2 == 1), isTrue);

      repeater.onAxis(GamepadAxis.rightStickY, 0.0);
      await tester.pump(const Duration(seconds: 1));
      expect(steps.length, 11);
    });

    testWidgets('flicking across releases the old direction first', (
      tester,
    ) async {
      final steps = <int>[];
      final repeater = GamepadScrollRepeater(
        deadzone: 0.5,
        onStep: (axis, direction) => steps.add(direction),
      );

      repeater.onAxis(GamepadAxis.rightStickY, 1.0);
      repeater.onAxis(GamepadAxis.rightStickY, -1.0);
      await tester.pump(const Duration(milliseconds: 100));
      repeater.stop();

      expect(steps.first, 1);
      expect(steps.skip(1).every((d) => d == -1), isTrue);
    });

    testWidgets('stop ends the repeat immediately', (tester) async {
      var steps = 0;
      final repeater = GamepadScrollRepeater(
        deadzone: 0.5,
        onStep: (_, _) => steps++,
      );

      repeater.onAxis(GamepadAxis.rightStickX, -1.0);
      repeater.stop();
      await tester.pump(const Duration(seconds: 1));

      expect(steps, 1);
    });
  });
}
