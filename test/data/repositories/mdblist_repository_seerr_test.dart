import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/mdblist_repository.dart';
import 'package:moonfin/data/repositories/tmdb_repository.dart';
import 'package:server_core/server_core.dart';

class _Client extends Mock implements MediaServerClient {}

class _ItemsApi extends Mock implements ItemsApi {}

/// Records the ratings lookups instead of calling the plugin.
class _RecordingRepository extends MdbListRepository {
  _RecordingRepository(MediaServerClient client)
    : super(client, TmdbRepository(client));

  final calls = <(String, String)>[];

  @override
  Future<Map<String, double>?> getRatings({
    required String tmdbId,
    required String mediaType,
  }) async {
    calls.add((tmdbId, mediaType));
    return {'imdb': 7.5};
  }
}

AggregatedItem _seerrCard({
  required String id,
  String type = 'Movie',
  Map<String, String>? providerIds,
}) => AggregatedItem(
  id: id,
  serverId: 'seerr',
  rawData: {
    'Name': 'The Matrix',
    'Type': type,
    'ProviderIds': ?providerIds,
  },
);

void main() {
  late _Client client;
  late _ItemsApi itemsApi;
  late _RecordingRepository repository;

  setUp(() {
    client = _Client();
    itemsApi = _ItemsApi();
    when(() => client.itemsApi).thenReturn(itemsApi);
    repository = _RecordingRepository(client);
  });

  tearDown(() => repository.dispose());

  void expectNoServerLookup() {
    verifyNever(() => client.itemsApi);
    verifyNever(
      () => itemsApi.getItem(
        any(),
        mediaSourceId: any(named: 'mediaSourceId'),
        fields: any(named: 'fields'),
      ),
    );
  }

  group('ratings for a Seerr card', () {
    test('use the TMDB id the card carries', () async {
      final ratings = await repository.getRatingsForItem(
        _seerrCard(
          id: 'tt0133093',
          providerIds: {'Imdb': 'tt0133093', 'Tmdb': '603'},
        ),
        resolveClient: client,
      );

      expect(ratings, {'imdb': 7.5});
      expect(repository.calls, [('603', 'Movie')]);
      expectNoServerLookup();
    });

    test('use the card id when there are no provider ids, since Seerr keys '
        'its items by TMDB id', () async {
      await repository.getRatingsForItem(
        _seerrCard(id: '1399', type: 'Series'),
        resolveClient: client,
      );

      expect(repository.calls, [('1399', 'Series')]);
      expectNoServerLookup();
    });

    test('skip a card that only has an IMDb id', () async {
      final ratings = await repository.getRatingsForItem(
        _seerrCard(id: 'tt0133093', providerIds: {'Imdb': 'tt0133093'}),
        resolveClient: client,
      );

      expect(ratings, isNull);
      expect(repository.calls, isEmpty);
      expectNoServerLookup();
    });
  });

  test('resolveTmdbId never asks the server about a Seerr id', () async {
    expect(
      await repository.resolveTmdbId(
        itemId: '603',
        serverId: 'seerr',
        knownTmdbId: null,
      ),
      '603',
    );
    expect(
      await repository.resolveTmdbId(
        itemId: 'tt0133093',
        serverId: 'seerr',
        knownTmdbId: null,
      ),
      isNull,
    );
    expectNoServerLookup();
  });

  test('a library item still resolves its TMDB id through its server', () async {
    when(
      () => itemsApi.getItem('abc', fields: 'ProviderIds'),
    ).thenAnswer((_) async => {
      'ProviderIds': {'Tmdb': '42'},
    });

    await repository.getRatingsForItem(
      const AggregatedItem(
        id: 'abc',
        serverId: 'server-1',
        rawData: {'Type': 'Movie'},
      ),
      resolveClient: client,
    );

    expect(repository.calls, [('42', 'Movie')]);
    verify(() => itemsApi.getItem('abc', fields: 'ProviderIds')).called(1);
  });
}
