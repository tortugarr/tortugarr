import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/dto/qbittorrent_dto.dart';

/// Raised for every failure inside [QBittorrentEnhancedService].
///
/// The service never returns an empty list or a silent no-op to paper over a
/// network, auth or parse error — callers either get data or this exception.
class QBittorrentServiceException implements Exception {
  final String message;

  /// HTTP status when the failure came from a server response.
  final int? statusCode;

  /// Underlying [DioException] or parse error, kept for logging.
  final Object? cause;

  const QBittorrentServiceException(
    this.message, {
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'QBittorrentServiceException$code: $message';
  }
}

/// Client for the qBittorrent Web API with progress polling and auto-seeding
/// control.
///
/// qBittorrent is reached
/// through the Caddy proxy on [defaultBaseUrl]. Unlike Jellyseerr this API is
/// session based: [initialize] posts the credentials to `/api/v2/auth/login`
/// once at startup and the resulting `SID` cookie is replayed on every later
/// request.
///
/// [monitorTorrent] polls `/api/v2/torrents/info` every [pollInterval] and
/// removes a torrent (keeping its files) as soon as it is both fully
/// downloaded and has repaid its share ratio, so finished downloads stop
/// eating upload bandwidth without any user action.
class QBittorrentEnhancedService {
  /// Caddy proxy in front of the native Windows qBittorrent on 8420.
  static const String defaultBaseUrl = 'http://localhost:8421';

  /// Secure-storage key holding the qBittorrent username.
  static const String usernameStorageKey = 'qbittorrent_username';

  /// Secure-storage key holding the qBittorrent password.
  static const String passwordStorageKey = 'qbittorrent_password';

  static const Duration requestTimeout = Duration(seconds: 30);

  /// How often [monitorTorrent] asks qBittorrent for a progress update.
  static const Duration defaultPollInterval = Duration(seconds: 2);

  /// Categories the download stack routes through qBittorrent.
  static const Set<String> supportedCategories = {
    'radarr',
    'sonarr',
    'prowlarr',
  };

  static const String _apiPrefix = '/api/v2';

  /// Matches the info hash inside a magnet URI's `xt` parameter.
  static final RegExp _magnetHashPattern =
      RegExp(r'xt=urn:btih:([a-z0-9]+)', caseSensitive: false);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  /// Poll cadence for [monitorTorrent]; overridable so tests need not wait.
  final Duration pollInterval;

  /// One controller per hash currently being monitored.
  final Map<String, StreamController<TorrentProgressDto>> _monitors = {};

  /// The polling timer backing each entry of [_monitors].
  final Map<String, Timer> _timers = {};

  String _baseUrl = defaultBaseUrl;
  String _username = '';
  String _password = '';
  bool _isAuthenticated = false;

  QBittorrentEnhancedService(
    this._dio,
    this._secureStorage, {
    this.pollInterval = defaultPollInterval,
  });

  /// Base URL currently in use, without a trailing slash.
  String get baseUrl => _baseUrl;

  /// True once a login round-trip has succeeded.
  bool get isAuthenticated => _isAuthenticated;

  /// Hashes with a live polling timer.
  Iterable<String> get monitoredHashes => _monitors.keys;

  /// Points the client at [baseUrl], loads credentials and logs in.
  ///
  /// [username] and [password] override secure storage; when either is null or
  /// blank the matching value is read from [usernameStorageKey] /
  /// [passwordStorageKey]. Login happens here, once — not per request.
  ///
  /// Throws [QBittorrentServiceException] when qBittorrent rejects the
  /// credentials or is unreachable.
  Future<void> initialize([
    String baseUrl = defaultBaseUrl,
    String? username,
    String? password,
  ]) async {
    _baseUrl = _normalizeBaseUrl(baseUrl);

    _username = (username ?? '').isNotEmpty
        ? username!
        : await _readSecret(usernameStorageKey);
    _password = (password ?? '').isNotEmpty
        ? password!
        : await _readSecret(passwordStorageKey);

    final options = _dio.options;
    options.baseUrl = _baseUrl;
    options.connectTimeout = requestTimeout;
    options.receiveTimeout = requestTimeout;

    await _login();
  }

  /// Hands [magnetUri] to qBittorrent under [category], saved into [savePath].
  ///
  /// [category] must be one of [supportedCategories]; [savePath] is an
  /// absolute path such as `/downloads/radarr`. Returns the info hash parsed
  /// out of the magnet, which is the handle every other method takes.
  ///
  /// Throws [QBittorrentServiceException] when the category is unknown, the
  /// magnet carries no info hash, or qBittorrent refuses the torrent.
  Future<String> addTorrent(
    String magnetUri,
    String category,
    String savePath,
  ) async {
    final normalizedCategory = category.trim().toLowerCase();
    if (!supportedCategories.contains(normalizedCategory)) {
      throw QBittorrentServiceException(
        "Unsupported category '$category' — expected one of "
        '${supportedCategories.join(', ')}',
      );
    }

    final hash = extractHash(magnetUri);
    if (hash == null) {
      throw const QBittorrentServiceException(
        'Could not read an info hash out of the magnet URI '
        '(no xt=urn:btih: parameter)',
      );
    }

    final response = await _post(
      '$_apiPrefix/torrents/add',
      body: {
        'urls': magnetUri,
        'category': normalizedCategory,
        'savepath': savePath,
        // Automatic torrent management would override savepath with the
        // category's default directory.
        'autoTMM': 'false',
      },
      description: 'add of $hash',
    );

    _assertOk(response, 'add of $hash');
    return hash;
  }

