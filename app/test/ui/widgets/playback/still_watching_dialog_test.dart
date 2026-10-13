import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/theme/app_theme.dart';
import 'package:moonfin/ui/widgets/playback/still_watching_dialog.dart';
import 'package:moonfin_design/moonfin_design.dart';

/// The player exits playback on any answer other than continue, so a pop that
/// misses the dialog reads to the viewer as continue throwing them out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => ThemeRegistry.setActiveById(ThemeRegistry.moonfinId));

  /// Puts the player on its own nested navigator, which is what tells a pop of
  /// the caller's route apart from a pop of the dialog.
  Future<bool?> showFromNestedNavigator(
    WidgetTester tester, {
    required String tapLabel,
  }) async {
    bool? answer;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(ThemeRegistry.active),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (playerContext) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  answer = await StillWatchingDialog.show(playerContext);
                },
                child: const Text('player'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('player'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.stillWatching), findsOneWidget);

    await tester.tap(find.text(tapLabel));
    await tester.pumpAndSettle();

    expect(
      find.text('player'),
      findsOneWidget,
      reason: 'the pop took the player route down',
    );
    expect(find.text(l10n.stillWatching), findsNothing);
    return answer;
  }

  testWidgets('continue answers true and leaves the player up', (tester) async {
    final answer = await showFromNestedNavigator(
      tester,
      tapLabel: l10n.stillWatchingContinue,
    );
    expect(answer, isTrue);
  });

  testWidgets('stop answers false and leaves the player up', (tester) async {
    final answer = await showFromNestedNavigator(
      tester,
      tapLabel: l10n.stillWatchingStop,
    );
    expect(answer, isFalse);
  });
}
