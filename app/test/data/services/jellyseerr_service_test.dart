import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/dto/jellyseerr_dto.dart';
import 'package:moonfin/data/services/jellyseerr_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Response<dynamic> _ok(dynamic data, {String path = '/api/v1/search'}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data,
    );

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  dynamic body,
  String path = '/api/v1/search',
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

void main() {
  late _MockDio dio;
  late _MockSecureStorage storage;
  late JellyseerrService service;
  late BaseOptions dioOptions;

  setUp(() async {
    dio = _MockDio();
    storage = _MockSecureStorage();
    dioOptions = BaseOptions();

    when(() => dio.options).thenReturn(dioOptions);
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'test-api-key');

    service = JellyseerrService(dio, storage);
    await service.initialize(JellyseerrService.defaultBaseUrl);
  });

  void stubGet(dynamic Function() answer) {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => answer() as Response<dynamic>);
  }

  void stubGetThrows(Object error) {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(error);
  }

  group('initialize', () {
    test('points Dio at the server, sets 30s timeouts and the API key header',
        () async {
      verify(() => storage.read(key: 'jellyseerr_api_key')).called(1);

      expect(service.baseUrl, 'http://localhost:5055');
      expect(service.hasApiKey, isTrue);
      expect(dioOptions.baseUrl, 'http://localhost:5055');
      expect(dioOptions.connectTimeout, const Duration(seconds: 30));
      expect(dioOptions.receiveTimeout, const Duration(seconds: 30));
      expect(dioOptions.headers['X-Api-Key'], 'test-api-key');
    });

    test('trims a trailing slash and survives a missing API key', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      final bare = JellyseerrService(dio, storage);
      await bare.initialize('http://localhost:5055/');

      expect(bare.baseUrl, 'http://localhost:5055');
      expect(bare.hasApiKey, isFalse);
    });
  });

  group('search', () {
    test('parses movie and tv results from the results envelope', () async {
      stubGet(() => _ok({
            'results': [
              {
                'id': 603,
                'mediaType': 'movie',
                'title': 'The Matrix',
                'releaseDate': '1999-03-30',
                'overview': 'A hacker learns the truth.',
                'posterPath': '/matrix.jpg',
                'voteAverage': 8.2,
              },
              {
                'id': 1396,
                'mediaType': 'tv',
                'name': 'Breaking Bad',
                'firstAirDate': '2008-01-20',
                'overview': 'A chemistry teacher turns to crime.',
                'posterPath': '/bb.jpg',
                'voteAverage': 8,
              },
            ],
          }));

      final results = await service.search('matrix');

      expect(results, hasLength(2));
      expect(results.first.id, 603);
      expect(results.first.title, 'The Matrix');
      expect(results.first.releaseYear, '1999');
      expect(results.first.mediaType, 'movie');
      expect(results.first.voteAverage, 8.2);

      // A series uses name/firstAirDate, and an int vote widens to double.
      expect(results.last.title, 'Breaking Bad');
      expect(results.last.releaseYear, '2008');
      expect(results.last.voteAverage, 8.0);
    });

    test('sends the query in the path and api_key as a parameter', () async {
      stubGet(() => _ok({'results': const []}));

      await service.search('  dune  ');

      final captured = verify(
        () => dio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;

      expect(captured[0], '/api/v1/search?query=dune&page=1');
      final query = captured[1] as Map<String, dynamic>;
      expect(query.containsKey('query'), isFalse);
      expect(query['api_key'], 'test-api-key');
    });

    test('percent-encodes spaces and apostrophes so Seerr accepts them',
        () async {
      stubGet(() => _ok({'results': const []}));

      await service.search("The Terminator's");

      final captured = verify(
        () => dio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;

      expect(captured[0], '/api/v1/search?query=The%20Terminator%27s&page=1');
    });

    test('falls back to defaults for missing fields', () async {
      stubGet(() => _ok({
            'results': [
              {'id': 42},
            ],
          }));

      final results = await service.search('sparse');

      expect(results.single.id, 42);
      expect(results.single.title, '');
      expect(results.single.releaseYear, '');
      expect(results.single.description, '');
      expect(results.single.posterPath, '');
      expect(results.single.voteAverage, 0.0);
    });

    test('returns an empty list for a blank query without calling Dio',
        () async {
      expect(await service.search('   '), isEmpty);
      verifyNever(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });

    test('wraps a DioException in a JellyseerrServiceException', () async {
      stubGetThrows(_dioError(DioExceptionType.connectionTimeout));

      await expectLater(
        service.search('matrix'),
        throwsA(
          isA<JellyseerrServiceException>().having(
            (e) => e.message,
            'message',
            allOf(contains('timed out'), contains('localhost:5055')),
          ),
        ),
      );
    });

    test('carries the status code and server message from a bad response',
        () async {
      stubGetThrows(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 401,
          body: {'message': 'Unauthorized'},
        ),
      );

      await expectLater(
        service.search('matrix'),
        throwsA(
          isA<JellyseerrServiceException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('Unauthorized')),
        ),
      );
    });

    test('rejects a body that is not a list', () async {
      stubGet(() => _ok('not json'));

      await expectLater(
        service.search('matrix'),
        throwsA(isA<JellyseerrServiceException>()),
      );
    });
  });

  group('getAvailableFiles', () {
    test('parses releases and derives resolution from the filename', () async {
      stubGet(() => _ok([
            {
              'path': 'The.Matrix.1999.2160p.UHD.BluRay.mkv',
              'size': 20 * 1024 * 1024,
              'seeders': 50,
              'leechers': 3,
            },
            {
              'path': 'The.Matrix.1999.1080p.WEB-DL.mkv',
              'sizeInMb': 4200,
              'seeders': 120,
              'leechers': 8,
            },
            {
              'path': 'The.Matrix.1999.DVDRip.avi',
              'seeders': 2,
            },
          ]));

      final files = await service.getAvailableFiles(603, 'movie');

      expect(files, hasLength(3));
      expect(files[0].resolution, '2160p');
      expect(files[0].sizeInMb, 20);
      expect(files[0].seeders, 50);
      expect(files[0].leechers, 3);

      expect(files[1].resolution, '1080p');
      expect(files[1].sizeInMb, 4200);

      // Anything without a 4K/1080p tag falls into the 720p bucket.
      expect(files[2].resolution, '720p');
      expect(files[2].sizeInMb, 0);
      expect(files[2].leechers, 0);
    });

    test('builds the tv path and accepts a files envelope', () async {
      stubGet(() => _ok({
            'files': [
              {'path': 'Breaking.Bad.S01.4K.mkv', 'seeders': 9},
            ],
          }));

      final files = await service.getAvailableFiles(1396, 'TV');

      expect(files.single.resolution, '2160p');

      final path = verify(
        () => dio.get<dynamic>(
          captureAny(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).captured.single;
      expect(path, '/api/v1/tv/1396/files');
    });

    test('rejects an unsupported mediaType before hitting the network',
        () async {
      await expectLater(
        service.getAvailableFiles(1, 'anime'),
        throwsA(
          isA<JellyseerrServiceException>()
              .having((e) => e.message, 'message', contains('anime')),
        ),
      );
      verifyNever(
        () => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });

    test('wraps a connection error', () async {
      stubGetThrows(_dioError(DioExceptionType.connectionError));

      await expectLater(
        service.getAvailableFiles(603, 'movie'),
        throwsA(
          isA<JellyseerrServiceException>().having(
            (e) => e.message,
            'message',
            contains('could not reach'),
          ),
        ),
      );
    });
  });

  group('submitRequest', () {
    void stubPost(dynamic Function() answer) {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => answer() as Response<dynamic>);
    }

    test('returns the confirmation and posts the selected files', () async {
      stubPost(() => _ok(
            {
              'id': 77,
              'status': 1,
              'createdAt': '2026-09-08T10:15:00.000Z',
              'media': {'tmdbId': 603},
            },
            path: '/api/v1/request',
          ));

      final result = await service.submitRequest(
        603,
        'movie',
        const ['The.Matrix.1999.1080p.WEB-DL.mkv'],
      );

      expect(result.requestId, 77);
      expect(result.mediaId, 603);
      expect(result.status, '1');
      expect(result.requestedAt, DateTime.utc(2026, 9, 8, 10, 15));

      final captured = verify(
        () => dio.post<dynamic>(
          captureAny(),
          data: captureAny(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).captured;

      expect(captured[0], '/api/v1/request');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['mediaId'], 603);
      expect(body['mediaType'], 'movie');
      expect(body['files'], ['The.Matrix.1999.1080p.WEB-DL.mkv']);
    });

    test('falls back to epoch zero when Jellyseerr omits createdAt', () async {
      stubPost(() => _ok({'id': 5, 'status': 'pending'},
          path: '/api/v1/request'));

      final result = await service.submitRequest(1396, 'tv', const []);

      expect(result.requestId, 5);
      expect(result.status, 'pending');
      expect(result.requestedAt.millisecondsSinceEpoch, 0);
    });

    test('wraps a duplicate-request rejection', () async {
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 409,
          body: {'message': 'Request already exists'},
          path: '/api/v1/request',
        ),
      );

      await expectLater(
        service.submitRequest(603, 'movie', const []),
        throwsA(
          isA<JellyseerrServiceException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                contains('Request already exists'),
              ),
        ),
      );
    });

    test('rejects a non-object confirmation body', () async {
      stubPost(() => _ok('accepted', path: '/api/v1/request'));

      await expectLater(
        service.submitRequest(603, 'movie', const []),
        throwsA(isA<JellyseerrServiceException>()),
      );
    });
  });

  group('JellyseerrFileOptionDto.resolutionFromPath', () {
    test('maps quality tags case-insensitively', () {
      expect(
        JellyseerrFileOptionDto.resolutionFromPath('Show.S01E01.2160p.mkv'),
        '2160p',
      );
      expect(
        JellyseerrFileOptionDto.resolutionFromPath('Show.S01E01.4k.mkv'),
        '2160p',
      );
      expect(
        JellyseerrFileOptionDto.resolutionFromPath('Show.S01E01.1080P.mkv'),
        '1080p',
      );
      expect(
        JellyseerrFileOptionDto.resolutionFromPath('Show.S01E01.mkv'),
        '720p',
      );
    });
  });
}
