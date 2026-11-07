import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/tortugarr/series_requests.dart';

/// 2026-11-07: Seerr › Requests showed the movies downloaded in the app,
/// never the series (series file no Seerr request).
void main() {
  Map<String, dynamic> row(int tvdb, String at,
          {int? tmdb, bool downloading = false, String user = 'u1', List<int> seasons = const [1]}) =>
      {
        'tvdbId': tvdb,
        'tmdbId': tmdb ?? tvdb + 1000,
        'title': 'Show $tvdb',
        'userId': user,
        'userName': 'Odd',
        'at': at,
        'downloads': 2,
        'seasons': seasons,
        'downloading': downloading,
      };

  SeerrRequest movie(int id, String at) => SeerrRequest(
        id: id,
        status: SeerrRequest.statusApproved,
        type: 'movie',
        createdAt: at,
        updatedAt: at,
        media: SeerrMedia(id: id, tmdbId: id, mediaType: 'movie'),
      );

  test('a plugin row becomes a read-only series card that opens the series', () {
    final cards = seriesRequestsFromPlugin([row(10, '2026-11-07T10:00:00Z', seasons: [1, 2])]);
    expect(cards, hasLength(1));
    final c = cards.single;
    expect(isPluginSeriesRequest(c), isTrue, reason: 'negative id: no approve/decline');
    expect(c.type, 'tv');
    expect(c.media!.tmdbId, 1010);
    expect(c.media!.tvdbId, 10);
    expect(c.media!.name, 'Show 10');
    expect(c.requestedBy!.bestName, 'Odd');
    expect(c.seasons!.map((s) => s.seasonNumber), [1, 2]);
    expect(c.media!.status, 5, reason: 'done downloading: available');
  });

  test('a series still downloading reads Processing', () {
    final c = seriesRequestsFromPlugin([row(10, '2026-11-07T10:00:00Z', downloading: true)]).single;
    expect(c.media!.status, 3);
    expect(c.media!.downloadStatus, isNotEmpty);
  });

  test('rows without a TMDB id are left out; two users get two cards', () {
    final cards = seriesRequestsFromPlugin([
      row(10, '2026-11-07T10:00:00Z'),
      {...row(20, '2026-11-07T10:00:00Z'), 'tmdbId': null},
      row(10, '2026-11-07T09:00:00Z', user: 'u2'),
    ]);
    expect(cards, hasLength(2));
    expect(cards[0].id, isNot(cards[1].id));
  });

  test('status filters keep the matching series', () {
    final cards = seriesRequestsFromPlugin([
      row(10, '2026-11-07T10:00:00Z', downloading: true),
      row(20, '2026-11-07T09:00:00Z'),
    ]);
    expect(seriesForStatus(cards, null), hasLength(2));
    expect(seriesForStatus(cards, 'approved'), hasLength(2));
    expect(seriesForStatus(cards, 'processing').single.media!.tvdbId, 10);
    expect(seriesForStatus(cards, 'available').single.media!.tvdbId, 20);
    expect(seriesForStatus(cards, 'pending'), isEmpty);
    expect(seriesForStatus(cards, 'failed'), isEmpty);
  });

  group('merge', () {
    final series = seriesRequestsFromPlugin([
      row(10, '2026-11-07T12:00:00Z'),
      row(20, '2026-11-01T12:00:00Z'),
    ]);
    final seerr = [movie(1, '2026-11-07T13:00:00Z'), movie(2, '2026-11-05T13:00:00Z')];

    test('newest first, movies and series together', () {
      final all = mergeSeriesRequests(
          seerr: seerr, series: series, seerrHasMore: false, sort: 'added', kind: SeerrRequestKind.all);
      expect(all.map((r) => r.id), [1, series[0].id, 2, series[1].id]);
    });

    test('while Seerr has more pages, older series wait for them', () {
      final page = mergeSeriesRequests(
          seerr: seerr, series: series, seerrHasMore: true, sort: 'added', kind: SeerrRequestKind.all);
      expect(page.map((r) => r.id), [1, series[0].id, 2]);
    });

    test('movies only and series only', () {
      final movies = mergeSeriesRequests(
          seerr: seerr, series: series, seerrHasMore: false, sort: 'added', kind: SeerrRequestKind.movies);
      expect(movies.map((r) => r.type).toSet(), {'movie'});
      final shows = mergeSeriesRequests(
          seerr: seerr, series: series, seerrHasMore: false, sort: 'added', kind: SeerrRequestKind.series);
      expect(shows, hasLength(2));
      expect(shows.map((r) => r.type).toSet(), {'tv'});
    });

    test('without the plugin the list is Seerr\'s, unchanged', () {
      final plain = mergeSeriesRequests(
          seerr: seerr, series: const [], seerrHasMore: true, sort: 'added', kind: SeerrRequestKind.all);
      expect(plain.map((r) => r.id), [1, 2]);
    });
  });
}
