import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/adult_library_dialog.dart';

/// 2026-11-07: the XXX search box closed when the user erased a typo, because
/// the field's Back handler counted Backspace (sent as a key by the phone and
/// TV keyboards) as Back.
void main() {
  Future<void> openSearch(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              // Closing without words returns before any search starts.
              onPressed: () => searchNewAdult(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('Backspace erases text and leaves the search box open', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byType(TextField), 'abcd');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget, reason: 'Backspace must not close the dialog');
    expect(find.text('abc'), findsOneWidget, reason: 'Backspace still erases');
  });

  testWidgets('the remote Back key still closes the search box', (tester) async {
    await openSearch(tester);
    // goBack has no physical key in the test simulator; Escape is the same
    // Back key set.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  test('only Backspace is taken out of the Back keys', () {
    expect(isDialogBackKeyInTextField(LogicalKeyboardKey.backspace), isFalse);
    for (final key in [
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.browserBack,
      LogicalKeyboardKey.gameButtonB,
    ]) {
      expect(isDialogBackKeyInTextField(key), isTrue, reason: '$key');
    }
  });
}
