import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/focus/dpad_keys.dart';
import 'package:moonfin/util/focus/gamepad/gamepad_key_synthesizer.dart';

/// Checks that a synthesized gamepad event behaves like the equivalent
/// keyboard event, so existing focus widgets and global key handlers work
/// without any gamepad-specific code.
void main() {
  late GamepadKeySynthesizer synthesizer;

  setUp(() => synthesizer = GamepadKeySynthesizer());
  tearDown(() => synthesizer.releaseAll());

  testWidgets('pad directions move focus through Focus.onKeyEvent', (
    tester,
  ) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    // Mirrors how rows and grids actually consume keys, with a raw key event
    // tested against the shared predicates rather than an Intent.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focus(
              focusNode: first,
              onKeyEvent: (node, event) {
                if (event.isActionable && event.logicalKey.isDownKey) {
                  second.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: const SizedBox(width: 10, height: 10),
            ),
            Focus(
              focusNode: second,
              child: const SizedBox(width: 10, height: 10),
            ),
          ],
        ),
      ),
    );

    first.requestFocus();
    await tester.pump();
    expect(first.hasPrimaryFocus, isTrue);

    synthesizer.press(GamepadNavKey.down);
    await tester.pump();

    expect(
      second.hasPrimaryFocus,
      isTrue,
      reason: 'pad down should move focus',
    );
  });

  testWidgets('pad A reaches Actions as an activation', (tester) async {
    var activated = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: node,
          onKeyEvent: (_, event) {
            if (isActivateKey(event)) {
              activated++;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();

    synthesizer.press(GamepadNavKey.select);
    await tester.pump();

    expect(activated, 1);
  });

  testWidgets('a global HardwareKeyboard handler wins over the focus tree', (
    tester,
  ) async {
    // The back chain lives in a global handler that runs ahead of focused
    // widgets.
    // When it claims the event the focus tree shouldn't also act, or one press
    // of pad B would close a sheet and pop the route.
    var globalSawBack = 0;
    var focusSawBack = 0;

    bool globalHandler(KeyEvent event) {
      if (event is KeyDownEvent && event.logicalKey.isBackKey) {
        globalSawBack++;
        return true;
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(globalHandler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(globalHandler));

    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: node,
          onKeyEvent: (_, event) {
            if (event.isActionable && event.logicalKey.isBackKey) {
              focusSawBack++;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    node.requestFocus();
    await tester.pump();

    synthesizer.press(GamepadNavKey.back);
    await tester.pump();

    expect(globalSawBack, 1);
    expect(
      focusSawBack,
      0,
      reason: 'a consumed event shouldn\'t be handled twice',
    );
  });

  testWidgets('pad input works with nothing focused', (tester) async {
    // On a cold start nothing has focus yet, and a global handler is what
    // restores it on the first press. Resolving against the focused widget
    // would drop the input entirely.
    var seen = 0;
    bool handler(KeyEvent event) {
      if (event is KeyDownEvent) seen++;
      return false;
    }

    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));

    // Nothing focusable in the tree, so the focus tree has nowhere to
    // deliver to and only the global handler can act.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    synthesizer.press(GamepadNavKey.down);
    await tester.pump();

    expect(seen, 1);
  });
}
