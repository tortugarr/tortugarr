import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tvos/flutter_tvos.dart'
    show TvRemoteTouchEvent, TvRemoteTouchPhase;
import 'package:moonfin/util/focus/siri_remote_glide.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final glide = SiriRemoteGlide.instance;
  final pressed = <LogicalKeyboardKey>[];
  bool capture(KeyEvent event) {
    if (event is KeyDownEvent) pressed.add(event.logicalKey);
    return true;
  }

  var now = Duration.zero;
  void advance(Duration by) {
    now += by;
    SiriRemoteGlide.debugNowOverride = now;
  }

  void touch(TvRemoteTouchPhase phase, double x, double y) {
    glide.debugHandleTouch(TvRemoteTouchEvent(phase: phase, x: x, y: y));
  }

  setUp(() {
    pressed.clear();
    now = Duration.zero;
    SiriRemoteGlide.debugNowOverride = now;
    HardwareKeyboard.instance.addHandler(capture);
  });

  tearDown(() {
    glide.debugReset();
    HardwareKeyboard.instance.removeHandler(capture);
    SiriRemoteGlide.debugNowOverride = null;
  });

  testWidgets('slow drag steps focus per distance and stops on release', (
    tester,
  ) async {
    touch(TvRemoteTouchPhase.started, -0.8, 0);
    var x = -0.8;
    // 16 slow moves of 0.1 each 100ms is 1.0 unit per second, well under the
    // flick threshold, crossing 1.6 units of travel: one step at 0.28 then
    // one every 0.36, so four steps in total.
    for (var i = 0; i < 16; i++) {
      advance(const Duration(milliseconds: 100));
      x += 0.1;
      touch(TvRemoteTouchPhase.move, x, 0);
    }
    expect(pressed, List.filled(4, LogicalKeyboardKey.arrowRight));

    touch(TvRemoteTouchPhase.ended, x, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(pressed.length, 4, reason: 'a slow drag must not glide');
  });

  testWidgets('vertical drag steps up', (tester) async {
    touch(TvRemoteTouchPhase.started, 0, -0.2);
    advance(const Duration(milliseconds: 100));
    touch(TvRemoteTouchPhase.move, 0, 0.2);
    expect(pressed, [LogicalKeyboardKey.arrowUp]);
    touch(TvRemoteTouchPhase.ended, 0, 0.2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('fast flick keeps gliding after release', (tester) async {
    touch(TvRemoteTouchPhase.started, -0.6, 0);
    var x = -0.6;
    // 0.15 every 16ms is over nine units per second.
    for (var i = 0; i < 5; i++) {
      advance(const Duration(milliseconds: 16));
      x += 0.15;
      touch(TvRemoteTouchPhase.move, x, 0);
    }
    final duringDrag = pressed.length;
    touch(TvRemoteTouchPhase.ended, x, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(pressed.length, greaterThan(duringDrag),
        reason: 'a flick must add glide steps after the finger lifts');
    expect(pressed.toSet(), {LogicalKeyboardKey.arrowRight});
  });

  testWidgets('touching the pad brakes an active glide', (tester) async {
    touch(TvRemoteTouchPhase.started, -0.6, 0);
    var x = -0.6;
    for (var i = 0; i < 5; i++) {
      advance(const Duration(milliseconds: 16));
      x += 0.15;
      touch(TvRemoteTouchPhase.move, x, 0);
    }
    touch(TvRemoteTouchPhase.ended, x, 0);
    await tester.pump(const Duration(milliseconds: 80));
    final atBrake = pressed.length;

    touch(TvRemoteTouchPhase.started, 0, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(pressed.length, atBrake,
        reason: 'a new touch must cancel pending glide steps');
    touch(TvRemoteTouchPhase.ended, 0, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a click cancels a glide', (tester) async {
    touch(TvRemoteTouchPhase.started, -0.6, 0);
    var x = -0.6;
    for (var i = 0; i < 5; i++) {
      advance(const Duration(milliseconds: 16));
      x += 0.15;
      touch(TvRemoteTouchPhase.move, x, 0);
    }
    touch(TvRemoteTouchPhase.ended, x, 0);
    await tester.pump(const Duration(milliseconds: 80));
    final atClick = pressed.length;

    touch(TvRemoteTouchPhase.clickStart, 0, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(pressed.length, atClick);
  });

  testWidgets('direction reversal mid drag responds immediately', (
    tester,
  ) async {
    touch(TvRemoteTouchPhase.started, 0.0, 0);
    advance(const Duration(milliseconds: 100));
    touch(TvRemoteTouchPhase.move, 0.3, 0);
    expect(pressed, [LogicalKeyboardKey.arrowRight]);

    // Coming back shouldn't have to unwind the forward accumulator.
    advance(const Duration(milliseconds: 100));
    touch(TvRemoteTouchPhase.move, 0.0, 0);
    advance(const Duration(milliseconds: 100));
    touch(TvRemoteTouchPhase.move, -0.1, 0);
    expect(pressed.last, LogicalKeyboardKey.arrowLeft);
    touch(TvRemoteTouchPhase.ended, -0.1, 0);
    await tester.pump(const Duration(seconds: 3));
  });
}
