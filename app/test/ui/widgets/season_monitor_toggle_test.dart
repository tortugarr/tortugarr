import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/missing_episodes/season_monitor_toggle.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  testWidgets('off by default; on asks first, and "Nei" turns it on without a search', (
    tester,
  ) async {
    final calls = <(bool, bool)>[];
    await tester.pumpWidget(_host(SeasonMonitorToggle(
      season: 13,
      monitored: false,
      onChanged: (on, searchNow) async {
        calls.add((on, searchNow));
        return null;
      },
    )));
    expect(find.text('Ikke overvåket'), findsOneWidget);

    await tester.tap(find.text('Ikke overvåket'));
    await tester.pumpAndSettle();
    expect(find.text('Skal Sonarr hente manglende episoder i sesong 13 nå?\n\n'
        'Nei: bare nye episoder blir hentet når de kommer.'), findsOneWidget);

    await tester.tap(find.text('Nei'));
    await tester.pumpAndSettle();
    expect(calls, [(true, false)]);
    expect(find.text('Overvåkes'), findsOneWidget);
  });

  testWidgets('cancelling the question changes nothing', (tester) async {
    final calls = <(bool, bool)>[];
    await tester.pumpWidget(_host(SeasonMonitorToggle(
      season: 2,
      monitored: false,
      onChanged: (on, searchNow) async {
        calls.add((on, searchNow));
        return null;
      },
    )));
    await tester.tap(find.text('Ikke overvåket'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // outside the dialog
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Ikke overvåket'), findsOneWidget);
  });

  testWidgets('a failed change flips back and shows why', (tester) async {
    await tester.pumpWidget(_host(SeasonMonitorToggle(
      season: 1,
      monitored: true,
      compact: true,
      onChanged: (on, searchNow) async => 'Sonarr godtok ikke endringen',
    )));
    expect(find.text('Overvåkes'), findsOneWidget);
    await tester.tap(find.text('Overvåkes'));
    await tester.pumpAndSettle();
    expect(find.text('Overvåkes'), findsOneWidget);
    expect(find.text('Sonarr godtok ikke endringen'), findsOneWidget);
  });
}
