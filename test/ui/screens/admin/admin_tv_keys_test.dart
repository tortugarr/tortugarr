import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/admin/widgets/admin_tv_keys.dart';
import 'package:moonfin/ui/widgets/overlay_sheet.dart' show InlineBackInterceptor;

void main() {
  late FocusNode top;
  late FocusNode slider;
  late FocusNode bottom;

  Future<void> pump(WidgetTester tester) async {
    top = FocusNode();
    slider = FocusNode();
    bottom = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminTvKeys(
          child: Column(
            children: [
              TextField(focusNode: top, maxLines: 3),
              Slider(focusNode: slider, value: 0.5, onChanged: (_) {}),
              TextField(focusNode: bottom),
            ],
          ),
        ),
      ),
    ));
  }

  testWidgets('Up and Down leave a text field and a slider', (tester) async {
    await pump(tester);
    top.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(slider.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(bottom.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(slider.hasPrimaryFocus, isTrue);
  });

  testWidgets('Back in a text field leaves the field, not the page', (tester) async {
    await pump(tester);
    top.requestFocus();
    await tester.pump();

    // The app's Back handling (key and popRoute) asks InlineBackInterceptor.
    expect(InlineBackInterceptor.handleBack(), isTrue);
    await tester.pump();
    expect(top.hasPrimaryFocus, isFalse);
    expect(slider.hasPrimaryFocus, isTrue);
  });

  // 2026-10-20 on the TV: the dashboard's top (tiles, server info) has nothing
  // focusable and the page sits in the shell's own navigator, so the remote
  // could neither scroll back to the top nor reach the menu on the left.
  testWidgets('Up scrolls a page to its top, Left leaves the page navigator',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final menu = FocusNode();
    final scan = FocusNode();
    final below = FocusNode();
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminTvKeys(
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextButton(focusNode: menu, onPressed: () {}, child: const Text('Dashboard')),
              ),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => ListView(
                      controller: scroll,
                      children: [
                        const SizedBox(height: 600, child: Text('tiles and server info')),
                        TextButton(focusNode: scan, onPressed: () {}, child: const Text('Scan All Libraries')),
                        const SizedBox(height: 400),
                        TextButton(focusNode: below, onPressed: () {}, child: const Text('See All')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    scroll.jumpTo(500);
    scan.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(scan.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(menu.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(menu.hasPrimaryFocus, isFalse);
  });

  testWidgets('Back goes from the page to the menu, not out of the admin area',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pages = GlobalKey<NavigatorState>();
    final rail = FocusNode();
    final list = FocusNode();
    final scan = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminTvKeys(
          pages: pages,
          exit: rail,
          child: Row(
            children: [
              SizedBox(width: 100, child: TextButton(focusNode: rail, onPressed: () {}, child: const Text('Exit'))),
              SizedBox(width: 200, child: TextButton(focusNode: list, onPressed: () {}, child: const Text('Dashboard'))),
              Expanded(
                child: Navigator(
                  key: pages,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Align(
                      alignment: Alignment.topLeft,
                      child: TextButton(focusNode: scan, onPressed: () {}, child: const Text('Scan')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    scan.requestFocus();
    await tester.pumpAndSettle();

    // The app's Back handling (key and popRoute) asks InlineBackInterceptor.
    expect(InlineBackInterceptor.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(list.hasPrimaryFocus, isTrue);

    expect(InlineBackInterceptor.handleBack(), isTrue);
    await tester.pumpAndSettle();
    expect(rail.hasPrimaryFocus, isTrue);

    // Back stops on Exit, however often it is pressed.
    for (var i = 0; i < 3; i++) {
      expect(InlineBackInterceptor.handleBack(), isTrue);
      await tester.pumpAndSettle();
    }
    expect(rail.hasPrimaryFocus, isTrue);
  });
}
