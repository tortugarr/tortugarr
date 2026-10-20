import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/prowlarr_search_client.dart';
import 'package:moonfin/data/services/download/release_video_guard.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/seerr/seerr_release_filter.dart';

ProwlarrRelease _release(String title, {int gb = 4}) => ProwlarrRelease(
      guid: 'magnet:?xt=urn:btih:${'a' * 40}',
      title: title,
      size: gb * 1024 * 1024 * 1024,
      indexerId: 1,
      indexer: 'test',
      seeders: 10,
      protocol: 'torrent',
    );

void main() {
  group('release picker filter', () {
    bool ok(String t) =>
        ProwlarrSearchClient.isValidMedia(_release(t), 'movie');

    test('keeps real releases', () {
      expect(ok('Kraken.2026.NORWEGiAN.1080p.iT.WEB-DL.H.264-NORViNE'), isTrue);
      expect(ok('Movie 2024 2160p UHD BluRay REMUX HDR DTS-HD MA'), isTrue);
      expect(ok('Old Movie 1998 DVDRip XviD'), isTrue);
      expect(ok('Movie.2024.720p.WEBRip.x264'), isTrue);
      // Early hotel/in-flight copies: lower quality, often hardcoded subs.
      expect(ok('Movie 2026 HDRip XviD HC'), isTrue);
    });

    test('drops cinema copies and screeners', () {
      expect(ok('Runner 2026 HDCAM x264'), isFalse);
      expect(ok('Runner.2026.1080p.HD-TS.x264'), isFalse);
      expect(ok('Runner 2026 TELESYNC 720p'), isFalse);
      expect(ok('Runner 2026 DVDSCR'), isFalse);
      expect(ok('Runner.2026.CAM.1080p'), isFalse);
    });

    test('drops executables and releases without a quality', () {
      expect(ok('South Park S29E02 1080p WEB H264-MeGusta exe'), isFalse);
      expect(ok('Some Movie 2026 Full Movie'), isFalse);
    });
  });

  test('reads the publish date of a release', () {
    final r = ProwlarrRelease.fromJson({
      'guid': 'g',
      'title': 'The Odyssey (2026) 1080p WEBRip x265 10bit 5.1-LAMA',
      'publishDate': '2026-08-28T10:00:00Z',
    });
    expect(r.publishDate, DateTime.utc(2026, 8, 28, 10));
  });

  test('adult releases only get the safety checks', () {
    bool ok(String t, {int gb = 1}) =>
        ProwlarrSearchClient.isValidMedia(_release(t, gb: gb), 'xxx');
    expect(ok('Some Studio Scene Name'), isTrue);
    expect(ok('Some Studio Scene Name 1080p'), isTrue);
    expect(ok('Some Studio Scene Name exe'), isFalse);
    expect(ok('Clip', gb: 0), isTrue); // unknown size is not held against it
  });

  test('keyword search ranks titles by how many words they contain', () {
    final words = ProwlarrSearchClient.keywordsOf('Red Car, night');
    expect(words, ['red', 'car', 'night']);
    expect(ProwlarrSearchClient.matchCount('A.Red.Car.At.Night.1080p', words), 3);
    expect(ProwlarrSearchClient.matchCount('Red Sky', words), 1);
  });

  group('video guard', () {
    test('reads hex and base32 magnet hashes', () {
      final hex = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01';
      expect(ReleaseVideoGuard.magnetHash('magnet:?xt=urn:btih:$hex&dn=x'),
          hex.toLowerCase());
      // base32 of 20 zero bytes
      expect(
        ReleaseVideoGuard.magnetHash('magnet:?xt=urn:btih:${'A' * 32}'),
        '0' * 40,
      );
      expect(ReleaseVideoGuard.magnetHash('https://example.com/x'), isNull);
    });

    test('needs a real-size video file', () {
      const mb = 1024 * 1024;
      expect(
        ReleaseVideoGuard.hasVideo(
            [(name: 'Show.S01E01.mkv', size: 900 * mb)]),
        isTrue,
      );
      expect(
        ReleaseVideoGuard.hasVideo([
          (name: 'South Park S29E02 1080p WEB H264-MeGusta.exe', size: 1000 * mb),
          (name: 'sample.mkv', size: 10 * mb),
        ]),
        isFalse,
      );
    });
  });

  group('trending filter', () {
    final today = DateTime(2026, 10, 1);

    SeerrDiscoverItem movie(int id, String date) =>
        SeerrDiscoverItem(id: id, mediaType: 'movie', title: 'm$id', releaseDate: date);

    Map<String, dynamic> details(List<(int, String)> types) => {
          'releases': {
            'results': [
              {
                'iso_3166_1': 'US',
                'release_dates': [
                  for (final (t, d) in types) {'type': t, 'release_date': '${d}T00:00:00.000Z'},
                ],
              },
            ],
          },
        };

    setUp(SeerrReleaseFilter.clearCache);

    test('keeps digital/disc releases, drops cinema-only and unreleased', () async {
      final byId = {
        1: details([(3, '2026-09-10'), (4, '2026-09-29')]), // digital out
        2: details([(3, '2026-09-07'), (4, '2026-10-13')]), // digital later
        3: details([(3, '2026-09-28')]), // cinema only
        5: details([]), // old, no data
      };
      final filter = SeerrReleaseFilter(
        (id) async => byId[id]!,
        now: () => today,
      );
      final page = await filter.apply(SeerrDiscoverPage(results: [
        movie(1, '2026-09-10'),
        movie(2, '2026-09-07'),
        movie(3, '2026-09-28'),
        movie(4, '2026-11-20'), // not premiered
        movie(5, '2019-05-01'),
        const SeerrDiscoverItem(id: 6, mediaType: 'tv', name: 'aired', firstAirDate: '2026-08-16'),
        const SeerrDiscoverItem(id: 7, mediaType: 'tv', name: 'soon', firstAirDate: '2026-12-01'),
      ]));
      expect(page.results.map((i) => i.id), [1, 5, 6]);
    });

    test('a failing details call falls back to the age rule', () async {
      final filter = SeerrReleaseFilter(
        (id) async => throw Exception('offline'),
        now: () => today,
      );
      final page = await filter.apply(SeerrDiscoverPage(results: [
        movie(1, '2026-09-10'),
        movie(2, '2020-01-01'),
      ]));
      expect(page.results.map((i) => i.id), [2]);
    });
  });
}
