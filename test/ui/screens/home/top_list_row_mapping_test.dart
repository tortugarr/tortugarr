import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/home_section_config.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';

/// What the Tortugarr plugin answers for GET /TopLists/{index} (2026-11-08).
Map<String, dynamic> _body() => {
  'index': 1,
  'title': 'Most watched shows this week',
  'items': [
    {
      'tmdbId': 247718,
      'tvdbId': 446831,
      'imdbId': 'tt31510819',
      'mediaType': 'tv',
      'title': 'MobLand',
      'year': 2025,
      'overview': 'Two mob families clash.',
      'posterUrl': 'https://image.tmdb.org/t/p/w342/a.jpg',
      'backdropUrl': 'https://image.tmdb.org/t/p/w780/b.jpg',
      'libraryItemId': null,
    },
    {
      'tmdbId': 1399,
      'mediaType': 'tv',
      'title': 'Game of Thrones',
      'libraryItemId': '0F2A6C8E-1111-2222-3333-444455556666',
    },
    {'tmdbId': 0, 'mediaType': 'movie', 'title': 'No id'},
  ],
};

void main() {
  test('owned titles become library cards, the rest Seerr cards, in list order', () {
    final row = HomeViewModel.mapTopList(
      _body(),
      owned: {
        '0f2a6c8e111122223333444455556666': {'Id': '0f2a6c8e111122223333444455556666', 'Name': 'Game of Thrones', 'Type': 'Series'},
      },
      serverId: 'http://server',
    )!;
    expect(row.id, 'tortugarr_top_1');
    expect(row.title, 'Most watched shows this week');
    expect(row.items, hasLength(2));

    final suggestion = row.items[0];
    expect(suggestion.serverId, 'seerr');
    expect(suggestion.id, '247718');
    expect(suggestion.rawData['Type'], 'Series');
    expect(suggestion.rawData['SeerrMediaType'], 'tv');
    expect(suggestion.rawData['PosterPath'], 'https://image.tmdb.org/t/p/w342/a.jpg');
    expect(suggestion.rawData['ProviderIds'], {'Tmdb': '247718', 'Imdb': 'tt31510819', 'Tvdb': '446831'});

    final mine = row.items[1];
    expect(mine.serverId, 'http://server');
    expect(mine.id, '0f2a6c8e111122223333444455556666');
  });

  test('an owned title the server did not return falls back to a Seerr card', () {
    final row = HomeViewModel.mapTopList(_body(), owned: const {}, serverId: 's')!;
    expect(row.items.map((i) => i.serverId), ['seerr', 'seerr']);
  });

  test('nothing usable gives no row', () {
    expect(HomeViewModel.mapTopList({'index': 0, 'title': 'x', 'items': []}, owned: const {}, serverId: 's'), isNull);
    expect(HomeViewModel.mapTopList({'title': 'no index', 'items': []}, owned: const {}, serverId: 's'), isNull);
  });

  test('top lists are a default home section, on, and serialize by name', () {
    final cfg = HomeSectionConfig.defaults().singleWhere((c) => c.type == HomeSectionType.tortugarrTopLists);
    expect(cfg.enabled, isTrue);
    expect(HomeSectionType.fromSerialized('tortugarr_top_lists'), HomeSectionType.tortugarrTopLists);
  });
}
