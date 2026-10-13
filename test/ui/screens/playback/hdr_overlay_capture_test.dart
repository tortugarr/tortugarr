import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/hdr_overlay_channel.dart';
import 'package:moonfin/ui/screens/playback/hdr_overlay_capture.dart';

void main() {
  testWidgets('the capture boundary stays off where it can never run', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HdrOverlayCapture(
          enabled: false,
          channel: HdrOverlayChannel(),
          child: const SizedBox(key: Key('chrome')),
        ),
      ),
    );

    // The capture arrangement is Windows only, so no other player carries a
    // boundary for it.
    expect(HdrOverlayCapture.canCapture, isFalse);
    expect(
      find.descendant(
        of: find.byType(HdrOverlayCapture),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('chrome')), findsOneWidget);
  });
}
