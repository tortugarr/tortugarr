import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/retro_artwork/retro_artwork_activity_gate.dart';
import 'package:moonfin/ui/screens/playback/game_emulator_screen.dart';
import 'package:server_core/server_core.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockMediaServerClient extends Mock implements MediaServerClient {}

/// Real wakelock plugins talk to a native platform channel that has no
/// handler in the widget-test harness. `_exit()` awaits `WakelockPlus.disable()`
/// outside its own try/catch, so an unmocked plugin call here would throw and
/// prevent the pop this test is checking for -- unrelated to the bug under
/// test. Swap in a no-op platform implementation instead of a channel mock.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMediaServerClient client;

  setUp(() async {
    WakelockPlusPlatformInterface.instance = _FakeWakelockPlatform();
    // _exit() awaits _restoreSystemUi()'s SystemChrome calls before popping;
    // without a handler these unmocked platform-channel calls would throw
    // and, like the wakelock stub above, block the pop this test checks for.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    await GetIt.instance.reset();
    client = _MockMediaServerClient();
    // No games API: _prepare() takes its "server does not support games"
    // error branch immediately, so the screen never builds the InAppWebView
    // (that only happens once _playerUrl is set). The menu button and the
    // pause overlay -- including Exit -- are always present regardless, which
    // is all this regression test needs to reach _exit().
    when(() => client.gamesApi).thenReturn(null);
    // Both game screens mix in GameAudioOwner, which resolves this.
    GetIt.instance.registerSingleton<PlaybackArbiter>(PlaybackArbiter());
    GetIt.instance.registerSingleton<MediaServerClient>(client);
    GetIt.instance.registerSingleton<RetroArtworkActivityGate>(
      RetroArtworkActivityGate(),
    );
  });

  tearDown(() => GetIt.instance.reset());

  test(
    'exit persistence skips a state that Save & exit already stored',
    () async {
      var stateSaves = 0;
      var settingsSaves = 0;

      await persistGameEmulatorExit(
        saveState: false,
        persistState: () async => stateSaves++,
        persistSettings: () async => settingsSaves++,
      );

      expect(stateSaves, 0);
      expect(settingsSaves, 1);
    },
  );
}
