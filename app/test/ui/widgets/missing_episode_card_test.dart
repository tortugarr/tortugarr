import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';
import 'package:moonfin/data/services/download/sonarr_client.dart';
import 'package:moonfin/ui/widgets/missing_episodes/missing_episode_card.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

MissingEpisode _missing(MissingEpisodeState state, {DateTime? aired}) =>
    MissingEpisode(
      SonarrEpisode(
        id: 4541,
        seasonNumber: 3,
        episodeNumber: 3,
        monitored: false,
        title: 'Rhaenyra Triumphant',
        airDateUtc: aired,
      ),
      state,
    );

Widget _host(Widget child, {double width = 1280}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  for (final width in [1280.0, 360.0]) {
    testWidgets('a missing episode is marked and selectable at ${width}px', (
      tester,
    ) async {
      var selected = 0;
      await tester.pumpWidget(_host(
        MissingEpisodeCard(
          missing: _missing(
            MissingEpisodeState.missing,
            aired: DateTime.utc(2026, 7, 6),
          ),
          onSelect: () => selected++,
        ),
        width: width,
      ));
      expect(find.text('Mangler'), findsOneWidget);
      expect(find.text('E03'), findsOneWidget);
      expect(find.text('3. Rhaenyra Triumphant'), findsOneWidget);
      await tester.tap(find.text('E03'));
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unaired episode says when it comes', (tester) async {
    await tester.pumpWidget(_host(MissingEpisodeCard(
      missing: _missing(
        MissingEpisodeState.unaired,
        aired: DateTime(DateTime.now().year, 10, 12, 12),
      ),
      onSelect: () {},
    )));
    expect(find.text('Kommer 12. okt.'), findsOneWidget);
  });

  testWidgets('downloading and importing have their own badges', (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      MissingEpisodeCard(
        missing: _missing(MissingEpisodeState.downloading),
        onSelect: () {},
      ),
      MissingEpisodeCard(
        missing: _missing(MissingEpisodeState.importing),
        onSelect: () {},
      ),
    ])));
    expect(find.text('Lastes ned'), findsOneWidget);
    expect(find.text('Klar snart'), findsOneWidget);
  });

  testWidgets('season pack button names the count', (tester) async {
    await tester.pumpWidget(_host(SeasonPackButton(
      missingCount: 6,
      onSelect: () {},
    )));
    expect(find.text('Hele sesongen'), findsOneWidget);
    expect(find.textContaining('6 episoder mangler'), findsOneWidget);
  });
}
