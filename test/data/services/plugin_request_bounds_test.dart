import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/plugin_sync_service.dart';

void main() {
  // Sign-in waits on the themes call before it reads the profile that decides
  // which home rows exist. With no bound the socket waits as long as the system
  // allows, which held the profile back for over two minutes.
  test('the plugin bounds how long a request may hang', () {
    final options = pluginRequestOptions();
    expect(options.connectTimeout, isNotNull);
    expect(
      options.connectTimeout,
      lessThanOrEqualTo(const Duration(seconds: 8)),
    );
    expect(options.receiveTimeout, isNotNull);
    expect(
      options.receiveTimeout,
      lessThanOrEqualTo(const Duration(minutes: 1)),
    );
  });
}
