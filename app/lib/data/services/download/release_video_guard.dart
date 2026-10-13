import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_now_service.dart' show DownloadNowConfig;

/// What the guard concluded about a grabbed release.
enum VideoCheckOutcome {
  /// The torrent holds a real video file.
  ok,

  /// No video in the torrent (e.g. a lone .exe); it was removed and, where
  /// Radarr/Sonarr track it, blocklisted so it is not grabbed again.
  removed,

  /// Same finding, but removing it failed — the user must clean up.
  removeFailed,

  /// The torrent or its file list never showed up within the time limit.
  unknown,
}

class VideoCheckResult {
  final VideoCheckOutcome outcome;
  final List<String> fileNames;
  const VideoCheckResult(this.outcome, [this.fileNames = const []]);
}

/// Checks what a grabbed torrent actually contains once qBittorrent has its
/// file list. Fake releases often look clean by title ("… 1080p WEB H264")
/// and carry a single .exe; qBittorrent skips such files, but Radarr/Sonarr
/// then sit on a download that never imports. This removes them early.
class ReleaseVideoGuard {
  static const videoExtensions = {
    '.mkv', '.mp4', '.m4v', '.avi', '.mov', '.wmv', '.ts', '.m2ts',
    '.webm', '.mpg', '.mpeg', '.vob',
  };

  /// A video file smaller than this is a sample or a decoy.
  static const int minVideoBytes = 50 * 1024 * 1024;

  final Dio _dio;
  final Duration pollEvery;
  String? _qbCookie;

