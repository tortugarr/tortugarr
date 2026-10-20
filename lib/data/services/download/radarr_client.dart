import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_now_service.dart' show DownloadNowConfig;

/// URL-encode a magnet link for form-urlencoded POST body.
/// Magnet links contain & and = which would break form parsing if not encoded.
String _encodeMagnetForForm(String magnet) => Uri.encodeComponent(magnet);

/// Tiny Radarr v3 client. The only thing we need it for is grabbing a
/// release the user picked from Prowlarr — that way Radarr stays in the
/// loop, sends the torrent to qBittorrent itself, and auto-imports the
/// resulting file into the movie library.
class RadarrClient {
  final Dio _dio;

  RadarrClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
              headers: {
                'X-Api-Key': DownloadNowConfig.radarrApiKey,
              },
            ));

  String get _base => DownloadNowConfig.radarrBaseUrl;

  bool _isSuccess(Response res) =>
      res.statusCode == 200 ||
      res.statusCode == 201 ||
      res.statusCode == 202;

  /// Look up a movie's metadata on TMDB via Radarr. Returns the lookup
  /// object (which contains the title, year, runtime, and runtime
  /// fields Radarr needs to add it). Returns null on any failure.
  Future<Map<String, dynamic>?> lookupByTmdb(int tmdbId) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/movie/lookup/tmdb',
        queryParameters: {'tmdbId': tmdbId},
      );
      if (!_isSuccess(res) || res.data is! Map) {
        debugPrint(
          '[Radarr] lookupByTmdb($tmdbId) HTTP ${res.statusCode}',
        );
        return null;
      }
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      debugPrint('[Radarr] lookupByTmdb($tmdbId) failed: $e');
      return null;
    }
  }

  /// Returns the movie object if it is already in the Radarr library, or
  /// null if it isn't (or the lookup failed).
  Future<Map<String, dynamic>?> movieByTmdb(int tmdbId) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/movie',
        queryParameters: {'tmdbIdId': tmdbId},
      );
      if (!_isSuccess(res) || res.data is! List) return null;
      for (final raw in res.data as List) {
        if (raw is Map && raw['tmdbId'] == tmdbId) {
          return Map<String, dynamic>.from(raw);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Radarr] movieByTmdb($tmdbId) failed: $e');
      return null;
    }
  }

  /// Add a movie to the Radarr library. [lookup] is the body returned by
  /// [lookupByTmdb]. [searchForMovie] is left false — the caller already
  /// picked a specific release and will call [grabRelease] right after.
  Future<bool> addMovie({
    required Map<String, dynamic> lookup,
    required int qualityProfileId,
    required String rootFolderPath,
    bool monitored = true,
    String minimumAvailability = 'released',
  }) async {
    try {
      final body = {
        // Spread FIRST: the lookup result carries its own placeholder values
        // (e.g. qualityProfileId: 0), which must never override the real
        // values below — Radarr rejects the add with 400 otherwise.
        ...lookup,
        'title': lookup['title'],
        'qualityProfileId': qualityProfileId,
        'tmdbId': lookup['tmdbId'],
        'year': lookup['year'],
        'rootFolderPath': rootFolderPath,
        'monitored': monitored,
        'minimumAvailability': minimumAvailability,
        'addOptions': {'searchForMovie': false},
      };
      final res = await _dio.post(
        '$_base/api/v3/movie',
        data: body,
      );
      if (_isSuccess(res)) {
        debugPrint('[Radarr] added movie "${lookup['title']}"');
        return true;
      }
      debugPrint(
        '[Radarr] addMovie rejected: ${res.statusCode} ${res.data}',
      );
    } catch (e) {
      debugPrint('[Radarr] addMovie failed: $e');
    }
    return false;
  }

  /// Fetch all quality profiles (cached for the lifetime of this client).
  Future<List<Map<String, dynamic>>> qualityProfiles() async {
    try {
      final res = await _dio.get('$_base/api/v3/qualityprofile');
      if (!_isSuccess(res) || res.data is! List) return const [];
      return (res.data as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[Radarr] qualityProfiles failed: $e');
      return const [];
    }
  }

  /// Fetch the configured root folders (cached for the lifetime of this
  /// client).
  Future<List<Map<String, dynamic>>> rootFolders() async {
    try {
      final res = await _dio.get('$_base/api/v3/rootfolder');
      if (!_isSuccess(res) || res.data is! List) return const [];
      return (res.data as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[Radarr] rootFolders failed: $e');
      return const [];
    }
  }

  /// Tell Radarr to grab a specific release. [guid] is the release guid
  /// (Prowlarr hands us the same one Radarr queries with) and
  /// [indexerId] is the indexer the release came from.
  ///
  /// Radarr will resolve the guid through its indexer, push the torrent
  /// to the configured download client (qBittorrent in this setup), and
  /// auto-import the finished file into the movie library.
  Future<({bool ok, int? status, String? body})> grabRelease({
    required String guid,
    required int indexerId,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/api/v3/release',
        data: {
          'guid': guid,
          'indexerId': indexerId,
        },
      );
      if (_isSuccess(res)) return (ok: true, status: res.statusCode, body: null);
      debugPrint(
        '[Radarr] grabRelease rejected: ${res.statusCode} ${res.data}',
      );
      return (ok: false, status: res.statusCode, body: res.data?.toString());
    } catch (e) {
      debugPrint('[Radarr] grabRelease failed: $e');
      return (ok: false, status: null, body: e.toString());
    }
  }

  /// Hand a release the Radarr has never seen to it directly. `/release`
  /// (grab) only knows releases from the Radarr's own searches and answers
  /// 404 "not in cache" for anything picked from Prowlarr; push makes the
  /// Radarr download and track it like one of its own.
  Future<({bool ok, String? reason})> pushRelease({
    required String title,
    required String downloadUrl,
    DateTime? publishDate,
    int? size,
    String? indexer,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/api/v3/release/push',
        data: {
          'title': title,
          'downloadUrl': downloadUrl,
          'protocol': 'torrent',
          'publishDate': (publishDate ?? DateTime.now()).toUtc().toIso8601String(),
          if (size != null && size > 0) 'size': size,
          if (indexer != null) 'indexer': indexer,
        },
      );
      final data = res.data;
      final first = data is List && data.isNotEmpty ? data.first : data;
      if ((res.statusCode == 200 || res.statusCode == 201) &&
          first is Map &&
          first['approved'] == true) {
        return (ok: true, reason: null);
      }
      final rejections = first is Map ? first['rejections'] : null;
      final reason = rejections is List && rejections.isNotEmpty
          ? rejections.join('; ')
          : 'HTTP ${res.statusCode}';
      debugPrint('[Radarr] pushRelease rejected: $reason');
      return (ok: false, reason: reason);
    } catch (e) {
      debugPrint('[Radarr] pushRelease failed: $e');
      return (ok: false, reason: e.toString());
    }
  }

  /// Wait until the Radarr's queue shows a download for [movieId].
  ///
  /// A grab is not in the queue until the Radarr next polls the download
  /// client; a search started before that (Seerr does one when a request is
  /// approved) does not see it and grabs a second release.
  Future<bool> waitUntilQueued(int movieId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await _dio.post('$_base/api/v3/command',
          data: {'name': 'RefreshMonitoredDownloads'});
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final res = await _dio.get('$_base/api/v3/queue/details',
            queryParameters: {'movieId': movieId});
        if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
          return true;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('[Radarr] waitUntilQueued failed: $e');
    }
    return false;
  }

  /// Fall back path: when Radarr can't accept the guid (e.g. a release
  /// the user's indexer doesn't expose via the API), we still have the
  /// magnet URL. Drop it directly into qBittorrent so the user at least
  /// gets the file — and the file lands in the watch folder Radarr
  /// monitors, so it still gets imported.
  Future<bool> grabMagnetViaQbittorrent({
    required String magnet,
    String? filename,
  }) async {
    // Lazy import keeps this file usable when qBittorrent isn't reachable.
    final qb = _Qbittorrent();
    return qb.addMagnet(magnet).then((r) => r != null);
  }
}

