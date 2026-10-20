import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/admin/widgets/admin_tv_keys.dart';

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

    // The test harness has no physical key for goBack; Escape takes the same path.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(top.hasPrimaryFocus, isFalse);
    expect(slider.hasPrimaryFocus, isTrue);
  });
}
