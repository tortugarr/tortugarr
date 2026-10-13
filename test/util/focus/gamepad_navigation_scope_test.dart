import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/focus/gamepad/gamepad_navigation_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

NormalizedGamepadEvent _button(GamepadButton button, {required bool pressed}) =>
    NormalizedGamepadEvent(
      gamepadId: 'pad-1',
      timestamp: 0,
      value: pressed ? 1 : 0,
      button: button,
      rawEvent: GamepadEvent(
        gamepadId: 'pad-1',
        timestamp: 0,
        type: KeyType.button,
        key: button.name,
        value: pressed ? 1 : 0,
      ),
    );

/// The test binding reports Android, where the pad is gated natively rather
/// than read from the plugin stream, so each test picks its platform. The
/// override has to be back to null before the body returns or the binding
/// fails the test for leaking it.
Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPreferences prefs;
  late StreamController<NormalizedGamepadEvent> pad;
  final seen = <KeyEvent>[];
  bool capture(KeyEvent event) {
    seen.add(event);
    return false;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
    pad = StreamController<NormalizedGamepadEvent>.broadcast();
    seen.clear();
    HardwareKeyboard.instance.addHandler(capture);
  });

  tearDown(() async {
    HardwareKeyboard.instance.removeHandler(capture);
    await pad.close();
    await GetIt.instance.reset();
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: GamepadNavigationScope(events: pad.stream, child: const SizedBox()),
    ),
  );

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> send(WidgetTester tester, NormalizedGamepadEvent event) async {
    pad.add(event);
    await tester.pump();
  }

  Iterable<LogicalKeyboardKey> downs() =>
      seen.whereType<KeyDownEvent>().map((e) => e.logicalKey);
  Iterable<LogicalKeyboardKey> ups() =>
      seen.whereType<KeyUpEvent>().map((e) => e.logicalKey);

  test('the switch is offered wherever a pad has a way in', () async {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      await on(platform, () async {
        expect(
          GamepadNavigationScope.isConfigurable,
          isTrue,
          reason: '$platform',
        );
      });
    }
    await on(TargetPlatform.fuchsia, () async {
      expect(GamepadNavigationScope.isConfigurable, isFalse);
    });
  });

  testWidgets('a pad does nothing until the preference is turned on', (
    tester,
  ) async {
    await on(TargetPlatform.linux, () async {
      await mount(tester);
      expect(prefs.get(UserPreferences.gamepadNavigationEnabled), isFalse);

      await send(tester, _button(GamepadButton.dpadDown, pressed: true));
      await send(tester, _button(GamepadButton.dpadDown, pressed: false));
      await send(tester, _button(GamepadButton.a, pressed: true));

      expect(seen, isEmpty, reason: 'off is the default and has to mean off');
      await unmount(tester);
    });
  });

  testWidgets('turning the preference on starts driving the UI', (
    tester,
  ) async {
    await on(TargetPlatform.linux, () async {
      await mount(tester);
      await prefs.set(UserPreferences.gamepadNavigationEnabled, true);
      await tester.pump();

      await send(tester, _button(GamepadButton.dpadDown, pressed: true));
      expect(downs(), [LogicalKeyboardKey.arrowDown]);

      await send(tester, _button(GamepadButton.dpadDown, pressed: false));
      expect(ups(), [LogicalKeyboardKey.arrowDown]);

      await send(tester, _button(GamepadButton.a, pressed: true));
      expect(downs().last, LogicalKeyboardKey.select);
      await send(tester, _button(GamepadButton.a, pressed: false));
      await unmount(tester);
    });
  });

  testWidgets('turning it off mid hold lets go and ignores what follows', (
    tester,
  ) async {
    await on(TargetPlatform.linux, () async {
      await mount(tester);
      await prefs.set(UserPreferences.gamepadNavigationEnabled, true);
      await tester.pump();
      await send(tester, _button(GamepadButton.dpadRight, pressed: true));
      expect(downs(), [LogicalKeyboardKey.arrowRight]);
      expect(ups(), isEmpty);

      await prefs.set(UserPreferences.gamepadNavigationEnabled, false);
      await tester.pump();
      expect(
        ups(),
        [LogicalKeyboardKey.arrowRight],
        reason: 'a held direction must not stay down once the pad is cut off',
      );

      seen.clear();
      await send(tester, _button(GamepadButton.dpadRight, pressed: false));
      await send(tester, _button(GamepadButton.dpadLeft, pressed: true));
      await send(tester, _button(GamepadButton.dpadLeft, pressed: false));
      expect(seen, isEmpty);
      await unmount(tester);
    });
  });

  testWidgets('a preference already on when the scope mounts is honoured', (
    tester,
  ) async {
    await on(TargetPlatform.linux, () async {
      await prefs.set(UserPreferences.gamepadNavigationEnabled, true);
      await mount(tester);

      await send(tester, _button(GamepadButton.b, pressed: true));
      expect(downs(), [LogicalKeyboardKey.escape]);
      await send(tester, _button(GamepadButton.b, pressed: false));
      await unmount(tester);
    });
  });

  group('on Android', () {
    const channel = MethodChannel('org.moonfin.androidtv/gamepad');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Iterable<String> pushes() => calls
        .where((c) => c.method == 'setNavigationEnabled')
        .map((c) => '${(c.arguments as Map)['enabled']}');

    testWidgets(
      'the Activity hears the stored value on mount and each change',
      (tester) async {
        await on(TargetPlatform.android, () async {
          await mount(tester);
          await tester.pump();
          expect(pushes(), ['false']);

          await prefs.set(UserPreferences.gamepadNavigationEnabled, true);
          await tester.pump();
          expect(pushes(), ['false', 'true']);

          await prefs.set(UserPreferences.gamepadNavigationEnabled, false);
          await tester.pump();
          expect(pushes(), ['false', 'true', 'false']);
          await unmount(tester);
        });
      },
    );

    testWidgets('the plugin stream is left alone even when on', (tester) async {
      await on(TargetPlatform.android, () async {
        await prefs.set(UserPreferences.gamepadNavigationEnabled, true);
        await mount(tester);
        await send(tester, _button(GamepadButton.dpadDown, pressed: true));
        expect(
          seen,
          isEmpty,
          reason: 'pad buttons already reach Flutter as real keys on Android',
        );
        await unmount(tester);
      });
    });
  });
}
