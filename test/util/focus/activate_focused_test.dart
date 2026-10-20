import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/navigation/single_push.dart';
import 'package:moonfin/util/focus/activate_focused.dart';

/// Mirrors the app root: a Focus above the routes that turns enter/select into
/// ActivateIntent, with MaterialApp's default Shortcuts still in place.
Widget _app(FocusNode card, VoidCallback onTap) => MaterialApp(
  builder: (context, child) => Focus(
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.select &&
          event.logicalKey != LogicalKeyboardKey.enter) {
        return KeyEventResult.ignored;
      }
      final target = FocusManager.instance.primaryFocus?.context ?? context;
      return activateFocused(target);
    },
    child: child!,
  ),
  home: Material(
    child: Center(
      child: InkWell(focusNode: card, onTap: onTap, child: const Text('card')),
    ),
  ),
);

void main() {
  testWidgets('one OK press on an InkWell taps it exactly once', (tester) async {
    var taps = 0;
    final card = FocusNode(debugLabel: 'card');
    await tester.pumpWidget(_app(card, () => taps++));
    await tester.pumpAndSettle();
    card.requestFocus();
    await tester.pumpAndSettle();
    expect(card.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('nothing focusable to activate leaves the key unhandled', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(activateFocused(ctx), KeyEventResult.ignored);
  });

  test('a location already on top or in flight is a duplicate', () {
    SinglePush.markInFlight(null);
    expect(SinglePush.isDuplicate('/seerr/media/42', currentPath: '/seerr/requests'), isFalse);
    expect(SinglePush.isDuplicate('/seerr/media/42?mediaType=movie', currentPath: '/seerr/media/42'), isTrue);
    SinglePush.markInFlight('/seerr/media/42');
    expect(SinglePush.isDuplicate('/seerr/media/42', currentPath: '/seerr/requests'), isTrue);
    expect(SinglePush.isDuplicate('/seerr/media/7', currentPath: '/seerr/requests'), isFalse);
    SinglePush.markInFlight(null);
  });
}
