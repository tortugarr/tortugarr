import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/native_game_player_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const controlChannel = MethodChannel('moonfin/native_game_control');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(controlChannel, null);
  });

  test(
    'restart() propagates a restart_unavailable PlatformException to the caller',
    () async {
      // Mirrors the native side genuinely rejecting a restart for cores that
      // don't support it. Regression test for the bug where _invoke()'s
      // blanket `catch (_) {}` swallowed this before it could reach
      // native_game_player_screen's _restart() handler, making the "Restart
      // is not available for this core" message unreachable.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controlChannel, (call) async {
            if (call.method == 'restart') {
              throw PlatformException(code: 'restart_unavailable');
            }
            return null;
          });

      final player = NativeGamePlayerChannel();

      await expectLater(
        player.restart(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'restart_unavailable',
          ),
        ),
      );
    },
  );

  test(
    'pause/resume/stop swallow platform errors',
    () async {
      // Fire-and-forget with no error handler downstream, so _invoke() keeps
      // swallowing for them.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controlChannel, (call) async {
            throw PlatformException(code: 'boom');
          });

      final player = NativeGamePlayerChannel();

      await expectLater(player.pause(), completes);
      await expectLater(player.resume(), completes);
      await expectLater(player.stop(), completes);
    },
  );

  test(
    'transports every advertised controller type and applies Auto as joypad',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controlChannel, (call) async {
            calls.add(call);
            if (call.method == 'getControllerTypes') {
              return [
                {'port': 0, 'id': 5, 'label': 'Classic'},
                {'port': 0, 'id': 2, 'label': 'Mouse'},
              ];
            }
            return null;
          });

      final player = NativeGamePlayerChannel();
      final types = await player.getControllerTypes();
      await player.setControllerType(0, 1);

      expect(types, hasLength(2));
      expect(types[0].id, 5);
      expect(types[1].label, 'Mouse');
      expect(
        calls.last,
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'setControllerType')
            .having((call) => call.arguments, 'arguments', {
              'port': 0,
              'deviceType': 1,
            }),
      );
    },
  );

  test(
    'start() propagates so a failed launch is not a frozen screen',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(controlChannel, (call) async {
        throw PlatformException(code: 'start_failed');
      });

      final player = NativeGamePlayerChannel();

      await expectLater(
        player.start(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'start_failed',
          ),
        ),
      );
    },
  );
}