  /// Streams progress for [hash], polling every [pollInterval].
  ///
  /// The first reading is fetched immediately rather than after one interval.
  /// When a reading reports [TorrentProgressDto.shouldStopSeeding] the service
  /// calls [stopSeeding] and then closes the stream and cancels the timer.
  /// A poll failure is forwarded to the stream as a
  /// [QBittorrentServiceException] and also ends monitoring, so a caller sees
  /// one terminal outcome instead of an endlessly retrying timer.
  ///
  /// Calling this twice for the same hash returns the same broadcast stream
  /// rather than starting a second timer.
  Stream<TorrentProgressDto> monitorTorrent(String hash) {
    final key = hash.trim().toLowerCase();

    final existing = _monitors[key];
    if (existing != null && !existing.isClosed) return existing.stream;

    final controller = StreamController<TorrentProgressDto>.broadcast();
    _monitors[key] = controller;
    _timers[key] = Timer.periodic(pollInterval, (_) => _poll(key));

    // Don't make the UI wait a full interval for its first frame of data.
    unawaited(_poll(key));

    return controller.stream;
  }

  /// Removes [hash] from qBittorrent while leaving the downloaded files.
  ///
  /// Throws [QBittorrentServiceException] on any transport or API failure.
  Future<void> stopSeeding(String hash) async {
    final key = hash.trim().toLowerCase();

    final response = await _post(
      '$_apiPrefix/torrents/delete',
      body: {'hashes': key, 'deleteFiles': 'false'},
      description: 'seeding stop for $key',
    );

    _assertOk(response, 'seeding stop for $key');
  }

  /// Lists the torrents qBittorrent knows about, optionally within [category].
  ///
  /// Throws [QBittorrentServiceException] on any transport or parse failure.
  Future<List<QBittorrentTorrentDto>> listTorrents({String? category}) async {
    final normalizedCategory = category?.trim().toLowerCase();
    final description = normalizedCategory == null || normalizedCategory.isEmpty
        ? 'torrent listing'
        : "torrent listing for '$normalizedCategory'";

    final raw = await _fetchTorrentInfo(
      queryParameters: {
        if (normalizedCategory != null && normalizedCategory.isNotEmpty)
          'category': normalizedCategory,
      },
      description: description,
    );

    try {
      return raw
          .map(QBittorrentTorrentDto.fromJson)
          .toList(growable: false);
    } catch (error) {
      throw QBittorrentServiceException(
        'Could not parse the $description from qBittorrent',
        cause: error,
      );
    }
  }

  /// Stops polling [hash] and closes its stream without touching qBittorrent.
  Future<void> cancelMonitor(String hash) =>
      _finishMonitor(hash.trim().toLowerCase());

  /// Cancels every timer and closes every open progress stream.
  Future<void> dispose() async {
    for (final hash in _monitors.keys.toList(growable: false)) {
      await _finishMonitor(hash);
    }
  }

  /// Pulls the info hash out of a magnet URI, or null when there is none.
  static String? extractHash(String magnetUri) {
    final match = _magnetHashPattern.firstMatch(magnetUri);
    return match?.group(1)?.toLowerCase();
  }

  // --- monitoring internals ----------------------------------------------

  Future<void> _poll(String hash) async {
    final controller = _monitors[hash];
    if (controller == null || controller.isClosed) return;

    List<Map<String, dynamic>> raw;
    try {
      raw = await _fetchTorrentInfo(
        queryParameters: {'hashes': hash},
        description: 'progress poll for $hash',
      );
    } on QBittorrentServiceException catch (error) {
      controller.addError(error);
      await _finishMonitor(hash);
      return;
    }

    // Re-check: stopSeeding or dispose may have run while the poll was in
    // flight.
    if (controller.isClosed) return;

    if (raw.isEmpty) {
      // qBittorrent no longer knows this torrent — someone removed it, or a
      // previous stopSeeding landed. Nothing left to report.
      await _finishMonitor(hash);
      return;
    }

    late final TorrentProgressDto progress;
    try {
      progress = TorrentProgressDto.fromJson(raw.first);
    } catch (error) {
      controller.addError(
        QBittorrentServiceException(
          'Could not parse the progress poll for $hash',
          cause: error,
        ),
      );
      await _finishMonitor(hash);
      return;
    }

    controller.add(progress);

    if (!progress.shouldStopSeeding) return;

    try {
      await stopSeeding(hash);
    } on QBittorrentServiceException catch (error) {
      if (!controller.isClosed) controller.addError(error);
    }
    await _finishMonitor(hash);
  }

