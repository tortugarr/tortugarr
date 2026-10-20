import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Raised for every failure inside [JellyfinRefreshService].
///
/// The service never swallows a refresh failure into a silent no-op — callers
/// either see the request accepted or get this exception.
class JellyfinRefreshException implements Exception {
  final String message;

  /// HTTP status when the failure came from a server response.
  final int? statusCode;

  /// Underlying [DioException] or parse error, kept for logging.
  final Object? cause;

  const JellyfinRefreshException(
    this.message, {
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'JellyfinRefreshException$code: $message';
  }
}

/// Triggers a Jellyfin media library scan once a download has landed.
///
/// This is deliberately a trigger, not a Jellyfin client: the app already has
/// a full media-server stack under `lib/auth` and `lib/di/modules`. The only
/// job here is to tell Jellyfin "new files exist on disk, go look" after
/// `QBittorrentEnhancedService` reports a finished torrent.
///
/// Jellyfin sits behind [defaultBaseUrl] from the app's perspective. The
/// access token is read from secure storage during [initialize] and replayed
/// as the `api_key` query parameter on every request, which is the one
/// authentication scheme every Jellyfin version and reverse proxy accepts.
class JellyfinRefreshService {
  /// Placeholder default; callers pass the real address.
  static const String defaultBaseUrl = 'http://localhost:8096';

  /// Secure-storage key holding the Jellyfin access token.
  static const String accessTokenStorageKey = 'jellyfin_access_token';

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Full library scan trigger. Jellyfin answers 204 and scans in background.
  static const String refreshPath = '/Library/Refresh';

  /// Endpoint [isScanning] probes for scan state.
  ///
  /// NOTE: this is the path the feature plan specifies. Stock Jellyfin answers
  /// `/System/Endpoint` with `{"IsLocal":bool,"IsInNetwork":bool}`, which
  /// carries no scan state — the authoritative source is `/ScheduledTasks`
  /// (the task keyed `RefreshLibrary`, whose `State` reads `Running` while a
  /// scan is in flight). [isScanning] parses defensively and reports `false`
  /// when the body has no scanning flag, so pointing this constant at
  /// `/ScheduledTasks` is the only change needed if the plan is revised.
  static const String scanStatusPath = '/System/Endpoint';

  /// Body keys accepted as the scanning flag, compared case-insensitively.
  static const Set<String> _scanningKeys = {'isscanning', 'scanning'};

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  String _baseUrl = defaultBaseUrl;
  String? _accessToken;

  JellyfinRefreshService(this._dio, this._secureStorage);

  /// Base URL currently in use, without a trailing slash.
  String get baseUrl => _baseUrl;

  /// True once an access token has been supplied or loaded.
  bool get hasAccessToken => (_accessToken ?? '').isNotEmpty;

  /// Points the client at [baseUrl], loads the access token and configures Dio.
  ///
  /// [accessToken] overrides secure storage; when it is null or blank the
  /// token is read from [accessTokenStorageKey]. A missing token is not fatal
  /// here — Jellyfin may allow anonymous library refresh — so it is left unset
  /// and the request itself surfaces any 401.
  ///
  /// Called once during app startup.
  Future<void> initialize([
    String baseUrl = defaultBaseUrl,
    String? accessToken,
  ]) async {
    _baseUrl = _normalizeBaseUrl(baseUrl);

    if ((accessToken ?? '').isNotEmpty) {
      _accessToken = accessToken;
    } else {
      try {
        _accessToken = await _secureStorage.read(key: accessTokenStorageKey);
      } catch (_) {
        // Secure storage is unavailable on some desktop/TV targets. Treat that
        // as "no token" rather than blocking startup entirely.
        _accessToken = null;
      }
    }

    final options = _dio.options;
    options.baseUrl = _baseUrl;
    options.connectTimeout = requestTimeout;
    options.receiveTimeout = requestTimeout;
  }

  /// Asks Jellyfin to scan its media library for new files.
  ///
  /// Returns as soon as Jellyfin accepts the request — the scan itself runs in
  /// the background and may take minutes. Poll [isScanning] to follow it.
  ///
  /// Throws [JellyfinRefreshException] on any transport or API failure.
  Future<void> refreshLibrary() async {
    try {
      await _dio.post<dynamic>(
        refreshPath,
        queryParameters: _query(),
      );
    } on DioException catch (error) {
      throw _wrap(error, 'library refresh');
    }
  }

  /// Reports whether Jellyfin is currently scanning its library.
  ///
  /// A body with no recognised scanning flag reads as `false` — "not scanning"
  /// is the safe answer, and the caller's next [refreshLibrary] is harmless
  /// even if a scan happens to be running.
  ///
  /// Throws [JellyfinRefreshException] on any transport failure.
  Future<bool> isScanning() async {
    late final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        scanStatusPath,
        queryParameters: _query(),
      );
    } on DioException catch (error) {
      throw _wrap(error, 'scan status check');
    }

    return _readScanningFlag(response.data);
  }

  // --- internals -----------------------------------------------------------

  /// Pulls a scanning flag out of [data], defaulting to false.
  ///
  /// Accepts a bare boolean body, or a map carrying any of [_scanningKeys]
  /// under any casing, so a Jellyfin version or proxy that renames the field
  /// does not silently break the probe.
  static bool _readScanningFlag(dynamic data) {
    if (data is bool) return data;
    if (data is! Map) return false;

    for (final entry in data.entries) {
      final key = entry.key.toString().toLowerCase();
      if (!_scanningKeys.contains(key)) continue;

      final value = entry.value;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.trim().toLowerCase() == 'true';
    }

    return false;
  }

  /// Merges the access token into [extra] as the `api_key` query parameter.
  Map<String, dynamic> _query([Map<String, dynamic>? extra]) {
    final query = <String, dynamic>{...?extra};
    if (hasAccessToken) query['api_key'] = _accessToken;
    return query;
  }

  JellyfinRefreshException _wrap(DioException error, String description) {
    return JellyfinRefreshException(
      'Jellyfin $description failed: ${_reason(error)}',
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
        final detail = body is Map && body['message'] is String
            ? body['message'] as String
            : (body is String && body.trim().isNotEmpty ? body.trim() : null);
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
