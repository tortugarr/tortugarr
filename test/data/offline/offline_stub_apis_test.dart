import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/offline/offline_stub_apis.dart';

void main() {
  // An empty configuration reads as a user who excludes nothing, so a caller
  // that caches it goes on showing every library long after the server is back.
  test('the offline stub refuses to invent a user configuration', () {
    expect(const OfflineUsersApi().getUserConfiguration(), throwsA(anything));
  });
}
