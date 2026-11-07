import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/prowlarr_search_client.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/download_now/release_picker_dialog.dart';

/// 2026-11-07: Left/Right in the release list switches tier and lands on the
/// top of the new list; the list shows sound badges from the release name.
void main() {
  ProwlarrRelease r(String title, int gb) => ProwlarrRelease(
    guid: title,
    title: title,
    size: gb << 30,
    indexerId: 1,
    indexer: 'idx',
    seeders: 10,
    protocol: 'torrent',
  );

  final releases = [
    r('Dune.2160p.A.DDP5.1.Atmos', 30),
    r('Dune.2160p.B', 20),
    r('Dune.2160p.C', 10),
    r('Dune.1080p.A.AAC2.0', 9),
    r('Dune.1080p.B', 8),
  ];

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showReleaseListDialog(context, title: 'Dune', releases: releases),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool focused(WidgetTester tester, String title) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return find.descendant(of: find.byWidget(ctx.widget), matching: find.text(title)).evaluate().isNotEmpty;
  }

  Future<void> focus(WidgetTester tester, String title) async {
    Focus.of(tester.element(find.text(title))).requestFocus();
    await tester.pump();
  }

  testWidgets('Right from deep in 2160p goes to the top of 1080p, Left back to the top of 2160p', (tester) async {
    await open(tester);
    expect(find.text('Dune.1080p.B'), findsNothing, reason: 'starts on 2160p');

    await focus(tester, 'Dune.2160p.C');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Dune.2160p.C'), findsNothing);
    expect(focused(tester, 'Dune.1080p.A.AAC2.0'), isTrue, reason: 'top row of 1080p');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focused(tester, 'Dune.2160p.A.DDP5.1.Atmos'), isTrue, reason: 'top row of 2160p');

    // Left on the first tier stays put.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focused(tester, 'Dune.2160p.A.DDP5.1.Atmos'), isTrue);
  });

  testWidgets('two Rights from 2160p reach All (empty tiers skipped), and Right there stays', (tester) async {
    await open(tester);
    await focus(tester, 'Dune.2160p.B');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // no 720p: straight to All
    await tester.pumpAndSettle();
    expect(find.text('Dune.1080p.B'), findsOneWidget);
    expect(find.text('Dune.2160p.B'), findsOneWidget, reason: 'All lists every release');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Dune.2160p.B'), findsOneWidget);
  });

  testWidgets('sound badges under the release name', (tester) async {
    await open(tester);
    expect(find.text('Atmos'), findsOneWidget);
    expect(find.text('DD+'), findsOneWidget);
    expect(find.text('5.1'), findsOneWidget);
  });

  testWidgets('a dead torrent goes last with its badge; live seeders are shown as live', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final list = [
      ProwlarrRelease(guid: 'big', title: 'Film.2160p.Big', size: 40 << 30, indexerId: 1, indexer: 'i',
          seeders: 900, protocol: 'torrent', liveSeeders: 0, dead: true),
      ProwlarrRelease(guid: 'small', title: 'Film.2160p.Small', size: 10 << 30, indexerId: 1, indexer: 'i',
          seeders: 3, protocol: 'torrent', liveSeeders: 150),
    ];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showReleaseListDialog(context, title: 'Film', releases: list),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final small = tester.getTopLeft(find.text('Film.2160p.Small')).dy;
    final big = tester.getTopLeft(find.text('Film.2160p.Big')).dy;
    expect(small < big, isTrue, reason: 'the dead one is last although it is bigger');
    expect(find.text('Dead · 0 seeders'), findsOneWidget);
    expect(find.textContaining('(live)'), findsNWidgets(2));
  });
}
