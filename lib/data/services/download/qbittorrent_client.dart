import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_now_service.dart' show DownloadNowConfig;

/// Decode magnet if already URL-encoded, then let Dio handle form encoding.
  /// Prowlarr returns magnets already URL-encoded (magnet%3A%3F...).
  /// Uri.decodeComponent decodes reserved chars (: ? = &) back to raw URI.
  String _prepareMagnetForForm(String magnet) => Uri.decodeComponent(magnet);

/// Tiny qBittorrent WebUI v2 client. Used by Download Now to drop a picked
/// Prowlarr release directly into the download client — Radarr/Sonarr then
/// auto-import the file from the downloads folder.
class QbittorrentClient {
  final Dio _dio;
  String? _cookie;

  QbittorrentClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
              headers: {
                'Referer': DownloadNowConfig.qbittorrentBaseUrl,
              },
            ));

  String get _base => DownloadNowConfig.qbittorrentBaseUrl;

  /// Reachability + auth check. Asks for the qBittorrent version after
  /// login instead of adding a test magnet — qBittorrent v5 rejects fake
  /// info-hashes, so a synthetic magnet always reports a false failure
  /// (and pollutes the download list on older versions).
  Future<bool> testConnection() async {
    if (!await _ensureLoggedIn()) return false;
    try {
      final res = await _dio.get(
        '$_base/api/v2/app/version',
        options: Options(headers: {'Cookie': _cookie ?? ''}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[qBittorrent] testConnection failed: $e');
      return false;
    }
  }

  Future<bool> _ensureLoggedIn() async {
    if (_cookie != null) return true;
    try {
      final res = await _dio.post(
        '$_base/api/v2/auth/login',
        data: {
          'username': DownloadNowConfig.qbittorrentUsername,
          'password': DownloadNowConfig.qbittorrentPassword,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      if (res.statusCode != 200 && res.statusCode != 204) return false;
      final setCookie = res.headers.value('set-cookie');
      if (setCookie == null) return false;
      // qBittorrent v5 returns "QBT_SID_<port>=...; HttpOnly; ..." — extract the full cookie name + value.
      final match = RegExp(r'(QBT_SID_\d+=([^;]+))').firstMatch(setCookie) ??
          RegExp(r'(SID=([^;]+))').firstMatch(setCookie);
      if (match == null) return false;
      // Use the full matched cookie name (QBT_SID_8420=xxx or SID=xxx)
      _cookie = match.group(1)!;
      return true;
    } catch (e) {
      debugPrint('[qBittorrent] login failed: $e');
      return false;
    }
  }

  /// Add a magnet link to the default download directory. Returns the
  /// qBittorrent "Ok." string on success and null on any failure.
  ///
  /// qBittorrent's `/api/v2/torrents/add` returns 200 with body
  /// "Ok." on success (older versions) OR JSON `{"added_torrent_ids":...}`
  /// (newer versions). On failure it returns 200 with body "Fails." or
  /// an error message. The status code alone can't tell them apart.
  ///
  /// The torrent is tagged with the "radarr" category so qBittorrent
  /// saves it under `H:\Downloads\radarr\...`. That's the only path
  /// shape the Radarr remote path mapping knows how to translate back
  /// to a nix path on the Radarr host.
  Future<String?> addMagnet(
    String magnet, {
    String? category,
    String? savePath,
  }) async {
    if (!await _ensureLoggedIn()) {
      debugPrint('[qBittorrent] addMagnet aborted: login failed');
      throw Exception('qBittorrent login failed - check credentials/URL');
    }
    final res = await _dio.post(
      '$_base/api/v2/torrents/add',
      data: {
        'urls': _prepareMagnetForForm(magnet),
        'category': category ?? DownloadNowConfig.qbittorrentMovieCategory,
        if (savePath != null) 'savepath': savePath,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': _cookie ?? ''},
      ),
    );
    if (res.statusCode != 200) {
      debugPrint(
        '[qBittorrent] addMagnet HTTP ${res.statusCode}: ${res.data}',
      );
      throw Exception('qBittorrent HTTP ${res.statusCode}: ${res.data}');
    }
    final data = res.data;
    bool success = false;
    if (data is Map) {
      // JSON response from qBittorrent v5+
      final successCount = data['success_count'];
      if (successCount is int && successCount > 0) {
        success = true;
      }
    } else {
      // Legacy string response
      final body = data?.toString() ?? '';
      final trimmed = body.trim();
      if (trimmed == 'Ok.' || (trimmed.startsWith('{') && trimmed.contains('success_count'))) {
        success = true;
      }
    }
    if (success) {
      return res.data?.toString() ?? 'Ok.';
    }
    debugPrint('[qBittorrent] addMagnet rejected: ${res.data}');
    throw Exception('qBittorrent rejected: ${res.data}');
  }

  /// Upload a .torrent file (as bytes) to qBittorrent. See [addMagnet]
  /// for why the category tag matters.
  Future<String?> addTorrentFile(
    List<int> bytes, {
    String? filename,
    String? category,
    String? savePath,
  }) async {
    if (!await _ensureLoggedIn()) {
      debugPrint('[qBittorrent] addTorrentFile aborted: login failed');
      throw Exception('qBittorrent login failed - check credentials/URL');
    }
    final form = FormData.fromMap({
      'torrents': MultipartFile.fromBytes(
        bytes,
        filename: filename ?? 'release.torrent',
      ),
      'category': category ?? DownloadNowConfig.qbittorrentMovieCategory,
      if (savePath != null) 'savepath': savePath,
    });
    final res = await _dio.post(
      '$_base/api/v2/torrents/add',
      data: form,
      options: Options(headers: {'Cookie': _cookie ?? ''}),
    );
    if (res.statusCode != 200) {
      debugPrint(
        '[qBittorrent] addTorrentFile HTTP ${res.statusCode}: ${res.data}',
      );
      throw Exception('qBittorrent HTTP ${res.statusCode}: ${res.data}');
    }
    final data = res.data;
    bool success = false;
    if (data is Map) {
      // JSON response from qBittorrent v5+
      final successCount = data['success_count'];
      if (successCount is int && successCount > 0) {
        success = true;
      }
    } else {
      // Legacy string response
      final body = data?.toString() ?? '';
      final trimmed = body.trim();
      if (trimmed == 'Ok.' || (trimmed.startsWith('{') && trimmed.contains('success_count'))) {
        success = true;
      }
    }
    if (success) {
      return res.data?.toString() ?? 'Ok.';
    }
    debugPrint('[qBittorrent] addTorrentFile rejected: ${res.data}');
    throw Exception('qBittorrent rejected: ${res.data}');
  }
}
