import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/seerr/seerr_discover_screen.dart';

void main() {
  Future<Map<String, dynamic>> seasons(String _) async => {
        'Items': [
          {'Id': 'season-1', 'IndexNumber': 1},
          {'Id': 'season-13', 'IndexNumber': 13},
        ],
      };
  Future<Map<String, dynamic>> episodes(String _, String seasonId) async => {
        'Items': [
          {'Id': 'ep-1', 'IndexNumber': 1},
          {'Id': 'ep-4', 'IndexNumber': 4},
        ],
      };

  test('an episode the library has opens that episode', () async {
    expect(
      await resolveSeasonTarget('series', season: 13, episode: 4,
          getSeasons: seasons, getEpisodes: episodes),
      'ep-4',
    );
  });

  test('a missing episode opens its season', () async {
    expect(
      await resolveSeasonTarget('series', season: 13, episode: 9,
          getSeasons: seasons, getEpisodes: episodes),
      'season-13',
    );
  });

  test('a season without an episode number opens the season', () async {
    expect(
      await resolveSeasonTarget('series', season: 1,
          getSeasons: seasons, getEpisodes: episodes),
      'season-1',
    );
  });

  test('a season the library lacks opens the series', () async {
    expect(
      await resolveSeasonTarget('series', season: 7, episode: 1,
          getSeasons: seasons, getEpisodes: episodes),
      'series',
    );
  });

  test('a failing lookup opens the series', () async {
    expect(
      await resolveSeasonTarget('series', season: 1,
          getSeasons: (_) async => throw Exception('offline'),
          getEpisodes: episodes),
      'series',
    );
  });
}
