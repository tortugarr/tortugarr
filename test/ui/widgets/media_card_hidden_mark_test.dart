import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_language_filter.dart';
import 'package:moonfin/ui/widgets/media_card.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/util/app_l10n.dart';

Widget _card({SeerrLanguageMark? mark}) => MaterialApp(
  // The Seerr type badge on the card reads the app's strings.
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('nb'),
  home: Scaffold(
    body: Center(
      child: MediaCard(
        title: 'Doraemon',
        width: 130,
        aspectRatio: 2 / 3,
        seerrMediaType: 'tv',
        seerrLanguageMark: mark,
      ),
    ),
  ),
);

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  testWidgets('a title the language filter would hide carries the red mark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(mark: const SeerrLanguageMark('JA', SeerrLanguageMarkKind.hidden)),
    );
    expect(find.text('SKJULES · JA'), findsOneWidget);
  });

  testWidgets('a kept title shows just its code', (tester) async {
    await tester.pumpWidget(
      _card(mark: const SeerrLanguageMark('SE', SeerrLanguageMarkKind.kept)),
    );
    expect(find.text('SE'), findsOneWidget);
    expect(find.textContaining('SKJULES'), findsNothing);
  });

  testWidgets('a foreign library title shows its code, not SKJULES', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        mark: const SeerrLanguageMark(
          'KO',
          SeerrLanguageMarkKind.libraryForeign,
        ),
      ),
    );
    expect(find.text('KO'), findsOneWidget);
    expect(find.textContaining('SKJULES'), findsNothing);
  });

  testWidgets('without preview there is no badge', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.textContaining('SKJULES'), findsNothing);
    expect(find.text('JA'), findsNothing);
  });
}
