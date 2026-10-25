import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_now_service.dart' show DownloadNowConfig;

/// A release returned by Prowlarr — a single file the user could pick.
///
/// `size` is in bytes. `tier` is the same cascade buckets the
/// DownloadNowService uses, so the picker can group by tier before
/// showing sizes.
class ProwlarrRelease {
  final String guid;
  final String title;
  final int size;
  final int indexerId;
  final String indexer;
  final int seeders;
  final int? leechers;
  final String? magnetUrl;
  final String? downloadUrl;
  final String protocol;
  final int? ageHours;
  final int? tmdbId;

  /// When the indexer published it. A "WEB" release of a movie published
  /// before the movie's digital date is a renamed CAM or another film.
  final DateTime? publishDate;

  /// Below the quality minimum (SD), listed only because the user asked for
  /// SD releases (public build, plugin's `sd: true`).
  final bool lowQuality;

  /// Why the user may not take this release (over their size limit, public
  /// build); the picker shows it greyed with this reason.
  final String? blockedReason;

  const ProwlarrRelease({
    required this.guid,
    required this.title,
    required this.size,
    required this.indexerId,
    required this.indexer,
    required this.seeders,
    required this.protocol,
    this.leechers,
    this.magnetUrl,
    this.downloadUrl,
    this.ageHours,
    this.tmdbId,
    this.publishDate,
    this.lowQuality = false,
    this.blockedReason,
  });

  factory ProwlarrRelease.fromJson(Map<String, dynamic> json) => ProwlarrRelease(
        guid: (json['guid'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        indexerId: (json['indexerId'] as num?)?.toInt() ?? 0,
        indexer: (json['indexer'] as String?) ?? '',
        seeders: (json['seeders'] as num?)?.toInt() ?? 0,
        leechers: (json['leechers'] as num?)?.toInt(),
        magnetUrl: json['magnetUrl'] as String?,
        downloadUrl: json['downloadUrl'] as String?,
        protocol: (json['protocol'] as String?) ?? 'unknown',
        ageHours: (json['ageHours'] as num?)?.toInt(),
        tmdbId: (json['tmdbId'] as num?)?.toInt(),
        publishDate: DateTime.tryParse(json['publishDate'] as String? ?? ''),
      );

  /// Human-readable size, e.g. "6.2 GB".
  String get sizeLabel => _humanBytes(size);

  /// Tier this release falls into. Mirrors the regex logic in
  /// DownloadNowService so a 2160p release from the picker matches the
  /// 2160p tier the cascade chose.
  String get tierLabel {
    final t = title.toLowerCase();
    final has2160 = RegExp(r'2160p|4k|uhd|ultra[.\s_-]?hd').hasMatch(t);
    final has1080 = RegExp(r'1080p|1080i').hasMatch(t);
    final has720 = RegExp(r'720p').hasMatch(t);
    if (has2160) return '2160p';
    if (has1080) return '1080p';
    if (has720) return '720p';
    return 'other';
  }
}

String _humanBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes B';
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}

/// Prowlarr search client. We only need one endpoint — the newznab
/// `/api/v1/search` call — and we use it both for the quality probe and
/// for the release picker.
class ProwlarrSearchClient {
  final Dio _dio;

  ProwlarrSearchClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
              headers: {
                'X-Api-Key': DownloadNowConfig.prowlarrApiKey,
              },
            ));

  String get _base => DownloadNowConfig.prowlarrBaseUrl;

  /// Minimum plausible sizes for media files (bytes).
  /// Episodes: 200 MB minimum (720p ~300 MB, 1080p ~1 GB)
  /// Movies: 700 MB minimum (720p ~1 GB, 1080p ~4 GB)
  static const _minEpisodeSize = 200 * 1024 * 1024; // 200 MB
  static const _minMovieSize = 700 * 1024 * 1024; // 700 MB
  static const _minXxxSize = 20 * 1024 * 1024; // 20 MB: short clips count

  /// File extensions that are NEVER valid media files.
  static const _bannedExtensions = {
    '.exe', '.msi', '.apk', '.app', '.dmg', '.pkg',
    '.bat', '.cmd', '.ps1', '.sh', '.scr', '.com',
    '.jar', '.py', '.rb', '.pl', '.php',
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz',
    '.iso', '.img', '.vhd', '.vhdx',
    '.pdf', '.doc', '.docx', '.txt', '.rtf',
  };

  /// Cinema copies, screeners and executables. Kept identical to the
  /// "Blokker TS/CAM og kjørbare filer" release profile in Radarr/Sonarr,
  /// which a release picked here would otherwise bypass.
  static final _junkRelease = RegExp(
    r'\b(HD-?CAM|CAM-?RIP|HQ-?CAM|CAM|HD-?TS|TS-?RIP|TELESYNC|PDVD|HD-?TC|'
    r'TELECINE|DVD-?SCR|SCREENER|WORKPRINT|TS|TC|exe|scr|lnk|msi)\b',
    caseSensitive: false,
  );

  /// A disc or web source counts as good quality even without a resolution.
  static final _goodSource = RegExp(
    r'\b(BluRay|Blu-Ray|BDRip|BRRip|BDRemux|REMUX|DVDRip|DVD9|DVD5|DVD|'
    r'WEB-?DL|WEBRip|WEB|HDRip)\b',
    caseSensitive: false,
  );

  /// Check if a release looks like a valid media file.
  @visibleForTesting
  static bool isValidMedia(ProwlarrRelease r, String mediaType) =>
      _isValidMedia(r, mediaType);

  /// The same CAM/TS/screener/exe, quality and size rules the picker applies,
  /// for releases that come from elsewhere (Sonarr's interactive search).
  /// Without [needsLink] a release without a magnet or torrent link passes:
  /// Sonarr (or the Tortugarr plugin) grabs it by its guid, and the plugin
  /// sends no links at all - every episode was dropped as "no download
  /// method" (2026-10-21).
  static bool acceptsRelease(ProwlarrRelease r, String mediaType,
          {bool needsLink = true}) =>
      _isValidMedia(r, mediaType, needsLink: needsLink);

  /// Executables are never media, whatever the category.
  static final _executable =
      RegExp(r'\b(exe|scr|lnk|msi)\b', caseSensitive: false);

  static bool _isValidMedia(ProwlarrRelease r, String mediaType,
      {bool needsLink = true}) {
    final titleLower = r.title.toLowerCase();

    // Adult releases rarely follow scene naming (no source tags, short
    // clips), so only the safety checks apply to them.
    if (mediaType == 'xxx') {
      return !_executable.hasMatch(r.title) &&
          !_bannedExtensions.any(titleLower.endsWith) &&
          (r.size <= 0 || r.size >= _minXxxSize) &&
          (r.protocol == 'bittorrent' || r.protocol == 'torrent');
    }

    if (_junkRelease.hasMatch(r.title)) {
      debugPrint('[Prowlarr] Filtered (CAM/TS/exe): "${r.title}"');
      return false;
    }

    // Only 720p/1080p/2160p, or a DVD/Blu-ray/web source.
    if (r.tierLabel == 'other' && !_goodSource.hasMatch(r.title)) {
      debugPrint('[Prowlarr] Filtered (no quality): "${r.title}"');
      return false;
    }

    // Size check - too small = fake/suspicious
    final minSize = mediaType == 'tv' ? _minEpisodeSize : _minMovieSize;
    if (r.size > 0 && r.size < minSize) {
      debugPrint('[Prowlarr] Filtered (too small): "${r.title}" ${r.sizeLabel}');
      return false;
    }

    // Extension check - downloadUrl or title has banned extension
    final url = r.downloadUrl ?? '';
    for (final ext in _bannedExtensions) {
      if (titleLower.endsWith(ext) || url.toLowerCase().endsWith(ext)) {
        debugPrint('[Prowlarr] Filtered (banned ext): "${r.title}"');
        return false;
      }
    }

    // Protocol check - skip non-bittorrent if possible
    if (r.protocol != 'bittorrent' && r.protocol != 'torrent') {
      debugPrint('[Prowlarr] Filtered (protocol=${r.protocol}): "${r.title}"');
      return false;
    }

    // Must have a way to download (magnet or torrent file)
    final hasMagnet = (r.guid.isNotEmpty && r.guid.startsWith('magnet:')) ||
        (r.magnetUrl?.isNotEmpty == true && r.magnetUrl!.startsWith('magnet:'));
    final hasTorrentUrl = r.downloadUrl?.isNotEmpty == true;
    if (needsLink && !hasMagnet && !hasTorrentUrl) {
      debugPrint('[Prowlarr] Filtered (no download method): "${r.title}"');
      return false;
    }

    return true;
  }

  /// Free-text search for a title. Returns the releases sorted by
  /// seeders (descending) so the most-available result shows first.
  Future<List<ProwlarrRelease>> search({
    required String query,
    required String mediaType,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/api/v1/search',
        queryParameters: {
          'query': query,
          'type': 'search',
          'limit': limit,
          // Use broader categories to catch indexers that don't use standard ones
          // 2000 = movies, 2010 = foreign movies, 2020 = documentaries, etc.
          // 5000 = tv, 5010 = anime, 5020 = documentaries, etc.
          'categories': switch (mediaType) {
            'movie' => [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060],
            'xxx' => [6000, 6010, 6020, 6030, 6040, 6045, 6050, 6060, 6070, 6080, 6090],
            _ => [5000, 5010, 5020, 5030, 5040, 5045, 5050, 5060, 5070, 5080],
          },
        },
      );
      debugPrint('[Prowlarr] search "$query" (mediaType=$mediaType) HTTP ${res.statusCode}, items=${res.data is List ? (res.data as List).length : "not a list"}');
      if (res.statusCode != 200 || res.data is! List) return const [];
      final rawList = res.data as List;
      if (rawList.isNotEmpty) {
        final first = rawList.first;
        if (first is Map) {
          debugPrint('[Prowlarr] first result keys: ${first.keys.toList()}');
          debugPrint('[Prowlarr] first result: guid="${first['guid']}", magnetUrl="${first['magnetUrl']}", downloadUrl="${first['downloadUrl']}", protocol="${first['protocol']}", title="${first['title']}"');
        }
      }
      final releases = rawList
          .whereType<Map>()
          .map((m) => ProwlarrRelease.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      releases.sort((a, b) => b.seeders.compareTo(a.seeders));
      // Filter out suspicious/fake releases before returning.
      final filtered = releases.where((r) => _isValidMedia(r, mediaType)).toList();
      debugPrint('[Prowlarr] filtered ${releases.length} -> ${filtered.length} releases');
      return filtered;
    } catch (e) {
      debugPrint('[Prowlarr] search exception: $e');
      return const [];
    }
  }

  /// Keyword search for adult releases. Indexers only match titles and
  /// need every word in them, so "a b c" finds next to nothing while each
  /// word alone finds plenty. Search the phrase and every word, merge, and
  /// rank by how many of the words a title contains, then by seeders.
  Future<List<ProwlarrRelease>> searchKeywords({
    required String query,
    required String mediaType,
  }) async {
    final words = keywordsOf(query);
    if (words.length <= 1) return search(query: query, mediaType: mediaType);
    final results = await Future.wait([
      search(query: query, mediaType: mediaType),
      for (final w in words) search(query: w, mediaType: mediaType),
    ]);
    final byGuid = <String, ProwlarrRelease>{};
    for (final list in results) {
      for (final r in list) {
        byGuid.putIfAbsent(r.guid, () => r);
      }
    }
    final ranked = byGuid.values.toList()
      ..sort((a, b) {
        final byWords =
            matchCount(b.title, words).compareTo(matchCount(a.title, words));
        if (byWords != 0) return byWords;
        return b.seeders.compareTo(a.seeders);
      });
    return ranked;
  }

  @visibleForTesting
  static List<String> keywordsOf(String query) => query
      .toLowerCase()
      .split(RegExp(r'[\s,.+_-]+'))
      .where((w) => w.length >= 2)
      .toSet()
      .toList();

  @visibleForTesting
  static int matchCount(String title, List<String> words) {
    final t = title.toLowerCase();
    return words.where(t.contains).length;
  }

  /// Follow the [release]'s downloadUrl to grab a real .torrent file the
  /// download client can ingest. Returns the raw bytes; for magnet links
  /// this just returns the URL string.
  Future<({String? magnet, List<int>? torrentBytes, String? fileName})>
      fetchPayload(ProwlarrRelease release) async {
    debugPrint('[Prowlarr] fetchPayload for "${release.title}": guid="${release.guid}", magnetUrl="${release.magnetUrl}", downloadUrl="${release.downloadUrl}", protocol="${release.protocol}"');

    // Prefer the raw magnet from guid (actual magnet URI).
    // magnetUrl is often a Prowlarr proxy URL that may or may not redirect cleanly.
    final rawMagnet = release.guid;
    if (rawMagnet.isNotEmpty && rawMagnet.startsWith('magnet:')) {
      debugPrint('[Prowlarr] Using magnet from guid');
      return (magnet: rawMagnet, torrentBytes: null, fileName: null);
    }
    // Fallback to magnetUrl if guid isn't a magnet.
    final magnet = release.magnetUrl;
    if (magnet != null && magnet.isNotEmpty && magnet.startsWith('magnet:')) {
      debugPrint('[Prowlarr] Using magnet from magnetUrl');
      return (magnet: magnet, torrentBytes: null, fileName: null);
    }
    final url = release.downloadUrl;
    if (url == null || url.isEmpty) {
      debugPrint('[Prowlarr] No downloadUrl available');
      throw Exception('No download URL or magnet link available for "${release.title}". Indexer: ${release.indexer} (id: ${release.indexerId})');
    }
    // Check if downloadUrl is actually a magnet link (some indexers return magnets via Prowlarr's /download endpoint)
    if (url.startsWith('magnet:')) {
      debugPrint('[Prowlarr] downloadUrl is a magnet link');
      return (magnet: url, torrentBytes: null, fileName: null);
    }
    // Fetch the .torrent file with redirects handled manually. Prowlarr
    // answers magnet-only releases with a 302 straight to a magnet: URI,
    // and Dio's redirect follower dies on those ("No host specified in
    // URI"). Follow http(s) hops ourselves and return the magnet as soon
    // as one shows up, skipping the torrent-file download entirely.
    try {
      var currentUrl = url;
      for (var hop = 0; hop < 5; hop++) {
        debugPrint('[Prowlarr] Downloading torrent file from: $currentUrl');
        final res = await _dio.get<List<int>>(
          currentUrl,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
          ),
        );
        final status = res.statusCode ?? 0;
        if (status >= 300 && status < 400) {
          final location = res.headers.value('location');
          if (location == null || location.isEmpty) {
            debugPrint('[Prowlarr] Redirect without location header (HTTP $status)');
            return (magnet: null, torrentBytes: null, fileName: null);
          }
          if (location.startsWith('magnet:')) {
            debugPrint('[Prowlarr] Download redirected to magnet');
            return (magnet: location, torrentBytes: null, fileName: null);
          }
          // Resolve relative redirects against the URL that produced them.
          currentUrl = Uri.parse(currentUrl).resolve(location).toString();
          continue;
        }
        if (status != 200 || res.data == null) {
          debugPrint('[Prowlarr] Download failed: HTTP $status');
          return (magnet: null, torrentBytes: null, fileName: null);
        }
        final name = (res.headers.value('content-disposition') ?? '')
            .split('filename=')
            .last
            .replaceAll(RegExp(r'[";]'), '')
            .trim();
        debugPrint('[Prowlarr] Downloaded torrent file: ${name.isEmpty ? "unnamed" : name}, ${res.data!.length} bytes');
        return (
          magnet: null,
          torrentBytes: res.data,
          fileName: name.isEmpty ? null : name,
        );
      }
      debugPrint('[Prowlarr] Download gave up after 5 redirects');
      return (magnet: null, torrentBytes: null, fileName: null);
    } catch (e) {
      debugPrint('[Prowlarr] Download exception: $e');
      throw Exception('Failed to download torrent file from $url: $e');
    }
  }
}
