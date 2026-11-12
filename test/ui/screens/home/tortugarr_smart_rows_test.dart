import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/ui/screens/home/tortugarr_smart_rows.dart';

TortugarrQueueItem _q(String id, String kind, {int? tmdb, int? tvdb, int size = 100, int left = 50, String? status = 'downloading', String name = 'X'}) =>
    TortugarrQueueItem(downloadId: id, kind: kind, tmdbId: tmdb, tvdbId: tvdb, size: size, sizeLeft: left, status: status, name: name);

void main() {
  test('episodes of one series fold into one card; imported ones are left out', () {
    final row = mapDownloadsRow([
      _q('A', 'episode', tvdb: 7, left: 25, name: 'Low Tide'),
      _q('B', 'episode', tvdb: 7, left: 75, name: 'Low Tide'),
      _q('C', 'movie', tmdb: 42, left: 10, name: 'Northbound'),
      _q('D', 'movie', tmdb: 43, status: 'completed'),
    ], title: 'On the way in', posters: {'movie:42': 'https://img/p.jpg'})!;
    expect(row.items.length, 2);
    final series = row.items.firstWhere((i) => i.rawData['Name'] == 'Low Tide');
    expect(series.rawData['Subtitle'], '2 episodes · 50 %');
    final movie = row.items.firstWhere((i) => i.rawData['Name'] == 'Northbound');
    expect(movie.rawData['Subtitle'], '90 %');
    expect(movie.rawData['PosterPath'], 'https://img/p.jpg');
    expect(movie.id, '42');
  });

  test('nothing downloading means no row', () {
    expect(mapDownloadsRow([_q('A', 'movie', tmdb: 1, status: 'completed')], title: 't'), isNull);
    expect(mapDownloadsRow(const [], title: 't'), isNull);
  });

  test('queued and importing read as words, not 0 % / 100 %', () {
    final row = mapDownloadsRow([
      _q('A', 'movie', tmdb: 1, status: 'queued', left: 100),
      _q('B', 'movie', tmdb: 2, status: 'importing', left: 0),
    ], title: 't')!;
    expect(row.items.map((i) => i.rawData['Subtitle']), ['Queued', 'Ready in a moment']);
  });

  test('Fits tonight keeps films up to 1 h 45 that have a runtime', () {
    int ticks(int minutes) => Duration(minutes: minutes).inMicroseconds * 10;
    final row = mapTonightRow([
      {'Id': 'a', 'RunTimeTicks': ticks(95)},
      {'Id': 'b', 'RunTimeTicks': ticks(150)},
      {'Id': 'c'},
      {'Id': 'd', 'RunTimeTicks': ticks(105)},
    ], title: 'Fits tonight', serverId: 's')!;
    expect(row.items.map((i) => i.id), ['a', 'd']);
  });

  test('Fits tonight mixes films and next-up episodes', () {
    int ticks(int minutes) => Duration(minutes: minutes).inMicroseconds * 10;
    final mixed = mixTonight(
      movies: [{'Id': 'm1', 'RunTimeTicks': ticks(90)}, {'Id': 'm2', 'RunTimeTicks': ticks(95)}],
      episodes: [{'Id': 'e1', 'RunTimeTicks': ticks(45)}],
    );
    final row = mapTonightRow(mixed, title: 't', serverId: 's')!;
    expect(row.items.map((i) => i.id), ['m1', 'e1', 'm2']);
  });
}
