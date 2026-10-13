import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/playback/playback_takeover.dart';

/// A 1x1 transparent PNG, enough to put a real decoded entry in the cache.
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

void main() {
  testWidgets('releasing image memory empties the image cache', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    // Decoding runs outside the fake-async zone, so the cache entry is real.
    await tester.runAsync(() => precacheImage(MemoryImage(_tinyPng), context));
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.currentSize, greaterThan(0));

    releaseImageMemoryForPlayback();

    expect(cache.currentSize, 0);
    expect(cache.liveImageCount, 0);
  });

  testWidgets('detaching text input drops focus and the IME client', (
    tester,
  ) async {
    final sentMethods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        sentMethods.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );

    // A bare focus node sends no IME traffic of its own when unfocused, so
    // every method the channel sees below came from the helper.
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Focus(focusNode: node, child: const SizedBox()),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);

    detachTextInputForPlayback();
    await tester.pump();

    expect(node.hasFocus, isFalse);
    expect(sentMethods, contains('TextInput.hide'));
    expect(sentMethods, contains('TextInput.clearClient'));
  });
}
