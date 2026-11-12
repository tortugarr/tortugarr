import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/home/harbor_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late UserPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showHarborTourOnce(context),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('the tour shows once, Right steps through it and OK on the last card closes it', (tester) async {
    await pump(tester);
    expect(find.text('Welcome aboard Tortugarr'), findsOneWidget);
    expect(prefs.get(UserPreferences.tgTourShown), isTrue);

    for (final title in ['Badges on the posters', 'Get a title', 'Make Home yours']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    // No SmartTube in tests: Make Home yours is the last card.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Make Home yours'), findsNothing);

    // Not again.
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome aboard Tortugarr'), findsNothing);
  });

  testWidgets('Left goes back a card', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Welcome aboard Tortugarr'), findsOneWidget);
  });
}