  ReleaseVideoGuard({Dio? dio, this.pollEvery = const Duration(seconds: 15)})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ));

  /// Watch the release the user just grabbed. [guid] is the Prowlarr guid
  /// (often the magnet itself), used to know the torrent hash up front.
  Future<VideoCheckResult> watch({
    required String releaseTitle,
    required String guid,
    String? magnetUrl,
    required bool isMovie,
    String? qbCategory,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    // A category of our own means Radarr/Sonarr are not involved.
    final viaArr = qbCategory == null;
    final deadline = DateTime.now().add(timeout);
    var hash = magnetHash(guid) ?? magnetHash(magnetUrl);
    while (DateTime.now().isBefore(deadline)) {
      try {
        hash ??= await _findHash(releaseTitle, isMovie,
            viaArr: viaArr, category: qbCategory);
        if (hash != null) {
          final files = await _files(hash);
          if (files != null && files.isNotEmpty) {
            if (hasVideo(files)) {
              return VideoCheckResult(VideoCheckOutcome.ok);
            }
            final names = [for (final f in files) f.name];
            final removed = await _remove(hash, isMovie, viaArr: viaArr);
            return VideoCheckResult(
              removed ? VideoCheckOutcome.removed : VideoCheckOutcome.removeFailed,
              names,
            );
          }
        }
      } catch (e) {
        debugPrint('[VideoGuard] check failed, retrying: $e');
      }
      await Future<void>.delayed(pollEvery);
    }
    return const VideoCheckResult(VideoCheckOutcome.unknown);
  }

  @visibleForTesting
  static bool hasVideo(List<({String name, int size})> files) => files.any(
        (f) =>
            f.size >= minVideoBytes &&
            videoExtensions.any((ext) => f.name.toLowerCase().endsWith(ext)),
      );

  /// The info hash (lower-case hex) from a magnet link, or null.
  @visibleForTesting
  static String? magnetHash(String? magnet) {
    if (magnet == null || !magnet.startsWith('magnet:')) return null;
    final m = RegExp(r'xt=urn:btih:([A-Za-z0-9]+)', caseSensitive: false)
        .firstMatch(Uri.decodeComponent(magnet));
    final raw = m?.group(1);
    if (raw == null) return null;
    if (raw.length == 40) return raw.toLowerCase();
    if (raw.length == 32) return _base32ToHex(raw);
    return null;
  }

  static String? _base32ToHex(String s) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final ch in s.toUpperCase().split('')) {
      final v = alphabet.indexOf(ch);
      if (v < 0) return null;
      value = (value << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.write(((value >> bits) & 0xff).toRadixString(16).padLeft(2, '0'));
      }
    }
    return out.toString();
  }

  // ------------------------------------------------------------ lookups

  ({String base, String key}) _arr(bool isMovie) => isMovie
      ? (base: DownloadNowConfig.radarrBaseUrl, key: DownloadNowConfig.radarrApiKey)
      : (base: DownloadNowConfig.sonarrBaseUrl, key: DownloadNowConfig.sonarrApiKey);

  Future<List<Map>> _queue(bool isMovie) async {
    final arr = _arr(isMovie);
    final res = await _dio.get(
      '${arr.base}/api/v3/queue',
      queryParameters: {'pageSize': 500},
      options: Options(headers: {'X-Api-Key': arr.key}),
    );
    final records = res.data is Map ? res.data['records'] : null;
    if (res.statusCode != 200 || records is! List) return const [];
    return records.whereType<Map>().toList();
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Radarr/Sonarr name the queue item after the release; qBittorrent names
  /// the torrent after it too. Either gives us the hash.
  Future<String?> _findHash(
    String title,
    bool isMovie, {
    bool viaArr = true,
    String? category,
  }) async {
    final want = _norm(title);
    for (final r in viaArr ? await _queue(isMovie) : const <Map>[]) {
      final id = r['downloadId'];
      if (id is String && _norm(r['title'] as String? ?? '') == want) {
        return id.toLowerCase();
      }
    }
    final torrents = await _qbGet('/api/v2/torrents/info', {
      'category': category ??
          (isMovie
              ? DownloadNowConfig.qbittorrentMovieCategory
              : DownloadNowConfig.qbittorrentTvCategory),
    });
    if (torrents is List) {
      for (final t in torrents.whereType<Map>()) {
        if (_norm(t['name'] as String? ?? '') == want) {
          return (t['hash'] as String?)?.toLowerCase();
        }
      }
    }
    return null;
  }

  /// The torrent's files, or null while qBittorrent is still fetching the
  /// metadata (a magnet has no file list until then).
  Future<List<({String name, int size})>?> _files(String hash) async {
    final data = await _qbGet('/api/v2/torrents/files', {'hash': hash});
    if (data is! List) return null;
    return [
      for (final f in data.whereType<Map>())
        (name: f['name'] as String? ?? '', size: (f['size'] as num?)?.toInt() ?? 0),
    ];
  }

  // ------------------------------------------------------------ removal

  Future<bool> _remove(String hash, bool isMovie, {bool viaArr = true}) async {
    // Through Radarr/Sonarr when they track it, so the release is
    // blocklisted and never grabbed again.
    for (final r in viaArr ? await _queue(isMovie) : const <Map>[]) {
      if ((r['downloadId'] as String?)?.toLowerCase() != hash) continue;
      final arr = _arr(isMovie);
      final res = await _dio.delete(
        '${arr.base}/api/v3/queue/${r['id']}',
        queryParameters: {'removeFromClient': true, 'blocklist': true},
        options: Options(headers: {'X-Api-Key': arr.key}),
      );
      if (res.statusCode == 200) return true;
    }
    if (!await _qbLogin()) return false;
    final res = await _dio.post(
      '${DownloadNowConfig.qbittorrentBaseUrl}/api/v2/torrents/delete',
      data: {'hashes': hash, 'deleteFiles': 'true'},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: _qbHeaders,
      ),
    );
    return res.statusCode == 200;
  }

  // -------------------------------------------------------- qBittorrent

  Map<String, String> get _qbHeaders => {
        'Referer': DownloadNowConfig.qbittorrentBaseUrl,
        if (_qbCookie != null) 'Cookie': _qbCookie!,
      };

  Future<bool> _qbLogin() async {
    if (_qbCookie != null) return true;
    final res = await _dio.post(
      '${DownloadNowConfig.qbittorrentBaseUrl}/api/v2/auth/login',
      data: {
        'username': DownloadNowConfig.qbittorrentUsername,
        'password': DownloadNowConfig.qbittorrentPassword,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: _qbHeaders,
      ),
    );
    // qBittorrent 5 answers 204 with an empty body on success.
    if (res.statusCode != 200 && res.statusCode != 204) return false;
    final setCookie = res.headers.value('set-cookie') ?? '';
    final m = RegExp(r'(QBT_SID_\d+=[^;]+)').firstMatch(setCookie) ??
        RegExp(r'(SID=[^;]+)').firstMatch(setCookie);
    if (m == null) return false;
    _qbCookie = m.group(1);
    return true;
  }

  Future<dynamic> _qbGet(String path, Map<String, dynamic> query) async {
    if (!await _qbLogin()) return null;
    final res = await _dio.get(
      '${DownloadNowConfig.qbittorrentBaseUrl}$path',
      queryParameters: query,
      options: Options(headers: _qbHeaders),
    );
    // 404 = no such torrent (yet); anything else unexpected is "not now".
    return res.statusCode == 200 ? res.data : null;
  }
}
