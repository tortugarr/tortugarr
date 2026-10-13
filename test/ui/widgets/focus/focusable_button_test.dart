import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/focus/focusable_button.dart';
import 'package:moonfin_design/moonfin_design.dart';

void main() {
  setUp(() => ThemeRegistry.setActiveById(ThemeRegistry.moonfinId));

  /// [FocusableButton] uses `useBackgroundFocus`, which normally suppresses
  /// the border overlay drawn by [FocusableWrapper] (bug: game-detail action
  /// pills looked identical whether focused or not except for a subtle
  testWidgets('autoScroll brings an off-screen button into view when focused', (
    tester,
  ) async {
    final topNode = FocusNode();
    final bottomNode = FocusNode();
    addTearDown(topNode.dispose);
    addTearDown(bottomNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                FocusableButton(
                  focusNode: topNode,
                  autoScroll: true,
                  onPressed: () {},
                  child: const SizedBox(height: 40, child: Text('Top')),
                ),
                const SizedBox(height: 2000),
                FocusableButton(
                  focusNode: bottomNode,
                  autoScroll: true,
                  onPressed: () {},
                  child: const SizedBox(height: 40, child: Text('Bottom')),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));

    bottomNode.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));

    topNode.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      scrollable.position.pixels,
      lessThan(50),
      reason: 'autoScroll:true pulls the top button back into view',
    );
  });

  testWidgets(
    'without autoScroll, focusing an off-screen button leaves the scroll offset alone',
    (tester) async {
      final topNode = FocusNode();
      final bottomNode = FocusNode();
      addTearDown(topNode.dispose);
      addTearDown(bottomNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  FocusableButton(
                    focusNode: topNode,
                    onPressed: () {},
                    child: const SizedBox(height: 40, child: Text('Top')),
                  ),
                  const SizedBox(height: 2000),
                  FocusableButton(
                    focusNode: bottomNode,
                    autoScroll: true,
                    onPressed: () {},
                    child: const SizedBox(height: 40, child: Text('Bottom')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));

      bottomNode.requestFocus();
      await tester.pump();
      await tester.pumpAndSettle();
      final scrolledDown = scrollable.position.pixels;
      expect(scrolledDown, greaterThan(0));

      topNode.requestFocus();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        scrollable.position.pixels,
        scrolledDown,
        reason:
            'default autoScroll:false leaves the offset stuck, reproducing the bug',
      );
    },
  );
}
