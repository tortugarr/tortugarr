import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/util/season_queue_context.dart';

const _seriesId = 'series-alpha';
const _season1Id = 'season-1';
const _season2Id = 'season-2';
const _specialsId = 'season-specials';

AggregatedItem _episode(
  String id, {
  String seriesId = _seriesId,
  String? seasonId = _season1Id,
  int seasonNumber = 1,
  int? indexNumber,
  String type = 'Episode',
}) {
  return AggregatedItem(
    id: id,
    serverId: 'server',
    rawData: {
      'Id': id,
      'Type': type,
      'SeriesId': seriesId,
      'SeasonId': ?seasonId,
      'ParentIndexNumber': seasonNumber,
      'IndexNumber': ?indexNumber,
    },
  );
}

/// A special as the server hands it over: filed under Specials, displayed
/// inside a regular season.
AggregatedItem _special(String id, {int indexNumber = 1}) => _episode(
  id,
  seasonId: _specialsId,
  seasonNumber: 0,
  indexNumber: indexNumber,
);

AggregatedItem _preroll(String id) => AggregatedItem(
  id: id,
  serverId: 'server',
  rawData: {'Id': id, 'Type': 'Trailer', '__moonfinIsPreroll': true},
);

void main() {
  group('resolveQueueSeason', () {
    test('reads season 1 from a queue an airs-before special leads', () {
      final season = resolveQueueSeason([
        _special('opening-special'),
        _episode('s1e1', indexNumber: 1),
        _episode('s1e2', indexNumber: 2),
      ]);

      expect(season?.seasonId, _season1Id);
      expect(season?.seasonNumber, 1);
    });

    test('reads season 1 from a queue an airs-after special trails', () {
      final season = resolveQueueSeason([
        _episode('s1e1', indexNumber: 1),
        _episode('s1e2', indexNumber: 2),
        _special('season-1-finale-special'),
      ]);

      expect(season?.seasonId, _season1Id);
      expect(season?.seasonNumber, 1);
    });

    test('returns null for a queue of nothing but specials', () {
      expect(
        resolveQueueSeason([_special('one'), _special('two', indexNumber: 2)]),
        isNull,
      );
    });

    test('ignores prerolls stitched into the queue', () {
      final season = resolveQueueSeason([
        _preroll('preroll'),
        _episode('s2e1', seasonId: _season2Id, seasonNumber: 2, indexNumber: 1),
      ]);

      expect(season?.seasonId, _season2Id);
      expect(season?.seasonNumber, 2);
    });
  });

  group('isSeasonScopedEpisodeQueue', () {
    bool scoped(
      List<AggregatedItem> queue, {
      String seasonId = _season1Id,
      int seasonNumber = 1,
    }) => isSeasonScopedEpisodeQueue(
      queue,
      seriesId: _seriesId,
      seasonId: seasonId,
      seasonNumber: seasonNumber,
    );

    test('accepts an inlined special as a member of the season', () {
      expect(
        scoped([_special('inlined-special'), _episode('s1e1', indexNumber: 1)]),
        isTrue,
      );
      expect(
        scoped([_episode('s1e1', indexNumber: 1), _special('inlined-special')]),
        isTrue,
      );
    });

    test('rejects a queue spanning two real seasons', () {
      expect(
        scoped([
          _episode('s1e1', indexNumber: 1),
          _episode(
            's2e1',
            seasonId: _season2Id,
            seasonNumber: 2,
            indexNumber: 1,
          ),
        ]),
        isFalse,
      );
    });

    test('rejects another series and non-episodes', () {
      expect(
        scoped([_episode('other', seriesId: 'series-other', indexNumber: 1)]),
        isFalse,
      );
      expect(
        scoped([_episode('movie', type: 'Movie', indexNumber: 1)]),
        isFalse,
      );
    });

    test(
      'falls back to the season number when the item carries no season id',
      () {
        expect(
          scoped([_episode('s1e1', seasonId: null, indexNumber: 1)]),
          isTrue,
        );
        expect(
          scoped([
            _episode('s3e1', seasonId: null, seasonNumber: 3, indexNumber: 1),
          ]),
          isFalse,
        );
      },
    );

    test('rejects an empty queue and one holding only prerolls', () {
      expect(scoped([]), isFalse);
      expect(scoped([_preroll('preroll')]), isFalse);
    });
  });

  group('orderSeasonEpisodes', () {
    test('sorts a scrambled season that holds no special', () {
      final ordered = orderSeasonEpisodes([
        _episode('s1e3', indexNumber: 3),
        _episode('s1e1', indexNumber: 1),
        _episode('s1e2', indexNumber: 2),
      ]);

      expect(ordered.map((e) => e.id), ['s1e1', 's1e2', 's1e3']);
    });

    test('leaves air order alone when a special trails the season', () {
      final aired = [
        _episode('s1e1', indexNumber: 1),
        _episode('s1e2', indexNumber: 2),
        _special('airs-after'),
      ];

      expect(orderSeasonEpisodes(aired).map((e) => e.id), [
        's1e1',
        's1e2',
        'airs-after',
      ]);
    });

    test('still sorts the Specials season, which inlines nothing', () {
      final scrambled = [
        _special('third', indexNumber: 3),
        _special('first', indexNumber: 1),
        _special('second', indexNumber: 2),
      ];

      expect(orderSeasonEpisodes(scrambled).map((e) => e.id), [
        'first',
        'second',
        'third',
      ]);
    });

    test('leaves air order alone when a special leads the season', () {
      final aired = [_special('airs-before'), _episode('s1e1', indexNumber: 1)];

      expect(orderSeasonEpisodes(aired).map((e) => e.id), [
        'airs-before',
        's1e1',
      ]);
    });
  });

  group('isSeasonFinale', () {
    // The season as the server lists it once an airs-after special is inlined.
    final airsAfterSeason = [
      _episode('s1e1', indexNumber: 1),
      _episode('s1e2', indexNumber: 2),
      _special('airs-after'),
    ];

    test('a trailing special does not hold back the next season', () {
      // The queue ran out on the last regular episode, so the special was
      // never queued — waiting on it would strand playback here.
      expect(isSeasonFinale(airsAfterSeason[1], airsAfterSeason), isTrue);
    });

    test('the trailing special itself finishes the season', () {
      expect(isSeasonFinale(airsAfterSeason[2], airsAfterSeason), isTrue);
    });

    test('a mid-season episode does not finish the season', () {
      expect(isSeasonFinale(airsAfterSeason[0], airsAfterSeason), isFalse);
    });

    test('a leading special never finishes the season', () {
      final airsBeforeSeason = [
        _special('airs-before'),
        _episode('s1e1', indexNumber: 1),
      ];

      expect(isSeasonFinale(airsBeforeSeason[0], airsBeforeSeason), isFalse);
      expect(isSeasonFinale(airsBeforeSeason[1], airsBeforeSeason), isTrue);
    });

    test('an absent special is not judged by its own numbering', () {
      // Special #2 would otherwise read as past the season's last episode.
      expect(
        isSeasonFinale(_special('unlisted', indexNumber: 2), [
          _episode('s1e1', indexNumber: 1),
        ]),
        isFalse,
      );
    });

    test('an absent episode falls back to the highest episode number', () {
      final season = [
        _episode('s1e1', indexNumber: 1),
        _episode('s1e2', indexNumber: 2),
      ];

      expect(isSeasonFinale(_episode('later', indexNumber: 3), season), isTrue);
      expect(
        isSeasonFinale(_episode('early', indexNumber: 1), season),
        isFalse,
      );
    });

    test('an empty season finishes nothing', () {
      expect(isSeasonFinale(_episode('s1e1', indexNumber: 1), []), isFalse);
    });
  });

  group('seasonContextParam', () {
    test('is dropped when it matches the episode own season', () {
      expect(
        seasonContextParam(
          contextSeasonId: _season1Id,
          episodeSeasonId: _season1Id,
        ),
        isNull,
      );
    });

    test('is dropped when there is no context', () {
      expect(
        seasonContextParam(contextSeasonId: null, episodeSeasonId: _season1Id),
        isNull,
      );
      expect(
        seasonContextParam(contextSeasonId: '', episodeSeasonId: _season1Id),
        isNull,
      );
    });

    test('is carried for a special listed outside its own season', () {
      expect(
        seasonContextParam(
          contextSeasonId: _season1Id,
          episodeSeasonId: _specialsId,
        ),
        _season1Id,
      );
    });
  });
}
