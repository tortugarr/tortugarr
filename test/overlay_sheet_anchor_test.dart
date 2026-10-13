import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/overlay_sheet.dart';

void main() {
  testWidgets('an anchored sheet opens at the anchor, a plain one centers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));

    OverlaySheetController.show<void>(ctx,
        anchor: const Offset(120, 90),
        builder: (_) => const SizedBox(key: Key('m'), width: 200, height: 100));
    await tester.pumpAndSettle();
    final anchored = tester.getTopLeft(find.byKey(const Key('m')));
    OverlaySheetController.closeTopSheet();
    await tester.pumpAndSettle();

    OverlaySheetController.show<void>(ctx,
        builder: (_) => const SizedBox(key: Key('c'), width: 200, height: 100));
    await tester.pumpAndSettle();
    final centred = tester.getTopLeft(find.byKey(const Key('c')));

    expect(anchored, const Offset(120, 90));
    expect(centred, const Offset(400, 350));
  });

  testWidgets('a sheet bigger than the window is held inside it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));

    OverlaySheetController.show<void>(ctx,
        anchor: const Offset(500, 400),
        builder: (_) =>
            Container(key: const Key('m'), color: const Color(0xFF000000)));
    await tester.pumpAndSettle();

    final r = tester.getRect(find.byKey(const Key('m')));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(1000));
    expect(r.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('an anchor near the edge flips back on screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));

    OverlaySheetController.show<void>(ctx,
        anchor: const Offset(980, 780),
        builder: (_) => const SizedBox(key: Key('m'), width: 200, height: 100));
    await tester.pumpAndSettle();

    final r = tester.getRect(find.byKey(const Key('m')));
    expect(r.right, lessThanOrEqualTo(1000));
    expect(r.bottom, lessThanOrEqualTo(800));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.top, greaterThanOrEqualTo(0));
  });
}
