import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/playback/controller_test_panel.dart';
import 'package:moonfin/util/focus/gamepad/controller_diagnostics.dart';

void main() {
  Widget harness(ControllerDiagnosticsSnapshot? snapshot, {int? port}) {
    return MaterialApp(
      home: Scaffold(
        body: ControllerTestPanel(
          snapshot: snapshot,
          deviceName: 'F710',
          port: port,
        ),
      ),
    );
  }

  testWidgets('an analog left stick renders its numbers and verdict', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ControllerDiagnosticsSnapshot(
          connectionId: 'a',
          port: 0,
          channels: [
            StickChannel(
              id: 'left',
              x: -0.42,
              y: 0.13,
              verdict: DiagnosticVerdict.analog,
            ),
          ],
        ),
        port: 0,
      ),
    );

    expect(find.text('-0.42/0.13'), findsOneWidget);
    expect(find.text('ANALOG'), findsOneWidget);
    expect(find.text('[F710 - P1]'), findsOneWidget);
  });

  testWidgets(
    'an unknown verdict renders the placeholder, not a verdict word',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const ControllerDiagnosticsSnapshot(
            connectionId: 'a',
            port: null,
            channels: [
              StickChannel(
                id: 'left',
                x: 0,
                y: 0,
                verdict: DiagnosticVerdict.unknown,
              ),
            ],
          ),
        ),
      );

      expect(find.text('--'), findsWidgets);
      expect(find.text('ANALOG'), findsNothing);
      expect(find.text('DIGITAL'), findsNothing);
      expect(find.text('[F710 - Unassigned]'), findsOneWidget);
    },
  );

  testWidgets('a button with the full naming chain renders every link', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ControllerDiagnosticsSnapshot(
          connectionId: 'a',
          port: 0,
          channels: [
            ButtonChannel(
              rawCode: 96,
              rawName: 'BUTTON_A',
              retroPad: 'A',
              label: 'Fire',
              pressed: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('key 96 (BUTTON_A)'), findsOneWidget);
    // The user-facing phrasing: the button they know plus what the game calls
    // it, with the raw code still on its own line for diagnosing odd pads.
    expect(find.text('Button A (Fire)'), findsOneWidget);
  });

  testWidgets(
    'a button with only rawCode/rawName renders just that link, no "null"',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const ControllerDiagnosticsSnapshot(
            connectionId: 'a',
            port: 0,
            channels: [
              ButtonChannel(rawCode: 96, rawName: 'BUTTON_A', pressed: true),
            ],
          ),
        ),
      );

      expect(find.text('key 96 (BUTTON_A)'), findsOneWidget);
      expect(find.textContaining('RetroPad'), findsNothing);
      expect(find.textContaining('->'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    },
  );

  testWidgets('with two buttons pressed, the last in the channel list wins', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ControllerDiagnosticsSnapshot(
          connectionId: 'a',
          port: 0,
          // Both held, but B is listed after A -- the folder's contract is
          // latest-last, so the panel must show B, not A.
          channels: [
            ButtonChannel(rawName: 'a', pressed: true),
            ButtonChannel(rawName: 'b', pressed: true),
          ],
        ),
      ),
    );

    expect(find.text('(b)'), findsOneWidget);
  });

  testWidgets('no hat channel shows the "reported as buttons" line', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ControllerDiagnosticsSnapshot(
          connectionId: 'a',
          port: 0,
          channels: [],
        ),
      ),
    );

    expect(find.text('reported as buttons'), findsOneWidget);
  });

  testWidgets('a hat channel present shows the d-pad row instead', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ControllerDiagnosticsSnapshot(
          connectionId: 'a',
          port: 0,
          channels: [
            StickChannel(
              id: 'hat',
              x: -1,
              y: -1,
              verdict: DiagnosticVerdict.digital,
            ),
          ],
        ),
      ),
    );

    expect(find.text('reported as buttons'), findsNothing);
    expect(find.text('< ^ - -'), findsOneWidget);
  });

  testWidgets('the exit hint becomes a countdown ring while B is held', (
    tester,
  ) async {
    // Not held: the quiet hint, no ring.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ControllerTestPanel(
            snapshot: null,
            deviceName: 'F710',
            port: 0,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Hold B to go back'), findsOneWidget);

    // Held: the ring appears and carries the progress, so the wait is visible
    // rather than guesswork.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ControllerTestPanel(
            snapshot: null,
            deviceName: 'F710',
            port: 0,
            exitHoldProgress: 0.4,
          ),
        ),
      ),
    );
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.4);
    expect(find.textContaining('Keep holding B'), findsOneWidget);
  });
}
