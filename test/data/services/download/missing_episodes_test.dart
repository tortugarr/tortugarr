import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';
import 'package:moonfin/data/services/download/sonarr_client.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

AggregatedItem _jf(int season, int episode, {int? end}) => AggregatedItem(
      id: 'jf-$season-$episode',
      serverId: 'srv',
      rawData: {
        'Id': 'jf-$season-$episode',
        'Type': 'Episode',
        'ParentIndexNumber': season,
        'IndexNumber': episode,
        'IndexNumberEnd': ?end,
      },
    );

SonarrEpisode _ep(
  int id,
  int season,
  int episode, {
  DateTime? aired,
  bool hasFile = false,
}) =>
    SonarrEpisode(
      id: id,
      seasonNumber: season,
      episodeNumber: episode,
      monitored: false,
      title: 'Episode $episode',
      hasFile: hasFile,
      airDateUtc: aired,
    );

SonarrRelease _rel(
  String title, {
  int seeders = 10,
  int size = 2 * 1024 * 1024 * 1024,
  bool approved = true,
  List<String> rejections = const [],
  bool fullSeason = false,
}) =>
    SonarrRelease(
      guid: 'magnet:?xt=urn:btih:${title.hashCode.abs()}',
      indexerId: 1,
      indexer: 'Test (Prowlarr)',
      title: title,
      size: size,
      seeders: seeders,
      protocol: 'torrent',
      quality: 'WEBDL-1080p',
      approved: approved,
      rejections: rejections,
      fullSeason: fullSeason,
      downloadUrl: 'http://prowlarr/1/download',
    );

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  final now = DateTime.utc(2026, 10, 3);
  final past = DateTime.utc(2026, 7, 1);
  final future = DateTime.utc(2026, 11, 1);

  group('mergeSeason', () {
    final status = SeriesEpisodeStatus(
      sonarrSeriesId: 46,
      title: 'House of the Dragon',
      episodes: [
        for (var e = 1; e <= 8; e++) _ep(100 + e, 3, e, aired: past),
        _ep(109, 3, 9, aired: future),
        _ep(110, 3, 10),
        _ep(201, 2, 1, aired: past),
      ],
      queuedEpisodeIds: {103},
    );

    test('puts placeholders between the episodes on disk, in order', () {
      final rows = MissingEpisodes.mergeSeason(
        present: [_jf(3, 7), _jf(3, 8)],
        status: status,
        season: 3,
        now: now,
      );
      expect(rows.length, 10);
      expect(
        [for (final r in rows) r.present != null ? 'P' : 'M'].join(),
        'MMMMMMPPMM',
      );
      expect(rows[6].present!.indexNumber, 7);
      expect(rows.first.missing!.number, 1);
    });

    test('states: missing, downloading, unaired, no air date', () {
      final rows = MissingEpisodes.mergeSeason(
        present: const [],
        status: status,
        season: 3,
        now: now,
      );
      MissingEpisodeState stateOf(int n) =>
          rows.firstWhere((r) => r.missing!.number == n).missing!.state;
      expect(stateOf(1), MissingEpisodeState.missing);
      expect(stateOf(3), MissingEpisodeState.downloading);
      expect(stateOf(9), MissingEpisodeState.unaired);
      expect(stateOf(10), MissingEpisodeState.unaired);
      expect(rows.firstWhere((r) => r.missing!.number == 9).missing!.canDownload,
          isFalse);
    });

    test('a file Sonarr has but Jellyfin does not show is "importing"', () {
      final s = SeriesEpisodeStatus(
        sonarrSeriesId: 1,
        title: 'x',
        episodes: [_ep(1, 1, 1, aired: past, hasFile: true)],
      );
      final rows =
          MissingEpisodes.mergeSeason(present: const [], status: s, season: 1, now: now);
      expect(rows.single.missing!.state, MissingEpisodeState.importing);
    });

    test('a multi-episode file covers every episode in its range', () {
      final rows = MissingEpisodes.mergeSeason(
        present: [_jf(3, 1, end: 2)],
        status: status,
        season: 3,
        now: now,
      );
      expect(rows.first.present, isNotNull);
      expect(rows.where((r) => r.missing?.number == 2), isEmpty);
    });

    test('other seasons stay out', () {
      final rows = MissingEpisodes.mergeSeason(
        present: [_jf(2, 1)],
        status: status,
        season: 2,
        now: now,
      );
      expect(rows.length, 1);
      expect(rows.single.present, isNotNull);
    });
  });

  group('missingSeasons', () {
    final status = SeriesEpisodeStatus(
      sonarrSeriesId: 1,
      title: 'x',
      episodes: [_ep(1, 0, 1), _ep(2, 1, 1), _ep(3, 2, 1), _ep(4, 3, 1)],
    );

    test('lists seasons the library has none of, without specials', () {
      expect(
        MissingEpisodes.missingSeasons(presentSeasons: [3], status: status),
        [1, 2],
      );
    });

    test('includes specials when the library shows specials', () {
      expect(
        MissingEpisodes.missingSeasons(presentSeasons: [0, 3], status: status),
        [1, 2],
      );
      final noSpecials = SeriesEpisodeStatus(
        sonarrSeriesId: 1,
        title: 'x',
        episodes: [_ep(1, 0, 1), _ep(1, 0, 2)],
      );
      expect(
        MissingEpisodes.missingSeasons(presentSeasons: [0], status: noSpecials),
        isEmpty,
      );
    });
  });

  group('season pack', () {
    List<SeasonEntry> missing(int n, {MissingEpisodeState state = MissingEpisodeState.missing}) => [
          for (var i = 1; i <= n; i++)
            SeasonEntry.missing(MissingEpisode(_ep(i, 1, i), state)),
        ];

    test('offered from three downloadable episodes', () {
      expect(MissingEpisodes.offerSeasonPack(missing(2)), isFalse);
      expect(MissingEpisodes.offerSeasonPack(missing(3)), isTrue);
    });

    test('unaired or downloading episodes do not count', () {
      expect(
        MissingEpisodes.offerSeasonPack(
          missing(5, state: MissingEpisodeState.unaired),
        ),
        isFalse,
      );
      expect(
        MissingEpisodes.offerSeasonPack([
          ...missing(2),
          SeasonEntry.present(_jf(1, 9)),
          ...missing(3, state: MissingEpisodeState.downloading),
        ]),
        isFalse,
      );
    });
  });

  group('pickable', () {
    test('drops CAM/TS, executables, dead and blocked releases', () {
      final options = MissingEpisodes.pickable([
        _rel('Show.S01E01.1080p.WEB.H264-GRP'),
        _rel('Show.S01E01.HDCAM.x264'),
        _rel('Show.S01E01.1080p.WEB.H264.exe'),
        _rel('Show.S01E01.1080p.WEB.H264-DEAD',
            approved: false,
            rejections: ['Not enough seeders: 0. Minimum seeders: 1']),
        _rel('Show.S01E01.1080p.WEB.H264-BLK',
            approved: false, rejections: ['Release is blocklisted']),
        _rel('Show.S01E01.1080p.WEB.H264-TINY', size: 50 * 1024 * 1024),
      ]);
      expect([for (final o in options) o.release.title],
          ['Show.S01E01.1080p.WEB.H264-GRP']);
    });

    test('recommended first, then resolution and seeders; soft ones dimmed', () {
      final options = MissingEpisodes.pickable([
        _rel('Show.S01E01.720p.WEB.H264-A', seeders: 900),
        _rel('Show.S01E01.2160p.WEB.H265-B',
            approved: false, rejections: ['WEBDL-2160p is not wanted in profile']),
        _rel('Show.S01E01.1080p.WEB.H264-C', seeders: 5),
        _rel('Show.S01E01.1080p.WEB.H264-D', seeders: 50),
      ]);
      expect([for (final o in options) o.release.title.split('-').last],
          ['D', 'C', 'A', 'B']);
      expect(options.last.recommended, isFalse);
      expect(options.last.softReason, 'Utenfor kvalitetsprofilen');
    });

    test('season search lists packs first', () {
      final options = MissingEpisodes.pickable([
        _rel('Show.S01E01.1080p.WEB.H264-E', seeders: 999),
        _rel('Show.S01.1080p.WEB.H264-PACK', seeders: 3, fullSeason: true),
      ], seasonPack: true);
      expect(options.first.release.fullSeason, isTrue);
    });

    test('episodes already on disk: packs still count, single files go', () {
      const existing = 'Existing file meets cutoff: HDTV-1080p';
      final options = MissingEpisodes.pickable([
        _rel('Show.S01E07.1080p.WEB.H264-HAVE',
            approved: false, rejections: [existing]),
        _rel('Show.S01.1080p.WEB.H264-PACK',
            approved: false, fullSeason: true, rejections: [existing]),
        _rel('Show.S01.2160p.WEB.H265-BIG',
            approved: false,
            fullSeason: true,
            rejections: ['WEBDL-2160p is not wanted in profile', existing]),
      ], seasonPack: true);
      expect([for (final o in options) o.release.title.split('-').last],
          ['PACK', 'BIG']);
      expect(options.first.recommended, isTrue);
      expect(options.last.softReason, 'Utenfor kvalitetsprofilen');
    });
  });

  test('SonarrRelease parses Sonarr 4 interactive search results', () {
    final r = SonarrRelease.fromJson({
      'guid': 'magnet:?xt=urn:btih:abc',
      'indexerId': 7,
      'indexer': '1337x (Prowlarr)',
      'title': 'House.of.the.Dragon.S03E03.1080p.WEB.h264-ETHEL',
      'size': 4330000000,
      'seeders': 3500,
      'leechers': 20,
      'protocol': 'torrent',
      'quality': {
        'quality': {'id': 3, 'name': 'WEBDL-1080p'},
      },
      'approved': false,
      'fullSeason': false,
      'rejections': ['WEBDL-2160p is not wanted in profile'],
      'publishDate': '2026-07-06T03:00:00Z',
    });
    expect(r.indexerId, 7);
    expect(r.quality, 'WEBDL-1080p');
    expect(r.rejections.single, contains('not wanted'));
    expect(r.publishDate, DateTime.utc(2026, 7, 6, 3));
  });

  test('SonarrEpisode reads hasFile and the air date', () {
    final e = SonarrEpisode.fromJson({
      'id': 4541,
      'seasonNumber': 3,
      'episodeNumber': 3,
      'hasFile': false,
      'monitored': true,
      'airDateUtc': '2026-07-06T01:00:00Z',
      'title': 'Rhaenyra Triumphant',
    });
    expect(e.hasFile, isFalse);
    expect(e.airDateUtc, DateTime.utc(2026, 7, 6, 1));
  });
}
