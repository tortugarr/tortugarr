import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/playback/media_kit_player_backend.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/widgets/playback/track_picker.dart';
import 'package:playback_core/playback_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend extends Fake implements MediaKitPlayerBackend {
  final audioDelays = <double>[];

  @override
  Future<void> setAudioDelay(double seconds) async => audioDelays.add(seconds);
}

class _Manager extends PlaybackManager {
  _Manager(this._backend);

  final PlayerBackend _backend;

  @override
  PlayerBackend? get backend => _backend;
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
    TrackPicker.resetDelays();
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> openPicker(
    WidgetTester tester,
    PlaybackManager manager, {
    bool subtitles = false,
    ValueChanged<bool>? onDialogOpenChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => TrackPicker.show(
              context,
              manager: manager,
              audio: !subtitles,
              clientFor: (_) => throw UnimplementedError(),
              onDialogOpenChanged: onDialogOpenChanged,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('reports its dialog opening and closing', (tester) async {
    final events = <bool>[];
    await openPicker(tester, PlaybackManager(), onDialogOpenChanged: events.add);
    expect(find.byType(Dialog), findsOneWidget);
    expect(events, [true]);

    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(events, [true, false]);
  });

  // Issue #1141: the delay is set from a bar that leaves the picture in view
  // rather than from under the track list.
  testWidgets('the audio delay opens in a bar that leaves the picture undimmed', (
    tester,
  ) async {
    final backend = _Backend();
    final events = <bool>[];
    await openPicker(tester, _Manager(backend), onDialogOpenChanged: events.add);
    expect(find.text(l10n.none), findsOneWidget);
    expect(find.byType(AnimatedModalBarrier), findsOneWidget);

    await tester.tap(find.text(l10n.audioDelay));
    await tester.pumpAndSettle();
    expect(find.text(l10n.audioTrack), findsNothing);
    expect(find.byType(AnimatedModalBarrier), findsNothing);

    await tester.tap(find.byTooltip(l10n.delayPlusMs(100)));
    await tester.pump();
    expect(find.text('+100 ms'), findsOneWidget);
    expect(backend.audioDelays, [0.1]);
    expect(TrackPicker.audioDelay, 0.1);

    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await tester.pumpAndSettle();
    expect(events, [true, false, true, false]);
  });

  // One subtitle menu: the track list with size, height and colour under it,
  // written to the subtitle settings the player draws with.
  testWidgets('the subtitle menu sets the subtitle size', (tester) async {
    await openPicker(tester, PlaybackManager(), subtitles: true);
    expect(find.text(l10n.subtitleTrack), findsOneWidget);
    expect(find.text(l10n.subtitleSize), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.increaseValue(l10n.subtitleSize)));
    await tester.pump();
    final prefs = GetIt.instance<UserPreferences>();
    expect(prefs.get(UserPreferences.subtitlesTextSize), 22.0);
  });

  testWidgets('the delay bar starts with Reset focused for a remote', (
    tester,
  ) async {
    final backend = _Backend();
    await openPicker(tester, _Manager(backend));
    await tester.tap(find.text(l10n.audioDelay));
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text(l10n.reset))).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(backend.audioDelays, [0.1]);
  });
}
