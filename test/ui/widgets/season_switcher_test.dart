import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/missing_episodes/season_switcher.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

String _label(int n) => 'Sesong $n';

/// Stargate SG-1 as the user has it: seasons 1 and 2 in the library, 3-5 missing.
List<SeasonSwitcherEntry> _sg1() => SeasonSwitcherEntry.combine(
      library: [
        (id: 's2', serverId: 'srv', number: 2, name: 'Sesong 2'),
        (id: 's1', serverId: 'srv', number: 1, name: 'Sesong 1'),
      ],
      missingSeasons: const [5, 3, 4],
      missingLabel: _label,
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

  test('combine lists library and missing seasons in order, without duplicates', () {
    final entries = SeasonSwitcherEntry.combine(
      library: [
        (id: 's2', serverId: null, number: 2, name: 'Sesong 2'),
        (id: 's1', serverId: null, number: 1, name: 'Sesong 1'),
        (id: 'x', serverId: null, number: null, name: 'Ekstra'),
      ],
      missingSeasons: const [3, 2],
      missingLabel: _label,
    );
    expect(entries.map((e) => e.label), ['Sesong 1', 'Sesong 2', 'Sesong 3', 'Ekstra']);
    expect(entries.map((e) => e.missing), [false, false, true, false]);
  });

  for (final width in [1280.0, 360.0]) {
    testWidgets('lists all seasons, highlights the current one and selects another at ${width}px', (
      tester,
    ) async {
      final selected = <SeasonSwitcherEntry>[];
      await tester.pumpWidget(_host(
        SeasonSwitcher(
          entries: _sg1(),
          currentItemId: 's1',
          onSelect: selected.add,
        ),
        width: width,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sesong 1'), findsOneWidget);
      expect(find.text('Sesong 2'), findsOneWidget);
      // Missing seasons may be scrolled off on a phone; scroll through them.
      for (final n in [3, 4, 5]) {
        await tester.scrollUntilVisible(find.text('Sesong $n'), 100,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Sesong $n'), findsOneWidget);
        // Each missing season carries its own "Mangler" badge.
        expect(
          find.descendant(
            of: find.ancestor(of: find.text('Sesong $n'), matching: find.byType(Row)),
            matching: find.text('Mangler'),
          ),
          findsOneWidget,
        );
      }

      // The current season is drawn bold on white.
      await tester.scrollUntilVisible(find.text('Sesong 1'), -100,
          scrollable: find.byType(Scrollable).first);
      final current = tester.widget<Text>(find.text('Sesong 1'));
      expect(current.style?.fontWeight, FontWeight.bold);
      expect(current.style?.color, Colors.black);

      // Tapping the current season does nothing.
      await tester.tap(find.text('Sesong 1'));
      await tester.pump();
      expect(selected, isEmpty);

      await tester.ensureVisible(find.text('Sesong 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sesong 2'));
      await tester.pump();
      expect(selected.single.itemId, 's2');

      await tester.scrollUntilVisible(find.text('Sesong 4'), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Sesong 4'));
      await tester.pump();
      expect(selected.last.missing, isTrue);
      expect(selected.last.number, 4);
    });
  }
}
