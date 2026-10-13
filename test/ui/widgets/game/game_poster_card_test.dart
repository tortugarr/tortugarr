import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/theme/app_theme.dart';
import 'package:moonfin/ui/widgets/bounded_network_image.dart';
import 'package:moonfin/ui/widgets/focus/focusable_wrapper.dart';
import 'package:moonfin/ui/widgets/game/game_card_focus_frame.dart';
import 'package:moonfin/ui/widgets/game/game_poster_card.dart';
import 'package:moonfin/util/focus/input_mode_tracker.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:moonfin_design/moonfin_design.dart';

void main() {
  setUp(() => ThemeRegistry.setActiveById(ThemeRegistry.moonfinId));

  testWidgets('focus and hover callbacks follow actual interaction', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var focused = 0;
    var focusLost = 0;
    var hoverStarted = 0;
    var hoverEnded = 0;

    await tester.pumpWidget(
      _TestApp(
        child: GamePosterCard(
          imageUrl: null,
          title: 'River Raid',
          fileName: 'River Raid (USA).a26',
          seed: 'river-raid',
          width: 110,
          focusNode: focusNode,
          onFocus: () => focused++,
          onFocusLost: () => focusLost++,
          onHoverStart: () => hoverStarted++,
          onHoverEnd: () => hoverEnded++,
          onTap: () {},
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focused, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(GamePosterCard)));
    await tester.pump();
    expect(hoverStarted, 1);

    // Leaving with keyboard focus retained must not clear the active item.
    await mouse.moveTo(const Offset(1000, 1000));
    await tester.pump();
    expect(hoverEnded, 0);

    focusNode.unfocus();
    await tester.pump();
    expect(focusLost, 1);
  });

  testWidgets('large text can use the card intrinsic caption height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        textScaler: const TextScaler.linear(3),
        child: GamePosterCard(
          imageUrl: null,
          title: 'A deliberately long two-line game title',
          fileName: 'long-title.rom',
          seed: 'long-title',
          width: 110,
          onTap: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('A deliberately long two-line game title'),
      findsOneWidget,
    );
  });

  testWidgets('can defer artwork without losing the fallback', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: GamePosterCard(
          imageUrl: 'https://example.invalid/poster.jpg',
          title: 'Deferred',
          fileName: 'deferred.rom',
          seed: 'deferred',
          width: 110,
          loadArtwork: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(BoundedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.videogame_asset), findsOneWidget);
  });

  testWidgets('TV right traversal stops at the row edge', (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    final alphaFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);
    addTearDown(alphaFocus.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GamePosterCard(
              imageUrl: null,
              title: 'First',
              fileName: 'first.rom',
              seed: 'first',
              width: 110,
              focusNode: firstFocus,
              onTap: () {},
            ),
            GamePosterCard(
              imageUrl: null,
              title: 'Second',
              fileName: 'second.rom',
              seed: 'second',
              width: 110,
              focusNode: secondFocus,
              stopRightTraversal: true,
              onTap: () {},
            ),
            Focus(
              focusNode: alphaFocus,
              child: const SizedBox(width: 30, height: 30),
            ),
          ],
        ),
      ),
    );

    firstFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);
    expect(alphaFocus.hasFocus, isFalse);
  });

  testWidgets('uses only the game focus frame around artwork', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: GamePosterCard(
          imageUrl: null,
          title: 'Focused',
          fileName: 'focused.rom',
          seed: 'focused',
          width: 110,
          focusNode: focusNode,
          onTap: () {},
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    // The card owns its focus visuals; there is a single border source (the
    // game focus frame) and no FocusableWrapper to draw a second outline.
    expect(find.byType(FocusableWrapper), findsNothing);
    expect(find.byType(GameCardFocusFrame), findsOneWidget);
  });

  testWidgets('on TV a mouse still highlights what it hovers', (tester) async {
    // InputModeTracker.of() is pinned to keyboard on TV so focus visuals can
    // never vanish for a remote user. Hover state must not be keyed on it, or a
    // mouse on a TV box highlights nothing at all.
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));

    final node = FocusNode(debugLabel: 'first');
    addTearDown(node.dispose);

    await tester.pumpWidget(
      _TestApp(
        child: InputModeTracker(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GamePosterCard(
                focusNode: node,
                title: 'Gauntlet',
                fileName: 'gauntlet.zip',
                seed: 'gauntlet',
                autoScroll: false,
                onTap: () {},
              ),
              GamePosterCard(
                title: 'Giga Wing',
                fileName: 'gigawing.zip',
                seed: 'gigawing',
                autoScroll: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    List<bool> frames() => tester
        .widgetList<GameCardFocusFrame>(find.byType(GameCardFocusFrame))
        .map((frame) => frame.active)
        .toList(growable: false);

    node.requestFocus();
    await tester.pumpAndSettle();
    expect(frames(), [true, false], reason: 'd-pad focus highlights on TV');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() => mouse.removePointer());
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(GamePosterCard).last));
    await tester.pumpAndSettle();

    expect(frames(), [
      false,
      true,
    ], reason: 'the hovered card highlights on TV');
  });

  testWidgets(
    'a resting pointer stops highlighting once the d-pad moves focus',
    (tester) async {
      final restingNode = FocusNode(debugLabel: 'resting');
      final movedNode = FocusNode(debugLabel: 'moved');
      addTearDown(restingNode.dispose);
      addTearDown(movedNode.dispose);

      await tester.pumpWidget(
        _TestApp(
          child: InputModeTracker(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GamePosterCard(
                  focusNode: restingNode,
                  title: 'Gauntlet',
                  fileName: 'gauntlet.zip',
                  seed: 'gauntlet',
                  autoScroll: false,
                  onTap: () {},
                ),
                GamePosterCard(
                  focusNode: movedNode,
                  title: 'Giga Wing',
                  fileName: 'gigawing.zip',
                  seed: 'gigawing',
                  autoScroll: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      List<bool> frames() => tester
          .widgetList<GameCardFocusFrame>(find.byType(GameCardFocusFrame))
          .map((frame) => frame.active)
          .toList(growable: false);

      // A cursor comes to rest on the first card and never moves again.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() => mouse.removePointer());
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(GamePosterCard).first));
      await tester.pumpAndSettle();
      expect(frames(), [true, false], reason: 'the pointer owns the highlight');

      // The user picks up the remote and moves focus to the second card.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      movedNode.requestFocus();
      await tester.pumpAndSettle();

      // The stationary pointer must not leave a second border behind.
      expect(frames(), [false, true]);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.textScaler = TextScaler.noScaling});

  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.buildTheme(ThemeRegistry.active),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }
}
