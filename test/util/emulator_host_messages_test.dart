import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/emulator_host_messages.dart';

void main() {
  test('subscribe returns a working no-op dispose off the web', () {
    // This test runs under the VM test runner (dart.library.js_interop is not
    // defined there), so it exercises emulator_host_messages_io.dart: on
    // Android/iOS/desktop, flutter_inappwebview's JavaScript handler already
    // delivers player messages, so there is nothing for this listener to do.
    var received = <Object?>[];
    final dispose = EmulatorHostMessages.subscribe(
      allowedOrigin: 'https://example.test',
      onMessage: received.add,
    );

    // No-op: never invokes the callback, and calling dispose is safe.
    expect(received, isEmpty);
    expect(dispose, isA<void Function()>());
    dispose();
  });
}
