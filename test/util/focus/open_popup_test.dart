import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/focus/open_popup.dart';

void main() {
  final root = GlobalKey<NavigatorState>();

  FocusNode? focus() => FocusManager.instance.primaryFocus;

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: root, home: home));
  }

  Future<void> openDialog(
    BuildContext context, {
    bool useRootNavigator = true,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
    );
  }

  testWidgets('a screen with nothing over it reports no popup', (tester) async {
    await pumpApp(tester, const Scaffold(body: TextField(autofocus: true)));
    await tester.pump();
    expect(openPopupFor(focus: focus(), root: root.currentState), isNull);
  });

  testWidgets('a dialog on the root is found with focus inside it', (
    tester,
  ) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const Scaffold();
        },
      ),
    );
    openDialog(context);
    await tester.pumpAndSettle();

    final popup = openPopupFor(focus: focus(), root: root.currentState);
    expect(popup, isNotNull);
    expect(popup!.route, isA<PopupRoute<dynamic>>());
    expect(popup.navigator, same(root.currentState));
    expect(focusIsInside(focus(), popup.route), isTrue);
  });

  testWidgets('a dialog on a nested navigator is found on that navigator', (
    tester,
  ) async {
    final nested = GlobalKey<NavigatorState>();
    late BuildContext inner;
    await pumpApp(
      tester,
      Navigator(
        key: nested,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (c) {
            inner = c;
            return const Scaffold();
          },
        ),
      ),
    );
    openDialog(inner, useRootNavigator: false);
    await tester.pumpAndSettle();

    final popup = openPopupFor(focus: focus(), root: root.currentState);
    expect(popup, isNotNull);
    expect(
      popup!.navigator,
      same(nested.currentState),
      reason: 'popping the root instead would take the whole panel away',
    );
    expect(focusIsInside(focus(), popup.route), isTrue);
  });

  testWidgets(
    'a screen inside a popup panel reports the panel with focus outside it',
    (tester) async {
      // The settings panel is a dialog on the root holding its own navigator
      // of ordinary page routes, so a settings screen must not read as a popup
      // itself, but the panel around it still does.
      final nested = GlobalKey<NavigatorState>();
      late BuildContext context;
      await pumpApp(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      );
      showGeneralDialog<void>(
        context: context,
        pageBuilder: (_, _, _) => Navigator(
          key: nested,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: TextField(autofocus: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popup = openPopupFor(focus: focus(), root: root.currentState);
      expect(popup, isNotNull);
      expect(popup!.navigator, same(root.currentState));
      expect(popup.route, isA<RawDialogRoute<void>>());
      expect(
        focusIsInside(focus(), popup.route),
        isFalse,
        reason: 'the focused screen is a page route under the panel',
      );
    },
  );

  testWidgets('with nothing focused the root is still consulted', (
    tester,
  ) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const Scaffold();
        },
      ),
    );
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('plain')),
    );
    await tester.pumpAndSettle();

    final popup = openPopupFor(focus: null, root: root.currentState);
    expect(popup, isNotNull);
    expect(popup!.navigator, same(root.currentState));
  });
}
