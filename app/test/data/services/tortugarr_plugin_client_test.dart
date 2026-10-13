import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/tortugarr/download_features.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/ui/widgets/download_now/plugin_download_flow.dart';
import 'package:server_core/server_core.dart';

class _MockClient extends Mock implements MediaServerClient {}

/// Answers each request from [routes] (`'GET /Capabilities'` → status+body)
/// and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, List<(int, Object?)>> routes;
  final List<RequestOptions> sent = [];
  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    sent.add(options);
    final key = '${options.method} ${options.uri.path.replaceFirst('/Tortugarr/v1', '')}';
    final queue = routes[key];
    if (queue == null || queue.isEmpty) return ResponseBody.fromString('', 404);
    final (status, body) = queue.length > 1 ? queue.removeAt(0) : queue.first;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TortugarrPluginClient _plugin(_FakeAdapter adapter) {
  final client = _MockClient();
  when(() => client.baseUrl).thenReturn('http://lab:8096');
  when(() => client.accessToken).thenReturn('tok');
  when(() => client.deviceInfo).thenReturn(const DeviceInfo(
    id: 'd', name: 'test', appName: 'Tortugarr', appVersion: '1'));
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;
  return TortugarrPluginClient(dio: dio, client: client);
}

void main() {
  test('capabilities: features from the plugin, sent with the Jellyfin session', () async {
    final adapter = _FakeAdapter({
      'GET /Capabilities': [
        (200, {
          'apiVersion': 1,
          'isAdmin': true,
          'features': {'downloadNow': true, 'videoCheck': true, 'adult': false},
        }),
      ],
    });
    final caps = await _plugin(adapter).capabilities();
    expect(caps.isAdmin, isTrue);
    expect(caps.downloadNow, isTrue);
    expect(caps.videoCheck, isTrue);
    expect(caps.adult, isFalse);
    expect(caps.subtitles, isFalse);
    expect(adapter.sent.single.uri.toString(), 'http://lab:8096/Tortugarr/v1/Capabilities');
    expect(adapter.sent.single.headers['Authorization'], contains('Token="tok"'));
  });

  test('capabilities: a server without the plugin turns everything off', () async {
    final caps = await _plugin(_FakeAdapter({})).capabilities();
    expect(caps.downloadNow, isFalse);
    expect(caps.isAdmin, isFalse);
  });

  test('search starts a job and polls it until done', () async {
    final adapter = _FakeAdapter({
      'POST /Searches': [
        (202, {'searchId': 'abc', 'pollAfterSeconds': 0}),
      ],
      'GET /Searches/abc': [
        (200, {'status': 'running', 'elapsedSeconds': 1}),
        (200, {
          'status': 'done',
          'result': {
            'title': 'Sintel',
            'year': 2010,
            'arrId': 2,
            'droppedEarly': 0,
            'releases': [
              {
                'guid': 'g1',
                'indexerId': 3,
                'indexer': 'Lab',
                'title': 'Sintel.2010.1080p.WEB-DL',
                'size': 1200000000,
                'seeders': 9,
                'leechers': 1,
                'protocol': 'torrent',
                'publishDate': '2026-10-01T00:00:00Z',
                'approved': false,
                'recommended': false,
                'rejections': ['Outside the quality profile'],
              },
            ],
          },
        }),
      ],
    });
    final result = await _plugin(adapter).search({'type': 'movie', 'tmdbId': 45745});
    expect(result.arrId, 2);
    expect(result.releases, hasLength(1));
    final r = result.releases.single;
    expect(r.approved, isFalse);
    expect(r.rejections, ['Outside the quality profile']);
    expect((adapter.sent.first.data as Map), {'type': 'movie', 'tmdbId': 45745});

    final picker = asPickerRelease(r);
    expect(picker.guid, 'g1');
    expect(picker.indexerId, 3);
    expect(picker.tierLabel, '1080p');
  });

  test('a failed search and an error body become TortugarrPluginException', () async {
    final failed = _FakeAdapter({
      'POST /Searches': [
        (202, {'searchId': 'x', 'pollAfterSeconds': 0}),
      ],
      'GET /Searches/x': [
        (200, {'status': 'failed', 'error': {'code': 'upstream_failed', 'message': 'Radarr is down'}}),
      ],
    });
    await expectLater(
      _plugin(failed).search({'type': 'movie', 'tmdbId': 1}),
      throwsA(isA<TortugarrPluginException>()
          .having((e) => e.code, 'code', 'upstream_failed')
          .having((e) => e.message, 'message', 'Radarr is down')),
    );

    final notAdmin = _FakeAdapter({
      'POST /Grab': [
        (403, {'error': {'code': 'not_admin', 'message': 'Only administrators can download.'}}),
      ],
    });
    await expectLater(
      _plugin(notAdmin).grab(
        type: 'movie',
        arrId: 2,
        release: const TortugarrRelease(
            guid: 'g', indexerId: 1, indexer: '', title: 't', size: 0, seeders: 0, leechers: 0),
      ),
      throwsA(isA<TortugarrPluginException>().having((e) => e.status, 'status', 403)),
    );
  });

  test('grab sends force only for a soft-rejected pick', () async {
    final adapter = _FakeAdapter({
      'POST /Grab': [
        (200, {'downloadId': 'H', 'title': 't', 'queued': true}),
      ],
    });
    const release = TortugarrRelease(
        guid: 'g', indexerId: 1, indexer: '', title: 't', size: 0, seeders: 0, leechers: 0);
    final plugin = _plugin(adapter);
    final grab = await plugin.grab(type: 'movie', arrId: 2, release: release);
    expect(grab.queued, isTrue);
    expect(grab.downloadId, 'H');
    expect((adapter.sent.last.data as Map), isNot(contains('force')));
    await plugin.grab(type: 'movie', arrId: 2, release: release, force: true);
    expect((adapter.sent.last.data as Map)['force'], isTrue);
  });

  test('video check maps the plugin action', () async {
    final adapter = _FakeAdapter({
      'POST /Downloads/H/Check': [
        (200, {'hasVideo': null, 'action': 'wait'}),
        (200, {
          'hasVideo': false,
          'files': [
            {'name': 'setup.exe', 'size': 1},
          ],
          'action': 'removed',
        }),
      ],
    });
    final check = await _plugin(adapter).watchVideo('H', every: Duration.zero);
    expect(check.action, TortugarrVideoAction.removed);
    expect(check.fileNames, ['setup.exe']);
  });

  test('deleteTitle: what was deleted, and the plugin codes on refusal', () async {
    final ok = _FakeAdapter({
      'DELETE /Library/item1': [
        (200, {'deleted': 'movie', 'title': 'Sita', 'files': 1, 'seerr': 'cleared'}),
      ],
    });
    expect(await _plugin(ok).deleteTitle('item1'), 'movie');

    final mismatch = _FakeAdapter({
      'DELETE /Library/item2': [
        (409, {'error': {'code': 'file_mismatch', 'message': 'Not the same file'}}),
      ],
    });
    await expectLater(
      _plugin(mismatch).deleteTitle('item2'),
      throwsA(isA<TortugarrPluginException>()
          .having((e) => e.code, 'code', 'file_mismatch')
          .having((e) => e.status, 'status', 409)),
    );
  });

  test('capabilities: deleteTitles is read from the plugin', () async {
    final caps = await _plugin(_FakeAdapter({
      'GET /Capabilities': [
        (200, {'features': {'deleteTitles': true}}),
      ],
    })).capabilities();
    expect(caps.deleteTitles, isTrue);
    expect(caps.downloadNow, isFalse);
  });

  test('already_in_client carries progress and gets its own message', () async {
    final adapter = _FakeAdapter({
      'POST /Grab': [
        (409, {
          'error': {
            'code': 'already_in_client',
            'message': 'qBittorrent already has this release',
            'downloadId': 'H',
            'category': 'radarr',
            'progress': 0.42,
            'state': 'downloading',
          },
        }),
      ],
    });
    try {
      await _plugin(adapter).grab(
        type: 'movie',
        arrId: 2,
        release: const TortugarrRelease(
            guid: 'g', indexerId: 1, indexer: '', title: 't', size: 0, seeders: 0, leechers: 0),
      );
      fail('expected an exception');
    } on TortugarrPluginException catch (e) {
      expect(e.code, 'already_in_client');
      expect(e.progress, 0.42);
      expect(explainPluginError(e), 'Already downloading (42 %)');
      expect(
        explainPluginError(const TortugarrPluginException(409, 'already_in_client', '', {'progress': 1})),
        startsWith('Already downloaded'),
      );
    }
  });

  test('no_indexers explains with the plugin reason', () {
    expect(
      explainPluginError(const TortugarrPluginException(null, 'no_indexers', '1 disabled until 05:21 UTC')),
      'No search sources are active on the server (1 disabled until 05:21 UTC). '
      'Check your indexers in Prowlarr.',
    );
  });

  test('subtitles: state, candidates and download map to the dialog models', () async {
    final adapter = _FakeAdapter({
      'GET /Subtitles/State': [
        (200, {'have': ['en'], 'missing': ['no']}),
      ],
      'GET /Subtitles': [
        (200, {
          'candidates': [
            {
              'id': 'sub1',
              'provider': 'opensubtitles',
              'language': 'no',
              'hearingImpaired': true,
              'forced': false,
              'originalFormat': false,
              'score': 90,
              'releaseInfo': ['Sintel.2010.1080p', 'WEB'],
            },
          ],
        }),
      ],
      'POST /Subtitles': [(204, null)],
    });
    final plugin = _plugin(adapter);
    const target = <String, Object>{'type': 'movie', 'tmdbId': 45745};

    final state = await plugin.subtitleState(target);
    expect(state.have, {'en'});
    expect(state.missing, {'no'});
    expect(adapter.sent.last.uri.queryParameters, {'type': 'movie', 'tmdbId': '45745'});

    final list = await plugin.subtitleCandidates(target);
    expect(list.single.subtitleId, 'sub1');
    expect(list.single.hearingImpaired, 'True');
    expect(list.single.release, 'Sintel.2010.1080p · WEB');

    await plugin.downloadSubtitle(target, list.single);
    final body = adapter.sent.last.data as Map;
    expect(body['id'], 'sub1');
    expect(body['hearingImpaired'], isTrue);
    expect(body['tmdbId'], 45745);
  });

  test('series status, season switch and space routes', () async {
    final adapter = _FakeAdapter({
      'GET /Series/81189': [
        (200, {
          'inSonarr': true,
          'arrId': 3,
          'title': 'Pioneer One',
          'seasonMonitoring': {'0': false, '1': true},
          'queuedEpisodeIds': [293],
          'seasons': [],
        }),
      ],
      'GET /Series/1': [
        (200, {'inSonarr': false}),
      ],
      'PUT /Series/81189/Seasons/1': [
        (200, {'arrId': 3, 'seasonNumber': 1, 'monitored': true, 'seasonMonitoring': {'1': true}, 'searchQueued': true}),
      ],
      'GET /Space/Check': [
        (200, {'freeBytes': 4, 'pendingBytes': 1, 'enough': false}),
      ],
    });
    final plugin = _plugin(adapter);
    expect((await plugin.seriesStatus(81189))!['arrId'], 3);
    expect(await plugin.seriesStatus(1), isNull);
    final put = await plugin.setSeasonMonitoring(81189, 1, monitored: true, search: true);
    expect(put.seasons, {1: true});
    expect(put.searchQueued, isTrue);
    expect(adapter.sent.last.data, {'monitored': true, 'search': true});
    expect((await plugin.spaceCheck(100))['freeBytes'], 4);
    expect(adapter.sent.last.uri.queryParameters, {'bytes': '100'});
    expect(TortugarrPluginClient.seasonMonitoringOf({'0': false, '2': true, 'x': true}), {0: false, 2: true});
  });

  test('dropped reasons explain an empty search', () {
    final sdOnly = TortugarrSearchResult.fromJson({
      'arrId': 1,
      'releases': [],
      'dropped': {'below the quality minimum': 3},
    });
    expect(sdOnly.found, 3);
    expect(sdOnly.onlySdDropped, isTrue);
    expect(nothingFoundMessage(sdOnly), startsWith('3 found, all SD'));

    final mixed = TortugarrSearchResult.fromJson({
      'arrId': 1,
      'releases': [],
      'dropped': {'below the quality minimum': 20, 'too small': 1, 'junk words': 0},
    });
    expect(mixed.onlySdDropped, isFalse);
    expect(nothingFoundMessage(mixed), '21 found, none usable: 20 below the quality minimum, 1 too small');

    expect(nothingFoundMessage(TortugarrSearchResult.fromJson({'arrId': 1})), 'No releases found');
    final down = TortugarrSearchResult.fromJson({
      'arrId': 1,
      'unavailableIndexers': ['Internet Archive'],
    });
    expect(down.unavailableIndexers, ['Internet Archive']);
    expect(nothingFoundMessage(down),
        'No releases found. Internet Archive unavailable right now: results from the other indexers only.');
  });

  test('without the public build define nothing goes through the plugin', () {
    expect(DownloadFeatures.viaPlugin, isFalse);
    expect(DownloadFeatures.capabilities.value.downloadNow, isFalse);
  });
}
