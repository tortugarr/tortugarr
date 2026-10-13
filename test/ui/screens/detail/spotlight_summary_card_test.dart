// The Spotlight summary card is the d-pad and touch entry into a card's
// modal: Select opens it, Up hands focus back to the action row, and the
// always-on badge names the card before its imagery loads.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _title = 'Similar and Seerr Recommendations';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
  });

  tearDown(() => GetIt.instance.reset());

  Future<({FocusNode node, List<String> log})> pump(WidgetTester tester) async {
    final node = FocusNode(debugLabel: 'card');
    addTearDown(node.dispose);
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 160,
              child: SpotlightSummaryCard(
                title: _title,
                subtitle: '12 titles',
                imageUrl: null,
                icon: Icons.auto_awesome_outlined,
                focusNode: node,
                onOpen: () => log.add('open'),
                onNavigateUp: () => log.add('up'),
              ),
            ),
          ),
        ),
      ),
    );
    return (node: node, log: log);
  }

  testWidgets('renders the title, subtitle, badge icon and chevron', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('12 titles'), findsOneWidget);
    // The badge always carries the icon; the no-image fallback repeats it.
    expect(find.byIcon(Icons.auto_awesome_outlined), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('the title may wrap onto two lines', (tester) async {
    await pump(tester);
    expect(tester.widget<Text>(find.text(_title)).maxLines, 2);
  });

  testWidgets('select opens the card', (tester) async {
    final (:node, :log) = await pump(tester);
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(log, ['open']);
  });

  testWidgets('arrow up hands focus back to the action row', (tester) async {
    final (:node, :log) = await pump(tester);
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(log, ['up']);
  });

  testWidgets('a tap opens the card', (tester) async {
    final (:log, node: _) = await pump(tester);

    await tester.tap(find.byType(SpotlightSummaryCard));
    await tester.pump();

    expect(log, ['open']);
  });
}
