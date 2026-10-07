import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/dto/jellyseerr_dto.dart';
import 'seerr/seerr_query_encoding.dart';

/// Raised for every failure inside [JellyseerrService].
///
/// The service never returns an empty list to paper over a network or parse
/// error — callers either get data or this exception.
class JellyseerrServiceException implements Exception {
  final String message;

  /// HTTP status when the failure came from a server response.
  final int? statusCode;

  /// Underlying [DioException] or parse error, kept for logging.
  final Object? cause;

  const JellyseerrServiceException(
    this.message, {
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'JellyseerrServiceException$code: $message';
  }
}

/// Client for the Jellyseerr instance that fronts content discovery.
///
/// Jellyseerr is reached at [defaultBaseUrl] unless a base URL is given.
/// The API key is read from secure storage during
/// [initialize] and then sent on every request.
class JellyseerrService {
  /// Placeholder default; callers pass the real address.
  static const String defaultBaseUrl = 'http://localhost:5055';

  /// Secure-storage key holding the Jellyseerr API key.
  static const String apiKeyStorageKey = 'jellyseerr_api_key';

  static const Duration requestTimeout = Duration(seconds: 30);

  static const String _apiPrefix = '/api/v1';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  String _baseUrl = defaultBaseUrl;
  String? _apiKey;

  JellyseerrService(this._dio, this._secureStorage);

  /// Base URL currently in use, without a trailing slash.
  String get baseUrl => _baseUrl;

  /// True once [initialize] has found an API key in secure storage.
  bool get hasApiKey => (_apiKey ?? '').isNotEmpty;

  /// Points the client at [baseUrl], loads the API key and configures Dio.
  ///
  /// Called once during app startup. A missing API key is not fatal here —
  /// Jellyseerr may be running open — so the key is simply left unset and the
  /// request itself will surface any 401.
  Future<void> initialize([String baseUrl = defaultBaseUrl]) async {
    _baseUrl = _normalizeBaseUrl(baseUrl);

    try {
      _apiKey = await _secureStorage.read(key: apiKeyStorageKey);
    } catch (error) {
      // Secure storage is unavailable on some desktop/TV targets. Treat that
      // as "no key" rather than blocking discovery entirely.
      _apiKey = null;
    }

    final options = _dio.options;
    options.baseUrl = _baseUrl;
    options.connectTimeout = requestTimeout;
    options.receiveTimeout = requestTimeout;
    if (hasApiKey) {
      // Jellyseerr's own middleware reads X-Api-Key; the api_key query
      // parameter added in _query() covers reverse proxies that strip headers.
      options.headers['X-Api-Key'] = _apiKey;
    }
  }

  /// Searches Jellyseerr for [query].
  ///
  /// Returns an empty list for a blank query. Throws
  /// [JellyseerrServiceException] on any transport or parse failure.
  Future<List<JellyseerrSearchResultDto>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Built by hand: Dio's queryParameters would send a space as '+' and
    // Uri.encodeComponent leaves apostrophes raw; Seerr 400s on either.
    final encodedQuery = strictQueryEncode(trimmed);
    final data = await _get(
      '$_apiPrefix/search?query=$encodedQuery&page=1',
      description: 'search for "$trimmed"',
    );

    return _parseList(
      data,
      JellyseerrSearchResultDto.fromJson,
      description: 'search results',
    );
  }

  /// Lists the downloadable releases Jellyseerr knows about for [mediaId].
  ///
  /// [mediaType] must be `'tv'` or `'movie'`.
  Future<List<JellyseerrFileOptionDto>> getAvailableFiles(
    int mediaId,
    String mediaType,
  ) async {
    final type = _validateMediaType(mediaType);

    final data = await _get(
      '$_apiPrefix/$type/$mediaId/files',
      description: 'file lookup for $type $mediaId',
    );

    return _parseList(
      data,
      JellyseerrFileOptionDto.fromJson,
      description: 'file options',
    );
  }

  /// Submits a download request for [mediaId] covering [selectedFiles].
  Future<JellyseerrMediaRequestDto> submitRequest(
    int mediaId,
    String mediaType,
    List<String> selectedFiles,
  ) async {
    final type = _validateMediaType(mediaType);
    final description = 'request for $type $mediaId';

    late final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_apiPrefix/request',
        data: {
          'mediaId': mediaId,
          'mediaType': type,
          'files': selectedFiles,
        },
        queryParameters: _query(),
      );
    } on DioException catch (error) {
      throw _wrap(error, description);
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw JellyseerrServiceException(
        'Jellyseerr returned an unexpected body for $description: '
        '${data.runtimeType}',
        statusCode: response.statusCode,
      );
    }

    try {
      return JellyseerrMediaRequestDto.fromJson(data);
    } catch (error) {
      throw JellyseerrServiceException(
        'Could not parse the $description confirmation',
        statusCode: response.statusCode,
        cause: error,
      );
    }
  }

  // --- internals ---------------------------------------------------------

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    required String description,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: _query(queryParameters),
      );
      return response.data;
    } on DioException catch (error) {
      throw _wrap(error, description);
    }
  }

  /// Merges the API key into [extra] as the `api_key` query parameter.
  Map<String, dynamic> _query([Map<String, dynamic>? extra]) {
    final query = <String, dynamic>{...?extra};
    if (hasApiKey) query['api_key'] = _apiKey;
    return query;
  }

  /// Accepts either a bare list or a `{results: [...]}`/`{files: [...]}` wrapper.
  List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson, {
    required String description,
  }) {
    dynamic raw = data;
    if (raw is Map<String, dynamic>) {
      raw = raw['results'] ?? raw['files'] ?? raw['data'];
    }

    if (raw is! List) {
      throw JellyseerrServiceException(
        'Jellyseerr returned an unexpected body for $description: '
        '${data.runtimeType}',
      );
    }

    try {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    } catch (error) {
      throw JellyseerrServiceException(
        'Could not parse $description from Jellyseerr',
        cause: error,
      );
    }
  }

  String _validateMediaType(String mediaType) {
    final type = mediaType.trim().toLowerCase();
    if (type != 'tv' && type != 'movie') {
      throw JellyseerrServiceException(
        "Unsupported mediaType '$mediaType' — expected 'tv' or 'movie'",
      );
    }
    return type;
  }

  JellyseerrServiceException _wrap(DioException error, String description) {
    final status = error.response?.statusCode;
    return JellyseerrServiceException(
      'Jellyseerr $description failed: ${_reason(error)}',
      statusCode: status,
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