/// Local qBittorrent helper for the Radarr-fallback path. Kept tiny and
/// private so the main QbittorrentClient (which is also used elsewhere)
/// stays the source of truth.
class _Qbittorrent {
  final Dio _dio;
  String? _cookie;

  _Qbittorrent()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (_) => true,
          headers: {
            'Referer': DownloadNowConfig.qbittorrentBaseUrl,
          },
        ));

  Future<String?> addMagnet(String magnet) async {
    if (_cookie == null) {
      final login = await _dio.post(
        '${DownloadNowConfig.qbittorrentBaseUrl}/api/v2/auth/login',
        data: {
          'username': DownloadNowConfig.qbittorrentUsername,
          'password': DownloadNowConfig.qbittorrentPassword,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (login.statusCode != 200) return null;
      final setCookie = login.headers.value('set-cookie');
      final m = RegExp(r'SID=([^;]+)').firstMatch(setCookie ?? '');
      if (m == null) return null;
      _cookie = 'SID=${m.group(1)}';
    }
    final res = await _dio.post(
      '${DownloadNowConfig.qbittorrentBaseUrl}/api/v2/torrents/add',
      data: {
        'urls': _encodeMagnetForForm(magnet),
        'category': DownloadNowConfig.qbittorrentMovieCategory,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': _cookie ?? ''},
      ),
    );
    if (res.statusCode != 200) return null;
    final body = res.data?.toString() ?? '';
    final trimmed = body.trim();
    if (trimmed == 'Ok.' || (trimmed.startsWith('{') && trimmed.contains('"success_count"'))) {
      return body;
    }
    debugPrint('[Radarr._Qbittorrent] addMagnet rejected: $body');
    throw Exception('qBittorrent rejected: $body');
  }
}
