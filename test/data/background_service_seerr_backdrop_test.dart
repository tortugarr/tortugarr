import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/background_service.dart';
import 'package:moonfin/data/services/media_server_client_factory.dart';
import 'package:server_core/server_core.dart';

class _Factory extends Mock implements MediaServerClientFactory {}

class _Client extends Mock implements MediaServerClient {}

AggregatedItem _seerrCard(String backdropPath) => AggregatedItem(
  id: '603',
  serverId: 'seerr',
  rawData: {
    'Name': 'The Matrix',
    'Type': 'Movie',
    'PosterPath': 'https://image.tmdb.org/t/p/w300/poster.jpg',
    'BackdropPath': backdropPath,
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackgroundService service;

  setUp(() {
    final factory = _Factory();
    when(() => factory.clientForServerOrActive(any())).thenReturn(_Client());
    GetIt.instance.registerSingleton<MediaServerClientFactory>(factory);
    service = BackgroundService();
  });

  tearDown(() async {
    service.dispose();
    await GetIt.instance.reset();
  });

  test('a Seerr card with no backdrop clears the page background rather than '
      'blurring its poster', () {
    service.setBackgroundUrl('https://image.tmdb.org/t/p/w1280/previous.jpg');
    expect(service.currentUrl, isNotNull);

    service.setBackground(_seerrCard(''), context: BlurContext.browsing);

    expect(service.currentUrl, isNull);
  });

  test('a Seerr card shows its backdrop, from a TMDB path or a full URL', () {
    service.setBackground(_seerrCard('/backdrop.jpg'));
    expect(
      service.currentUrl,
      'https://image.tmdb.org/t/p/w1280/backdrop.jpg',
    );

    service.setBackground(_seerrCard('https://example.com/backdrop.jpg'));
    expect(service.currentUrl, 'https://example.com/backdrop.jpg');
  });
}
