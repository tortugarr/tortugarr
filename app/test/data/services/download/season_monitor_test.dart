import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';
import 'package:moonfin/data/services/download/sonarr_client.dart';

/// Sonarr as American Horror Story was after the cleanup: every season off.
Map<String, dynamic> _ahs() => {
      'id': 55,
      'title': 'American Horror Story',
      'monitored': false,
      'monitorNewItems': 'none',
      'qualityProfileId': 4,
      'seasons': [
        for (final n in [0, 1, 2, 13]) {'seasonNumber': n, 'monitored': false},
      ],
    };

/// Records every request and answers like Sonarr.
class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  final List<Object?> bodies = [];
  final int putStatus;
  Map<String, dynamic> series = _ahs();

  _Recorder({this.putStatus = 202});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    bodies.add(options.data);
    var status = 200;
    Object body = <Object>[];
    final path = options.uri.path;
    if (path.endsWith('/api/v3/series/55') && options.method == 'GET') {
      body = series;
    } else if (path.endsWith('/api/v3/series/55') && options.method == 'PUT') {
      status = putStatus;
      if (putStatus < 300) series = Map<String, dynamic>.from(options.data as Map);
      body = series;
    } else if (path.endsWith('/api/v3/command')) {
      status = 201;
      body = {'id': 1};
    } else if (path.endsWith('/api/v3/episode/monitor')) {
      status = 202;
      body = <Object>[];
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> to(String suffix, String method) =>
      calls.where((c) => c.uri.path.endsWith(suffix) && c.method == method);
}

SonarrEpisode _ep(int id, int season, int number, String? aired) => SonarrEpisode.fromJson({
      'id': id,
      'seasonNumber': season,
      'episodeNumber': number,
      'monitored': false,
      'hasFile': false,
      'airDateUtc': aired,
    });

SeriesEpisodeStatus _status() => SeriesEpisodeStatus(
      sonarrSeriesId: 55,
      title: 'American Horror Story',
      episodes: [
        _ep(1301, 13, 1, '2026-09-10T02:00:00Z'),
        _ep(1304, 13, 4, '2026-10-01T02:00:00Z'),
        _ep(1305, 13, 5, '2026-10-08T02:00:00Z'),
        _ep(201, 2, 1, '2012-10-17T02:00:00Z'),
      ],
      seasonMonitored: const {0: false, 1: false, 2: false, 13: false},
    );

(SonarrClient, _Recorder) _client({int putStatus = 202}) {
  final rec = _Recorder(putStatus: putStatus);
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = rec;
  return (SonarrClient(dio: dio), rec);
}

void main() {
  final now = DateTime.utc(2026, 10, 3, 12);

  test('the payload changes only the chosen season, and series.monitored follows', () {
    final on = SonarrClient.seasonMonitorPayload(_ahs(), 13, true);
    expect(
      SonarrClient.seasonMonitoredOf(on['seasons']),
      {0: false, 1: false, 2: false, 13: true},
    );
    expect(on['monitored'], true);
    expect(on['monitorNewItems'], 'none');
    expect(on['qualityProfileId'], 4, reason: 'everything else is kept');

    final off = SonarrClient.seasonMonitorPayload(on, 13, false);
    expect(SonarrClient.seasonMonitoredOf(off['seasons']).values, everyElement(false));
    expect(off['monitored'], false);
  });

  test('aired episodes of a season are the ones that stay unmonitored on "Nei"', () {
    expect(MissingEpisodes.airedEpisodeIds(_status().episodes, 13, now), [1301, 1304]);
  });

  test('season on with "Nei" sends no search and unmonitors the aired episodes', () async {
    final (client, rec) = _client();
    final result = await MissingEpisodesService(sonarr: client)
        .setSeasonMonitoring(_status(), 13, on: true, searchNow: false, now: now);
    expect(result[13], true);
    expect(rec.to('/api/v3/command', 'POST'), isEmpty);
    final unmonitor = rec.to('/api/v3/episode/monitor', 'PUT').single;
    expect(unmonitor.data, {'episodeIds': [1301, 1304], 'monitored': false});
  });

  test('season on with "Ja" searches exactly that season', () async {
    final (client, rec) = _client();
    await MissingEpisodesService(sonarr: client)
        .setSeasonMonitoring(_status(), 13, on: true, searchNow: true, now: now);
    final cmd = rec.to('/api/v3/command', 'POST').single;
    expect(cmd.data, {'name': 'SeasonSearch', 'seriesId': 55, 'seasonNumber': 13});
    expect(rec.to('/api/v3/episode/monitor', 'PUT'), isEmpty);
  });

  test('season off sends no search', () async {
    final (client, rec) = _client();
    final result = await MissingEpisodesService(sonarr: client)
        .setSeasonMonitoring(_status(), 13, on: false, now: now);
    expect(result[13], false);
    expect(rec.to('/api/v3/command', 'POST'), isEmpty);
  });

  test('a refused change throws so the toggle can flip back', () async {
    final (client, _) = _client(putStatus: 400);
    expect(
      MissingEpisodesService(sonarr: client)
          .setSeasonMonitoring(_status(), 13, on: true, now: now),
      throwsA(isA<MissingEpisodesException>()),
    );
  });

  test('series parse their per-season monitoring', () {
    final s = SonarrSeries.fromJson(_ahs());
    expect(s.seasonMonitored, {0: false, 1: false, 2: false, 13: false});
  });
}
