import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/floating_notification.dart';
import 'package:moonfin/util/platform_detection.dart';

void main() {
  // TV can't tap the card, which is the case that used to leave the text with
  // no theme above it.
  testWidgets('the text is themed on TV too', (tester) async {
    PlatformDetection.setTvMode(true);
    addTearDown(() => PlatformDetection.setTvMode(false));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                FloatingNotification.show(context, 'Title', 'Body', () {}),
            child: const Text('show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    expect(
      find.ancestor(of: find.text('Title'), matching: find.byType(Material)),
      findsWidgets,
    );

    // Let the card time out so no timer is left behind.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });
}