  Future<void> _finishMonitor(String hash) async {
    _timers.remove(hash)?.cancel();
    final controller = _monitors.remove(hash);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  // --- transport internals -----------------------------------------------

  /// Posts [body] as `application/x-www-form-urlencoded`, which is the only
  /// encoding the qBittorrent Web API accepts.
  Future<Response<dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    required String description,
  }) {
    return _withSession(
      () => _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // qBittorrent rejects cross-origin writes unless the Referer matches.
          headers: {'Referer': _baseUrl},
        ),
      ),
      description,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTorrentInfo({
    required Map<String, dynamic> queryParameters,
    required String description,
  }) async {
    final response = await _withSession(
      () => _dio.get<dynamic>(
        '$_apiPrefix/torrents/info',
        queryParameters: queryParameters,
      ),
      description,
    );

    final data = response.data;
    if (data is! List) {
      throw QBittorrentServiceException(
        'qBittorrent returned an unexpected body for $description: '
        '${data.runtimeType}',
        statusCode: response.statusCode,
      );
    }

    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Runs [request], re-authenticating once if the session cookie expired.
  ///
  /// qBittorrent answers 403 for an unknown or expired `SID`. A monitor can
  /// run for hours, so a single transparent re-login is worth more than
  /// surfacing a spurious auth error to the UI.
  Future<Response<dynamic>> _withSession(
    Future<Response<dynamic>> Function() request,
    String description,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode != 403 || !_isAuthenticated) {
        throw _wrap(error, description);
      }

      _isAuthenticated = false;
      await _login();

      try {
        return await request();
      } on DioException catch (retryError) {
        throw _wrap(retryError, description);
      }
    }
  }

  /// Authenticates and stores the `SID` cookie on the shared Dio client.
  Future<void> _login() async {
    late final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_apiPrefix/auth/login',
        data: {'username': _username, 'password': _password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Referer': _baseUrl},
        ),
      );
    } on DioException catch (error) {
      throw _wrap(error, 'login');
    }

    // qBittorrent answers 200 with the literal body "Ok." or "Fails.".
    final body = response.data?.toString().trim().toLowerCase() ?? '';
    if (body.startsWith('fails')) {
      throw QBittorrentServiceException(
        "qBittorrent rejected the credentials for '$_username'",
        statusCode: response.statusCode,
      );
    }

    _storeSessionCookie(response);
    _isAuthenticated = true;
  }

  /// Copies the `SID` cookie out of the login response onto the Dio defaults.
  ///
  /// Done by hand rather than through a cookie jar so the session survives on
  /// every platform, including web builds where the jar is a no-op.
  void _storeSessionCookie(Response<dynamic> response) {
    final setCookie = response.headers.map['set-cookie'];
    if (setCookie == null) return;

    for (final entry in setCookie) {
      final sid = entry.split(';').first.trim();
      if (sid.toUpperCase().startsWith('SID=')) {
        _dio.options.headers['Cookie'] = sid;
        return;
      }
    }
  }

  Future<String> _readSecret(String key) async {
    try {
      return await _secureStorage.read(key: key) ?? '';
    } catch (_) {
      // Secure storage is unavailable on some desktop/TV targets. Treat that
      // as "no credential" and let the login surface the resulting 403.
      return '';
    }
  }

  /// qBittorrent signals write failures in the body, not the status code.
  void _assertOk(Response<dynamic> response, String description) {
    final body = response.data?.toString().trim() ?? '';
    if (body.isEmpty || body.toLowerCase().startsWith('ok')) return;

    throw QBittorrentServiceException(
      'qBittorrent refused the $description: $body',
      statusCode: response.statusCode,
    );
  }

  QBittorrentServiceException _wrap(DioException error, String description) {
    return QBittorrentServiceException(
      'qBittorrent $description failed: ${_reason(error)}',
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }

  String _reason(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'timed out after ${requestTimeout.inSeconds}s '
            'contacting $_baseUrl';
      case DioExceptionType.connectionError:
        return 'could not reach $_baseUrl';
      case DioExceptionType.badCertificate:
        return 'the TLS certificate for $_baseUrl was rejected';
      case DioExceptionType.cancel:
        return 'the request was cancelled';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final body = error.response?.data;
        final detail = body is String && body.trim().isNotEmpty
            ? body.trim()
            : null;
        return 'server responded ${status ?? 'with an error'}'
            '${detail == null ? '' : ' — $detail'}';
      case DioExceptionType.unknown:
        return error.message ?? 'unknown transport error';
    }
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
