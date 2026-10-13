import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/tv_image_cache_io.dart';

void main() {
  // Artwork goes through the cache manager's own client rather than the one
  // the API calls share, so nothing that bounds those reaches it. A grid asking
  // for dozens of images opened a connection each, which is what fails on a
  // link that drops connection attempts while the API calls beside it succeed.
  test('artwork requests are bounded like the api ones', () {
    final client = buildImageHttpClient();
    addTearDown(() => client.close(force: true));

    expect(client.maxConnectionsPerHost, imageRequestSlots);
    expect(client.connectionTimeout, isNotNull);
    expect(
      client.connectionTimeout,
      lessThanOrEqualTo(const Duration(seconds: 8)),
    );
  });

  test('artwork takes a smaller share of the link than the api', () {
    expect(imageRequestSlots, lessThan(6));
    expect(imageRequestSlots, greaterThan(0));
  });
}
