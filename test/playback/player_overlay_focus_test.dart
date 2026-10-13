import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The player reads every remote key on one node wrapping the whole screen, and
/// the OSD, the skip button and the next up card all sit below it. When one of
/// them goes away Flutter hands focus to whatever held it before, which is the
/// player's node only if it ever did, so focus can be left on the route's own
/// scope with no key reaching the player at all.
class _Player extends StatefulWidget {
  const _Player({required this.restoreFocus});

  final bool restoreFocus;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  final overlay = FocusNode(debugLabel: 'overlay');
  final osd = FocusNode(debugLabel: 'osd');
  final skip = FocusNode(debugLabel: 'skip');

  bool osdVisible = true;
  bool skipVisible = false;
  int keysRead = 0;

  @override
  void initState() {
    super.initState();
    if (widget.restoreFocus) {
      FocusManager.instance.addListener(_restoreOverlayFocus);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_restoreOverlayFocus);
    overlay.dispose();
    osd.dispose();
    skip.dispose();
    super.dispose();
  }

  void _restoreOverlayFocus() {
    if (!mounted || overlay.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || overlay.hasFocus) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      overlay.requestFocus();
    });
  }

  void showSkipButton() => setState(() => skipVisible = true);

  void hideOsd() => setState(() => osdVisible = false);

  void hideSkipButton() => setState(() => skipVisible = false);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: overlay,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) keysRead++;
        return KeyEventResult.handled;
      },
      child: Column(
        children: [
          if (osdVisible) Focus(focusNode: osd, child: const Text('osd')),
          if (skipVisible) Focus(focusNode: skip, child: const Text('skip')),
        ],
      ),
    );
  }
}

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<_PlayerState> pumpPlayer(
    WidgetTester tester, {
    required bool restoreFocus,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _Player(restoreFocus: restoreFocus),
      ),
    );
    final player = tester.state<_PlayerState>(find.byType(_Player));
    player.osd.requestFocus();
    await tester.pump();
    expect(player.osd.hasPrimaryFocus, isTrue);
    return player;
  }

  testWidgets('the OSD timing out takes the remote with it', (tester) async {
    final player = await pumpPlayer(tester, restoreFocus: false);

    player.hideOsd();
    await tester.pumpAndSettle();

    expect(player.overlay.hasFocus, isFalse);
    player.keysRead = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(player.keysRead, 0);
  });

  testWidgets('the player reads keys again once the OSD is gone', (
    tester,
  ) async {
    final player = await pumpPlayer(tester, restoreFocus: true);

    player.hideOsd();
    await tester.pumpAndSettle();
    expect(player.overlay.hasPrimaryFocus, isTrue);

    player.keysRead = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(player.keysRead, 1);
  });

  testWidgets('the skip button going away also hands the remote back', (
    tester,
  ) async {
    final player = await pumpPlayer(tester, restoreFocus: true);

    player.showSkipButton();
    await tester.pump();
    player.skip.requestFocus();
    player.hideOsd();
    await tester.pumpAndSettle();
    expect(player.skip.hasPrimaryFocus, isTrue, reason: 'the button keeps it');

    player.hideSkipButton();
    await tester.pumpAndSettle();
    expect(player.overlay.hasPrimaryFocus, isTrue);
  });

  testWidgets('a dialog over the player keeps the remote', (tester) async {
    final player = await pumpPlayer(tester, restoreFocus: true);

    final dialog = FocusNode(debugLabel: 'dialog');
    addTearDown(dialog.dispose);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              Focus(focusNode: dialog, autofocus: true, child: const Text('d')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dialog.hasPrimaryFocus, isTrue);

    player.hideOsd();
    await tester.pumpAndSettle();

    expect(dialog.hasPrimaryFocus, isTrue);
  });
}
