import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/home/harbor_cards.dart';

void main() {
  testWidgets('a ranked card shows its number and puts the poster after the gutter', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 160,
          height: 180,
          child: HarborRankedCard(rank: 7, gutter: 60, imageHeight: 150, child: SizedBox(key: Key('poster'), width: 100, height: 150)),
        ),
      ),
    ));
    expect(find.text('7'), findsOneWidget);
    final card = tester.getTopLeft(find.byType(HarborRankedCard));
    expect(tester.getTopLeft(find.byKey(const Key('poster'))).dx - card.dx, 60);
  });

  testWidgets('a collection card keeps its poster in front of two plates', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: HarborStackedCard(width: 100, imageHeight: 150, child: SizedBox(key: Key('poster'), width: 100, height: 150))),
    ));
    final stack = tester.widget<Stack>(find.descendant(of: find.byType(HarborStackedCard), matching: find.byType(Stack)).first);
    expect(stack.children.length, 3);
    expect((stack.children.last as SizedBox).key, const Key('poster'));
  });
}
