import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/download_now/plugin_search_progress.dart';

void main() {
  setUp(resetPluginSearchProgressForTest);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    return ctx;
  }

  testWidgets('Cancel closes at once and tells the search, which never finishes',
      (tester) async {
    final ctx = await pumpHost(tester);
    bool Function()? isCancelled;
    final never = Completer<int>();
    final result = showPluginSearchProgress<int>(ctx, title: 'Mike S01', start: (c) {
      isCancelled = c;
      return never.future;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mike S01'), findsOneWidget);
    expect(isCancelled!(), isFalse);

    await tester.tap(find.text('Cancel'));
    expect(isCancelled!(), isTrue, reason: 'the search hears about the cancel before the dialog closes');
    await tester.pumpAndSettle();

    expect(find.text('Mike S01'), findsNothing);
    expect((await result).cancelled, isTrue);
  });

  testWidgets('a second search while one is open does not stack a dialog', (tester) async {
    final ctx = await pumpHost(tester);
    final never = Completer<int>();
    var starts = 0;
    Future<int> start(bool Function() _) {
      starts++;
      return never.future;
    }

    final first = showPluginSearchProgress<int>(ctx, title: 'Mike S01', start: start);
    final second = showPluginSearchProgress<int>(ctx, title: 'Mike S01', start: start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect((await second).cancelled, isTrue);
    expect(starts, 1);
    expect(find.text('Mike S01'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Mike S01'), findsNothing);
    expect((await first).cancelled, isTrue);
  });
}
