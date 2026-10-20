import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/dto/qbittorrent_dto.dart';
import 'package:moonfin/data/services/qbittorrent_enhanced_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const String _magnet =
    'magnet:?xt=urn:btih:C1A2B3D4E5F60718293A4B5C6D7E8F9012345678'
    '&dn=Dune.Part.Two.2024.2160p';
const String _hash = 'c1a2b3d4e5f60718293a4b5c6d7e8f9012345678';

Response<dynamic> _ok(
  dynamic data, {
  String path = '/api/v2/torrents/info',
  int statusCode = 200,
  Map<String, List<String>>? headers,
}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
      headers: headers == null ? null : Headers.fromMap(headers),
    );

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  dynamic body,
  String path = '/api/v2/torrents/info',
}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: statusCode,
            data: body,
          ),
  );
}

/// One torrent as `/api/v2/torrents/info` reports it.
Map<String, dynamic> _torrent({
  double progress = 0.0,
  double ratio = 0.0,
  String state = 'downloading',
  String category = 'radarr',
  int eta = 600,
}) =>
    <String, dynamic>{
      'hash': _hash.toUpperCase(),
      'name': 'Dune.Part.Two.2024.2160p',
      'progress': progress,
      'uploaded': 512,
      'size': 4096,
      'state': state,
      'ratio': ratio,
      'eta': eta,
      'category': category,
      'save_path': '/downloads/$category',
    };

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late _MockSecureStorage storage;
  late QBittorrentEnhancedService service;
  late BaseOptions dioOptions;

  /// Every POST the service made, as `(path, formBody)`.
  late List<({String path, Map<String, dynamic> data})> posts;

  /// Responses (or throwables) handed out by successive GETs; the last entry
  /// is reused once the queue runs dry so a fast poll loop cannot starve.
  late List<Object> getScript;
  late int getCalls;

  /// Body returned by `POST /api/v2/auth/login`.
  late String loginBody;

  setUp(() {
    dio = _MockDio();
    storage = _MockSecureStorage();
    dioOptions = BaseOptions();
    posts = [];
    getScript = [
      _ok([_torrent()])
    ];
    getCalls = 0;
    loginBody = 'Ok.';

    when(() => dio.options).thenReturn(dioOptions);
    when(() => storage.read(key: QBittorrentEnhancedService.usernameStorageKey))
        .thenAnswer((_) async => 'stored-user');
    when(() => storage.read(key: QBittorrentEnhancedService.passwordStorageKey))
        .thenAnswer((_) async => 'stored-pass');

    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      final data = Map<String, dynamic>.from(
        invocation.namedArguments[#data] as Map,
      );
      posts.add((path: path, data: data));

      if (path.endsWith('/auth/login')) {
        return _ok(
          loginBody,
          path: path,
          headers: {
            'set-cookie': ['SID=session-token-42; HttpOnly; path=/'],
          },
        );
      }
      // torrents/add answers "Ok."; torrents/delete answers an empty body.
      return _ok(path.endsWith('/torrents/add') ? 'Ok.' : '', path: path);
    });

    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async {
      final step = getScript[
          getCalls < getScript.length ? getCalls : getScript.length - 1];
      getCalls++;
      if (step is Response<dynamic>) return step;
      throw step;
    });

    service = QBittorrentEnhancedService(
      dio,
      storage,
      // The production cadence is 2s; tests would otherwise idle for it.
      pollInterval: const Duration(milliseconds: 5),
    );
  });

  tearDown(() => service.dispose());

  Future<void> initialized() =>
      service.initialize(QBittorrentEnhancedService.defaultBaseUrl);

  group('initialize', () {
    test('reads credentials, configures Dio and pins the session cookie',
        () async {
      await initialized();

      verify(() => storage.read(key: 'qbittorrent_username')).called(1);
      verify(() => storage.read(key: 'qbittorrent_password')).called(1);

      expect(service.baseUrl, 'http://localhost:8421');
      expect(service.isAuthenticated, isTrue);
      expect(dioOptions.baseUrl, 'http://localhost:8421');
      expect(dioOptions.connectTimeout, const Duration(seconds: 30));
      expect(dioOptions.receiveTimeout, const Duration(seconds: 30));
      expect(dioOptions.headers['Cookie'], 'SID=session-token-42');

      expect(posts, hasLength(1));
      expect(posts.single.path, '/api/v2/auth/login');
      expect(posts.single.data['username'], 'stored-user');
      expect(posts.single.data['password'], 'stored-pass');
    });

    test('prefers explicit credentials and trims a trailing slash', () async {
      await service.initialize(
        'http://localhost:8421/',
        'explicit-user',
        'explicit-pass',
      );

      expect(service.baseUrl, 'http://localhost:8421');
      expect(posts.single.data['username'], 'explicit-user');
      verifyNever(() => storage.read(key: any(named: 'key')));
    });

    test('throws when qBittorrent answers Fails.', () async {
      loginBody = 'Fails.';

      await expectLater(
        initialized(),
        throwsA(
          isA<QBittorrentServiceException>().having(
            (e) => e.message,
            'message',
            contains('rejected the credentials'),
          ),
        ),
      );
      expect(service.isAuthenticated, isFalse);
    });
  });

  group('addTorrent', () {
    test('returns the magnet hash and posts the category and save path',
        () async {
      await initialized();

      final hash = await service.addTorrent(
        _magnet,
        'radarr',
        '/downloads/radarr',
      );

      expect(hash, _hash);

      final add = posts.last;
      expect(add.path, '/api/v2/torrents/add');
      expect(add.data['urls'], _magnet);
      expect(add.data['category'], 'radarr');
      expect(add.data['savepath'], '/downloads/radarr');
      // Automatic torrent management would override savepath.
      expect(add.data['autoTMM'], 'false');
    });

    test('rejects an unknown category before hitting the network', () async {
      await initialized();
      posts.clear();

      await expectLater(
        service.addTorrent(_magnet, 'lidarr', '/downloads/lidarr'),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.message, 'message', contains('lidarr')),
        ),
      );
      expect(posts, isEmpty);
    });

    test('rejects a magnet without an info hash', () async {
      await initialized();

      await expectLater(
        service.addTorrent('magnet:?dn=No.Hash.Here', 'sonarr', '/downloads'),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.message, 'message', contains('info hash')),
        ),
      );
    });

    test('surfaces a qBittorrent refusal carried in the body', () async {
      await initialized();
      when(
        () => dio.post<dynamic>(
          any(that: contains('/torrents/add')),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(
          'Fails.',
          path: '/api/v2/torrents/add',
          statusCode: 415,
        ),
      );

      await expectLater(
        service.addTorrent(_magnet, 'radarr', '/downloads/radarr'),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.statusCode, 'statusCode', 415)
              .having((e) => e.message, 'message', contains('refused')),
        ),
      );
    });
  });

  group('monitorTorrent', () {
    test('polls repeatedly and yields a reading per tick', () async {
      await initialized();
      getScript = [
        _ok([_torrent(progress: 0.10)]),
        _ok([_torrent(progress: 0.55, state: 'downloading')]),
        _ok([_torrent(progress: 0.90)]),
      ];
      getCalls = 0;

      final readings =
          await service.monitorTorrent(_hash).take(3).toList();

      expect(readings.map((r) => r.progress), [0.10, 0.55, 0.90]);
      expect(readings.first.hash, _hash);
      expect(readings.first.name, 'Dune.Part.Two.2024.2160p');
      expect(readings.first.totalBytes, 4096);
      expect(readings.first.uploadedBytes, 512);
      expect(readings.first.eta, const Duration(minutes: 10));
      expect(readings.every((r) => r.shouldStopSeeding), isFalse);

      final query = verify(
        () => dio.get<dynamic>(
          '/api/v2/torrents/info',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.first as Map<String, dynamic>;
      expect(query['hashes'], _hash);

      await service.cancelMonitor(_hash);
    });

    test('stops seeding and closes the stream once ratio reaches 1.0',
        () async {
      await initialized();
      getScript = [
        _ok([_torrent(progress: 0.80)]),
        _ok([_torrent(progress: 1.0, ratio: 0.40, state: 'uploading')]),
        _ok([_torrent(progress: 1.0, ratio: 1.05, state: 'uploading', eta: 0)]),
      ];
      getCalls = 0;

      // The stream completing at all is the assertion: nothing cancels it but
      // the auto-stop.
      final readings = await service.monitorTorrent(_hash).toList();

      expect(readings, hasLength(3));
      expect(readings[1].shouldStopSeeding, isFalse,
          reason: 'complete but under ratio 1.0 must keep seeding');
      expect(readings.last.shouldStopSeeding, isTrue);

      final delete = posts.last;
      expect(delete.path, '/api/v2/torrents/delete');
      expect(delete.data['hashes'], _hash);
      expect(delete.data['deleteFiles'], 'false');

      // Timer cancelled and the hash dropped from the active map.
      expect(service.monitoredHashes, isEmpty);
    });

    test('ends monitoring when qBittorrent no longer knows the torrent',
        () async {
      await initialized();
      getScript = [
        _ok([_torrent(progress: 0.30)]),
        _ok(const <dynamic>[]),
      ];
      getCalls = 0;

      final readings = await service.monitorTorrent(_hash).toList();

      expect(readings, hasLength(1));
      expect(service.monitoredHashes, isEmpty);
      // An empty listing is not a failure, so no delete is attempted.
      expect(posts.any((p) => p.path.endsWith('/torrents/delete')), isFalse);
    });

    test('forwards a poll failure to the stream and stops polling', () async {
      await initialized();
      getScript = [_dioError(DioExceptionType.connectionError)];
      getCalls = 0;

      await expectLater(
        service.monitorTorrent(_hash),
        emitsInOrder([
          emitsError(
            isA<QBittorrentServiceException>().having(
              (e) => e.message,
              'message',
              contains('could not reach'),
            ),
          ),
          emitsDone,
        ]),
      );
      expect(service.monitoredHashes, isEmpty);
    });

    test('reuses one monitor per hash regardless of casing', () async {
      await initialized();
      getScript = [
        _ok([_torrent(progress: 0.25)])
      ];
      getCalls = 0;

      final first = service.monitorTorrent(_hash);
      final second = service.monitorTorrent(_hash.toUpperCase());

      // One controller, one timer — not two of each.
      expect(service.monitoredHashes, [_hash]);

      // Both handles observe the same broadcast controller, so a single poll
      // feeds them both.
      final readings = await Future.wait([first.first, second.first]);
      expect(readings.map((r) => r.progress), [0.25, 0.25]);
      expect(getCalls, 1);

      await service.cancelMonitor(_hash);
    });
  });

  group('listTorrents', () {
    test('parses entries and filters by category', () async {
      await initialized();
      getScript = [
        _ok([
          _torrent(category: 'sonarr'),
          _torrent(category: 'sonarr'),
        ])
      ];
      getCalls = 0;

      final torrents = await service.listTorrents(category: 'Sonarr');

      expect(torrents, hasLength(2));
      expect(torrents.first.hash, _hash);
      expect(torrents.first.category, 'sonarr');
      expect(torrents.first.savePath, '/downloads/sonarr');

      final query = verify(
        () => dio.get<dynamic>(
          '/api/v2/torrents/info',
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(query['category'], 'sonarr');
    });

    test('omits the category parameter when none is given', () async {
      await initialized();

      await service.listTorrents();

      final query = verify(
        () => dio.get<dynamic>(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(query.containsKey('category'), isFalse);
    });

    test('rejects a body that is not a list', () async {
      await initialized();
      getScript = [_ok('not json')];
      getCalls = 0;

      await expectLater(
        service.listTorrents(),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.message, 'message', contains('unexpected body')),
        ),
      );
    });
  });

  group('error handling', () {
    test('wraps a timeout in a QBittorrentServiceException', () async {
      await initialized();
      getScript = [_dioError(DioExceptionType.receiveTimeout)];
      getCalls = 0;

      await expectLater(
        service.listTorrents(),
        throwsA(
          isA<QBittorrentServiceException>().having(
            (e) => e.message,
            'message',
            allOf(contains('timed out'), contains('localhost:8421')),
          ),
        ),
      );
    });

    test('carries the status code from a bad response', () async {
      await initialized();
      getScript = [
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 404,
          body: 'Not Found',
        )
      ];
      getCalls = 0;

      await expectLater(
        service.listTorrents(),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', contains('Not Found')),
        ),
      );
    });

    test('re-authenticates once when the session cookie expired', () async {
      await initialized();
      getScript = [
        _dioError(DioExceptionType.badResponse, statusCode: 403),
        _ok([_torrent(category: 'prowlarr')]),
      ];
      getCalls = 0;
      posts.clear();

      final torrents = await service.listTorrents();

      expect(torrents, hasLength(1));
      expect(getCalls, 2, reason: 'the request is retried after re-login');
      expect(posts.single.path, '/api/v2/auth/login');
    });

    test('gives up when the retry is refused too', () async {
      await initialized();
      getScript = [_dioError(DioExceptionType.badResponse, statusCode: 403)];
      getCalls = 0;

      await expectLater(
        service.listTorrents(),
        throwsA(
          isA<QBittorrentServiceException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('stopSeeding wraps a transport failure', () async {
      await initialized();
      when(
        () => dio.post<dynamic>(
          any(that: contains('/torrents/delete')),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          DioExceptionType.connectionError,
          path: '/api/v2/torrents/delete',
        ),
      );

      await expectLater(
        service.stopSeeding(_hash),
        throwsA(
          isA<QBittorrentServiceException>().having(
            (e) => e.message,
            'message',
            contains('seeding stop'),
          ),
        ),
      );
    });
  });

  group('TorrentProgressDto', () {
    test('shouldStopSeeding needs both completion and a repaid ratio', () {
      TorrentProgressDto at(double progress, double ratio) =>
          TorrentProgressDto.fromJson(
            _torrent(progress: progress, ratio: ratio),
          );

      expect(at(0.99, 5.0).shouldStopSeeding, isFalse);
      expect(at(1.0, 0.99).shouldStopSeeding, isFalse);
      expect(at(1.0, 1.0).shouldStopSeeding, isTrue);
      expect(at(1.0, 2.5).shouldStopSeeding, isTrue);
    });

    test('normalises hash casing, clamps progress and folds a negative ratio',
        () {
      final dto = TorrentProgressDto.fromJson({
        'hash': _hash.toUpperCase(),
        'name': 'Sparse',
        'progress': 1.4,
        'ratio': -1,
        'eta': unknownEtaSeconds,
      });

      expect(dto.hash, _hash);
      expect(dto.progress, 1.0);
      expect(dto.seedRatio, 0.0);
      expect(dto.uploadedBytes, 0);
      expect(dto.totalBytes, 0);
      expect(dto.state, '');
      expect(dto.hasEta, isFalse);
    });
  });

  group('extractHash', () {
    test('reads the info hash case-insensitively and returns null otherwise',
        () {
      expect(QBittorrentEnhancedService.extractHash(_magnet), _hash);
      expect(
        QBittorrentEnhancedService.extractHash('magnet:?dn=Nothing'),
        isNull,
      );
    });
  });
}
