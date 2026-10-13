import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/jellyfin_refresh_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

Response<dynamic> _ok(
  dynamic data, {
  String path = JellyfinRefreshService.scanStatusPath,
  int statusCode = 200,
}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );

DioException _dioError(
  DioExceptionType type, {
  int? statusCode,
  dynamic body,
  String path = JellyfinRefreshService.refreshPath,
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
  late JellyfinRefreshService service;
  late BaseOptions dioOptions;

  /// Every POST the service made, as `(path, query)`.
  late List<({String path, Map<String, dynamic>? query})> posts;

  /// Response (or throwable) the next GET hands back.
  late Object getResult;

  setUp(() {
    dio = _MockDio();
    storage = _MockSecureStorage();
    dioOptions = BaseOptions();
    posts = [];
    // Stock Jellyfin's real /System/Endpoint body: no scanning flag at all.
    getResult = _ok(<String, dynamic>{'IsLocal': true, 'IsInNetwork': true});

    when(() => dio.options).thenReturn(dioOptions);
    when(() => storage.read(key: JellyfinRefreshService.accessTokenStorageKey))
        .thenAnswer((_) async => 'stored-token');

    when(
      () => dio.post<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      final query =
          invocation.namedArguments[#queryParameters] as Map<String, dynamic>?;
      posts.add((path: path, query: query));
      // Jellyfin answers 204 No Content and scans in the background.
      return _ok(null, path: path, statusCode: 204);
    });

    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async {
      final step = getResult;
      if (step is Response<dynamic>) return step;
      throw step;
    });

    service = JellyfinRefreshService(dio, storage);
  });

  Future<void> initialized() =>
      service.initialize(JellyfinRefreshService.defaultBaseUrl);

  group('initialize', () {
    test('reads the access token from secure storage and configures Dio',
        () async {
      await initialized();

      verify(() => storage.read(key: 'jellyfin_access_token')).called(1);

      expect(service.baseUrl, 'http://localhost:8096');
      expect(service.hasAccessToken, isTrue);
      expect(dioOptions.baseUrl, 'http://localhost:8096');
      expect(dioOptions.connectTimeout, const Duration(seconds: 30));
      expect(dioOptions.receiveTimeout, const Duration(seconds: 30));
    });

    test('prefers an explicit token and trims a trailing slash', () async {
      await service.initialize('http://localhost:8096/', 'explicit-token');

      expect(service.baseUrl, 'http://localhost:8096');
      expect(service.hasAccessToken, isTrue);
      verifyNever(() => storage.read(key: any(named: 'key')));

      await service.refreshLibrary();
      expect(posts.single.query?['api_key'], 'explicit-token');
    });

    test('treats unavailable secure storage as no token rather than failing',
        () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenThrow(Exception('no keystore on this platform'));

      await initialized();

      expect(service.hasAccessToken, isFalse);

      // The api_key parameter is omitted entirely, letting Jellyfin answer 401
      // rather than the app sending a literal "null" key.
      await service.refreshLibrary();
      expect(posts.single.query?.containsKey('api_key'), isFalse);
    });
  });

  group('refreshLibrary', () {
    test('POSTs /Library/Refresh with the access token', () async {
      await initialized();

      await service.refreshLibrary();

      expect(posts, hasLength(1));
      expect(posts.single.path, '/Library/Refresh');
      expect(posts.single.query?['api_key'], 'stored-token');
    });

    test('returns once the request is accepted, without waiting for the scan',
        () async {
      await initialized();

      // A 204 with no body must not be read as a failure or a parse error.
      await expectLater(service.refreshLibrary(), completes);
    });

    test('wraps a transport failure in a JellyfinRefreshException', () async {
      await initialized();
      when(
        () => dio.post<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(_dioError(DioExceptionType.connectionError));

      await expectLater(
        service.refreshLibrary(),
        throwsA(
          isA<JellyfinRefreshException>()
              .having((e) => e.message, 'message', contains('library refresh'))
              .having(
                (e) => e.message,
                'message',
                contains('could not reach http://localhost:8096'),
              )
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
    });

    test('carries the status code and detail from a bad response', () async {
      await initialized();
      when(
        () => dio.post<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        _dioError(
          DioExceptionType.badResponse,
          statusCode: 401,
          body: {'message': 'Access token is invalid'},
        ),
      );

      await expectLater(
        service.refreshLibrary(),
        throwsA(
          isA<JellyfinRefreshException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                contains('Access token is invalid'),
              ),
        ),
      );
    });

    test('reports a timeout against the configured base URL', () async {
      await initialized();
      when(
        () => dio.post<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(_dioError(DioExceptionType.receiveTimeout));

      await expectLater(
        service.refreshLibrary(),
        throwsA(
          isA<JellyfinRefreshException>().having(
            (e) => e.message,
            'message',
            allOf(contains('timed out after 30s'), contains('8096')),
          ),
        ),
      );
    });
  });

  group('isScanning', () {
    test('GETs the scan status endpoint with the access token', () async {
      await initialized();

      await service.isScanning();

      final captured = verify(
        () => dio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;

      expect(captured.first, JellyfinRefreshService.scanStatusPath);
      expect(
        (captured.last as Map<String, dynamic>)['api_key'],
        'stored-token',
      );
    });

    test('returns true when the body reports a scan in progress', () async {
      await initialized();
      getResult = _ok(<String, dynamic>{'IsScanning': true});

      expect(await service.isScanning(), isTrue);
    });

    test('returns false when the body reports no scan in progress', () async {
      await initialized();
      getResult = _ok(<String, dynamic>{'IsScanning': false});

      expect(await service.isScanning(), isFalse);
    });

    test('reads the flag under any casing and non-bool encodings', () async {
      await initialized();

      Future<bool> scanningFor(dynamic body) async {
        getResult = _ok(body);
        return service.isScanning();
      }

      expect(await scanningFor(<String, dynamic>{'isScanning': true}), isTrue);
      expect(await scanningFor(<String, dynamic>{'scanning': true}), isTrue);
      // Some proxies stringify or numify JSON booleans.
      expect(await scanningFor(<String, dynamic>{'IsScanning': 'true'}), isTrue);
      expect(await scanningFor(<String, dynamic>{'IsScanning': 1}), isTrue);
      expect(await scanningFor(<String, dynamic>{'IsScanning': 0}), isFalse);
      expect(
        await scanningFor(<String, dynamic>{'IsScanning': 'false'}),
        isFalse,
      );
      // A bare boolean body.
      expect(await scanningFor(true), isTrue);
    });

    test('reports false when the body carries no scanning flag', () async {
      await initialized();
      // This is what stock Jellyfin actually returns for /System/Endpoint.
      getResult = _ok(<String, dynamic>{'IsLocal': true, 'IsInNetwork': true});

      expect(
        await service.isScanning(),
        isFalse,
        reason: 'an unrecognised body must not be read as "scanning"',
      );
    });

    test('reports false for a body that is not a map or bool', () async {
      await initialized();
      getResult = _ok('Not Found');

      expect(await service.isScanning(), isFalse);
    });

    test('wraps a transport failure in a JellyfinRefreshException', () async {
      await initialized();
      getResult = _dioError(
        DioExceptionType.connectionError,
        path: JellyfinRefreshService.scanStatusPath,
      );

      await expectLater(
        service.isScanning(),
        throwsA(
          isA<JellyfinRefreshException>().having(
            (e) => e.message,
            'message',
            contains('scan status check'),
          ),
        ),
      );
    });

    test('carries the status code from a bad response', () async {
      await initialized();
      getResult = _dioError(
        DioExceptionType.badResponse,
        statusCode: 404,
        body: 'Not Found',
        path: JellyfinRefreshService.scanStatusPath,
      );

      await expectLater(
        service.isScanning(),
        throwsA(
          isA<JellyfinRefreshException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', contains('Not Found')),
        ),
      );
    });
  });

  group('JellyfinRefreshException', () {
    test('renders the status code in toString when there is one', () {
      expect(
        const JellyfinRefreshException('boom', statusCode: 500).toString(),
        'JellyfinRefreshException (HTTP 500): boom',
      );
      expect(
        const JellyfinRefreshException('boom').toString(),
        'JellyfinRefreshException: boom',
      );
    });

    test('keeps the underlying cause for logging', () {
      final cause = _dioError(DioExceptionType.cancel);
      expect(
        JellyfinRefreshException('boom', cause: cause).cause,
        same(cause),
      );
    });
  });
}
