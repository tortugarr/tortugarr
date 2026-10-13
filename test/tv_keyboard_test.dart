import 'package:custom_tv_text_field/custom_tv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _keyboardApp(
  KeyboardController controller, {
  InputPurpose purpose = InputPurpose.text,
  List<String> recents = const [],
  Locale? locale,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('de')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: CustomKeyboard(
        keyboardController: controller,
        focusNode: FocusNode(),
        inputPurpose: purpose,
        recentSuggestions: recents,
      ),
    ),
  );
}

void main() {
  group('KeyboardController cursor', () {
    test('inserts at the caret instead of appending', () {
      final controller = KeyboardController();
      controller.setText('moonfin');
      controller.moveCursor(-1);
      controller.moveCursor(-1);
      controller.moveCursor(-1);
      controller.addCharacter('X');
      expect(controller.text, 'moonXfin');
      expect(controller.cursor, 5);
    });

    test('backspace deletes before the caret only', () {
      final controller = KeyboardController();
      controller.setText('abc');
      controller.moveCursor(-1);
      controller.backspace();
      expect(controller.text, 'ac');
      expect(controller.cursor, 1);
      controller.backspace();
      controller.backspace();
      expect(controller.text, 'c');
      expect(controller.cursor, 0);
    });

    test('caret movement clamps at both ends', () {
      final controller = KeyboardController();
      controller.setText('ab');
      controller.moveCursor(1);
      expect(controller.cursor, 2);
      controller.moveCursor(-1);
      controller.moveCursor(-1);
      controller.moveCursor(-1);
      expect(controller.cursor, 0);
    });

    test('surrogate pairs move and delete as one character', () {
      final controller = KeyboardController();
      controller.setText('a\u{1F600}b');
      controller.moveCursor(-1);
      controller.moveCursor(-1);
      expect(controller.cursor, 1);
      controller.moveCursor(1);
      expect(controller.cursor, 3);
      controller.backspace();
      expect(controller.text, 'ab');
    });

    test('setText puts the caret at the end and clear resets it', () {
      final controller = KeyboardController();
      controller.setText('hello');
      expect(controller.cursor, 5);
      controller.clear();
      expect(controller.text, '');
      expect(controller.cursor, 0);
    });
  });

  group('KeyboardLayouts', () {
    test('locale picks the letter arrangement', () {
      expect(
        KeyboardLayouts.variantForLocale(const Locale('fr')),
        KeyboardLayoutVariant.azerty,
      );
      expect(
        KeyboardLayouts.variantForLocale(const Locale('de')),
        KeyboardLayoutVariant.qwertz,
      );
      expect(
        KeyboardLayouts.variantForLocale(const Locale('en')),
        KeyboardLayoutVariant.qwerty,
      );
      expect(
        KeyboardLayouts.variantForLocale(null),
        KeyboardLayoutVariant.qwerty,
      );
    });

    test('shifted layouts derive from the lowercase rows', () {
      final upper = KeyboardLayouts.upperFor(KeyboardLayoutVariant.azerty);
      expect(upper[0].first, 'A');
      expect(upper[1].last, 'M');
      final qwertyUpper = KeyboardLayouts.upperFor(KeyboardLayoutVariant.qwerty);
      expect(qwertyUpper[1].last, '"');
      expect(qwertyUpper[2], contains('BACKSPACE'));
    });
  });

  group('CustomKeyboard widget', () {
    testWidgets('caret keys let a character land mid-word', (tester) async {
      final controller = KeyboardController()..show();
      await tester.pumpWidget(_keyboardApp(controller));
      await tester.pump();

      await tester.tap(find.text('a'));
      await tester.tap(find.text('b'));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      await tester.tap(find.text('c'));
      await tester.pump();

      expect(controller.text, 'acb');
    });

    testWidgets('paste inserts sanitized clipboard text', (tester) async {
      final controller = KeyboardController()..show();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': 'https://demo.moonfin.org\n'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(_keyboardApp(controller));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.content_paste_rounded));
      await tester.pump();

      expect(controller.text, 'https://demo.moonfin.org');
    });

    testWidgets('long pressing backspace clears the whole field',
        (tester) async {
      final controller = KeyboardController()
        ..setText('a long server address')
        ..show();
      await tester.pumpWidget(_keyboardApp(controller));
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(controller.text, '');
    });

    testWidgets('numeric purpose gets the large number pad', (tester) async {
      final controller = KeyboardController()..show();
      await tester.pumpWidget(
        _keyboardApp(controller, purpose: InputPurpose.numeric),
      );
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('q'), findsNothing);
      expect(find.text('SPACE'), findsNothing);

      await tester.tap(find.text('8'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('9'));
      await tester.tap(find.text('6'));
      await tester.pump();
      expect(controller.text, '8096');
    });

    testWidgets('French locale shows AZERTY rows', (tester) async {
      final controller = KeyboardController()..show();
      await tester.pumpWidget(
        _keyboardApp(controller, locale: const Locale('fr')),
      );
      await tester.pumpAndSettle();

      // AZERTY starts its top row with a and z where QWERTY has q and w.
      final aCenter = tester.getCenter(find.text('a'));
      final qCenter = tester.getCenter(find.text('q'));
      expect(aCenter.dy < qCenter.dy, isTrue);
      expect(find.text('m'), findsOneWidget);
    });

    testWidgets('username field offers remembered names as chips',
        (tester) async {
      final controller = KeyboardController()..show();
      await tester.pumpWidget(
        _keyboardApp(
          controller,
          purpose: InputPurpose.username,
          recents: const ['Alice', 'Bob'],
        ),
      );
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      await tester.tap(find.text('Alice'));
      await tester.pump();

      expect(controller.text, 'Alice');
      expect(controller.isVisible, isFalse);
    });

    testWidgets('url field lists recent servers before the static helpers',
        (tester) async {
      final controller = KeyboardController()..show();
      await tester.pumpWidget(
        _keyboardApp(
          controller,
          purpose: InputPurpose.url,
          recents: const ['https://demo.moonfin.org:8096'],
        ),
      );
      await tester.pump();

      expect(find.text('https://demo.moonfin.org:8096'), findsOneWidget);
      await tester.tap(find.text('https://demo.moonfin.org:8096'));
      await tester.pump();

      // A recent address replaces the text but keeps the keyboard open for
      // edits, unlike a submit chip.
      expect(controller.text, 'https://demo.moonfin.org:8096');
      expect(controller.isVisible, isTrue);
    });
  });
}
