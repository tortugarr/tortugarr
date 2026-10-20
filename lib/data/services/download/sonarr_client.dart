import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_now_service.dart' show DownloadNowConfig;

/// One Sonarr series, in the trimmed shape the Download Now flow needs.
class SonarrSeries {
  final int id;
  final int? tvdbId;
  final int? tmdbId;
  final String title;
  final String? path;
  final int? qualityProfileId;
  final bool monitored;
  final List<SonarrEpisode> episodes;

  /// Sonarr's monitoring per season number.
  final Map<int, bool> seasonMonitored;

  const SonarrSeries({
    required this.id,
    required this.title,
    required this.episodes,
    this.tvdbId,
    this.tmdbId,
    this.path,
    this.qualityProfileId,
    this.monitored = true,
    this.seasonMonitored = const {},
  });

  /// Return a copy with [episodes] replaced. Sonarr's `/series/{id}` endpoint
  /// does NOT include episodes — they must be fetched separately via
  /// `/episode?seriesId=` — so callers attach them after the fact.
  SonarrSeries withEpisodes(List<SonarrEpisode> episodes) => SonarrSeries(
        id: id,
        tvdbId: tvdbId,
        tmdbId: tmdbId,
        title: title,
        path: path,
        qualityProfileId: qualityProfileId,
        monitored: monitored,
        episodes: episodes,
        seasonMonitored: seasonMonitored,
      );

  factory SonarrSeries.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = (json['episodes'] as List?) ?? const [];
    final eps = rawEpisodes
        .whereType<Map>()
        .map((e) => SonarrEpisode.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return SonarrSeries(
      // /series/lookup (Skyhook) results have no 'id' for series not yet in
      // the library — tolerate that instead of throwing a num cast.
      id: (json['id'] as num?)?.toInt() ?? 0,
      tvdbId: (json['tvdbId'] as num?)?.toInt(),
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      title: (json['title'] as String?) ?? '',
      path: json['path'] as String?,
      qualityProfileId: (json['qualityProfileId'] as num?)?.toInt(),
      monitored: json['monitored'] as bool? ?? true,
      episodes: eps,
      seasonMonitored: SonarrClient.seasonMonitoredOf(json['seasons']),
    );
  }
}

class SonarrEpisode {
  final int id;
  final int seasonNumber;
  final int episodeNumber;
  final String? title;
  final bool monitored;

  /// Sonarr has a file for this episode on disk.
  final bool hasFile;

  /// When it first aired; null when the date is not known yet.
  final DateTime? airDateUtc;

  const SonarrEpisode({
    required this.id,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.monitored,
    this.title,
    this.hasFile = false,
    this.airDateUtc,
  });

  factory SonarrEpisode.fromJson(Map<String, dynamic> json) => SonarrEpisode(
        id: (json['id'] as num?)?.toInt() ?? 0,
        seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
        episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
        monitored: json['monitored'] as bool? ?? false,
        title: json['title'] as String?,
        hasFile: json['hasFile'] as bool? ?? false,
        airDateUtc: DateTime.tryParse(json['airDateUtc'] as String? ?? ''),
      );
}

/// One result of a Sonarr interactive search (`GET /api/v3/release`).
class SonarrRelease {
  final String guid;
  final int indexerId;
  final String indexer;
  final String title;
  final int size;
  final int seeders;
  final int? leechers;
  final String protocol;
  final String? magnetUrl;
  final String? downloadUrl;
  final DateTime? publishDate;

  /// Sonarr's quality name, e.g. "WEBDL-1080p".
  final String quality;
  final bool approved;
  final bool fullSeason;
  final List<String> rejections;

  const SonarrRelease({
    required this.guid,
    required this.indexerId,
    required this.indexer,
    required this.title,
    required this.size,
    required this.seeders,
    required this.protocol,
    required this.quality,
    required this.approved,
    this.leechers,
    this.magnetUrl,
    this.downloadUrl,
    this.publishDate,
    this.fullSeason = false,
    this.rejections = const [],
  });

  factory SonarrRelease.fromJson(Map<String, dynamic> json) {
    final quality = json['quality'];
    final inner = quality is Map ? quality['quality'] : null;
    final rejections = json['rejections'];
    return SonarrRelease(
      guid: (json['guid'] as String?) ?? '',
      indexerId: (json['indexerId'] as num?)?.toInt() ?? 0,
      indexer: (json['indexer'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      seeders: (json['seeders'] as num?)?.toInt() ?? 0,
      leechers: (json['leechers'] as num?)?.toInt(),
      protocol: (json['protocol'] as String?) ?? 'unknown',
      magnetUrl: json['magnetUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      publishDate: DateTime.tryParse(json['publishDate'] as String? ?? ''),
      quality: inner is Map ? '${inner['name'] ?? ''}' : '',
      approved: json['approved'] as bool? ?? false,
      fullSeason: json['fullSeason'] as bool? ?? false,
      rejections: [
        if (rejections is List)
          for (final r in rejections)
            // Sonarr 4 sends plain strings; older versions sent {reason}.
            if (r is String) r else if (r is Map && r['reason'] is String) r['reason'] as String,
      ],
    );
  }
}

/// Tiny Sonarr v3 client. We use it for the one thing the Seerr API cannot
/// do: download a *subset* of episodes from a season. Sonarr's
/// per-episode monitoring + episode search covers that case cleanly.
class SonarrClient {
  final Dio _dio;

  SonarrClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
              headers: {
                'X-Api-Key': DownloadNowConfig.sonarrApiKey,
              },
            ));

  String get _base => DownloadNowConfig.sonarrBaseUrl;

  /// Why the last series lookup could not ask Sonarr, for the user to see.
  String? lastError;

  static String _describe(Object e) {
    final text = e is DioException
        ? [e.type.name, if (e.message != null) e.message!].join(': ')
        : '$e';
    final line = text.split('\n').first.trim();
    return line.length > 140 ? '${line.substring(0, 140)}…' : line;
  }

  /// Look up a series already in Sonarr's library by its TMDB id. Returns
  /// null when the series has never been added — the caller decides what
  /// to do. NOTE: this queries Sonarr's OWN series list (`/api/v3/series`),
  /// not `/series/lookup` — lookup results come from Skyhook and have no
  /// library 'id', so they can never resolve an existing series.
  Future<SonarrSeries?> lookupByTmdb(int tmdbId) async {
    try {
      final res = await _dio.get('$_base/api/v3/series');
      if (res.statusCode != 200 || res.data is! List) return null;
      for (final raw in res.data as List) {
        if (raw is! Map) continue;
        if ((raw['tmdbId'] as num?)?.toInt() == tmdbId) {
          return SonarrSeries.fromJson(Map<String, dynamic>.from(raw));
        }
      }
    } catch (e) {
      debugPrint('[Sonarr] lookupByTmdb failed: $e');
    }
    return null;
  }

  /// Fetch the full series record (with episodes) for an existing Sonarr
  /// series id.
  Future<SonarrSeries?> getSeries(int seriesId) async {
    try {
      final res = await _dio.get('$_base/api/v3/series/$seriesId');
      if (res.statusCode != 200 || res.data is! Map) return null;
      return SonarrSeries.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      debugPrint('[Sonarr] getSeries failed: $e');
      return null;
    }
  }

  /// Fetch every episode for a series. Sonarr's `/series/{id}` response
  /// omits episodes, so this is the only way to get the episode ids needed
  /// to monitor/search a subset of a season. Without this, per-episode
  /// downloads silently fell back to grabbing the WHOLE season.
  Future<List<SonarrEpisode>> getEpisodes(int seriesId) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/episode',
        queryParameters: {'seriesId': seriesId},
      );
      if (res.statusCode != 200 || res.data is! List) return const [];
      return (res.data as List)
          .whereType<Map>()
          .map((e) => SonarrEpisode.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[Sonarr] getEpisodes($seriesId) failed: $e');
      return const [];
    }
  }

  /// Sonarr's `/series/{id}` and the add-series response both omit episodes.
  /// Attach them via [getEpisodes] so callers can resolve per-episode ids.
  Future<SonarrSeries?> _ensureEpisodes(SonarrSeries s) async {
    if (s.episodes.isNotEmpty) return s;
    final eps = await getEpisodes(s.id);
    return s.withEpisodes(eps);
  }

  /// Resolves a TMDB id to a Sonarr series, fetching the full record. Adds
  /// the series to Sonarr with sane defaults if it isn't there yet — the
  /// "Download Now" flow assumes the show is available.
  Future<SonarrSeries?> ensureSeriesByTmdb(int tmdbId) async {
    final existing = await lookupByTmdb(tmdbId);
    if (existing != null) {
      final full = await getSeries(existing.id);
      if (full != null) return _ensureEpisodes(full);
    }
    // Nothing in the lookup result — try the direct lookup-by-tmdb call
    // (Sonarr accepts tmdb:12345 as a search term on /series/lookup).
    try {
      final res = await _dio.get(
        '$_base/api/v3/series/lookup',
        queryParameters: {'term': 'tmdb:$tmdbId'},
      );
      if (res.statusCode == 200 && res.data is List) {
        for (final raw in res.data as List) {
          if (raw is! Map) continue;
          if ((raw['tmdbId'] as num?)?.toInt() == tmdbId) {
            // Unmonitored, no search: the user decides per season in the
            // app what Sonarr should follow.
            final added = await _addSeries(
              Map<String, dynamic>.from(raw),
              monitored: false,
            );
            if (added != null) return added;
          }
        }
      }
    } catch (e) {
      debugPrint('[Sonarr] ensureSeriesByTmdb failed: $e');
    }
    return null;
  }

  /// Add the series with TVDB id [tvdbId] unmonitored and without a search,
  /// so its episode list is known but nothing is downloaded on its own.
  /// Returns the series as it is in Sonarr (also when it was already there).
  Future<SonarrSeries?> addSeriesUnmonitoredByTvdb(int tvdbId) async {
    final existing = await seriesByTvdb(tvdbId);
    if (existing.series != null) return existing.series;
    try {
      final res = await _dio.get(
        '$_base/api/v3/series/lookup',
        queryParameters: {'term': 'tvdb:$tvdbId'},
      );
      if (res.statusCode != 200 || res.data is! List) return null;
      for (final raw in res.data as List) {
        if (raw is Map && (raw['tvdbId'] as num?)?.toInt() == tvdbId) {
          return _addSeries(
            Map<String, dynamic>.from(raw),
            monitored: false,
          );
        }
      }
    } catch (e) {
      debugPrint('[Sonarr] addSeriesUnmonitoredByTvdb failed: $e');
    }
    return null;
  }

  /// The series with TVDB id [tvdbId] in Sonarr's library. `ok` is false when
  /// Sonarr could not be asked; `series` is null when it is not there.
  Future<({bool ok, SonarrSeries? series})> seriesByTvdb(int tvdbId) =>
      _seriesBy('tvdbId', tvdbId);

  /// Same as [seriesByTvdb], for series Jellyfin only knows by TMDB id.
  Future<({bool ok, SonarrSeries? series})> seriesByTmdb(int tmdbId) =>
      _seriesBy('tmdbId', tmdbId);

  Future<({bool ok, SonarrSeries? series})> _seriesBy(String field, int id) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/series',
        queryParameters: {if (field == 'tvdbId') 'tvdbId': id},
      );
      if (res.statusCode != 200 || res.data is! List) {
        lastError = 'Sonarr svarte HTTP ${res.statusCode}';
        return (ok: false, series: null);
      }
      lastError = null;
      for (final raw in res.data as List) {
        if (raw is Map && (raw[field] as num?)?.toInt() == id) {
          return (ok: true, series: SonarrSeries.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      return (ok: true, series: null);
    } catch (e) {
      debugPrint('[Sonarr] series by $field failed: $e');
      lastError = _describe(e);
      return (ok: false, series: null);
    }
  }

  /// Episode ids of [seriesId] that are in Sonarr's download queue right now.
  Future<Set<int>> queuedEpisodeIds(int seriesId) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/queue/details',
        queryParameters: {'seriesId': seriesId},
      );
      if (res.statusCode != 200 || res.data is! List) return const {};
      return {
        for (final r in (res.data as List).whereType<Map>())
          if (r['episodeId'] is num) (r['episodeId'] as num).toInt(),
      };
    } catch (e) {
      debugPrint('[Sonarr] queuedEpisodeIds failed: $e');
      return const {};
    }
  }

  /// Sonarr's interactive search: every release the indexers have for one
  /// episode ([episodeId]) or a whole season ([seriesId] + [seasonNumber]).
  /// Takes 10–60 s. Returns null when Sonarr could not be asked.
  Future<List<SonarrRelease>?> interactiveSearch({
    int? episodeId,
    int? seriesId,
    int? seasonNumber,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/api/v3/release',
        queryParameters: {
          'episodeId': ?episodeId,
          if (episodeId == null && seriesId != null) 'seriesId': seriesId,
          if (episodeId == null && seasonNumber != null) 'seasonNumber': seasonNumber,
        },
        options: Options(receiveTimeout: const Duration(seconds: 150)),
      );
      if (res.statusCode != 200 || res.data is! List) {
        debugPrint('[Sonarr] interactiveSearch HTTP ${res.statusCode}');
        return null;
      }
      return (res.data as List)
          .whereType<Map>()
          .map((m) => SonarrRelease.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[Sonarr] interactiveSearch failed: $e');
      return null;
    }
  }

  Future<SonarrSeries?> _addSeries(
    Map<String, dynamic> lookupResult, {
    bool monitored = false,
  }) async {
    try {
      // The Skyhook lookup carries placeholders (qualityProfileId: 0, no
      // rootFolderPath, seasonFolder: false) that Sonarr rejects — resolve
      // real values from the server first.
      var qualityProfileId =
          (lookupResult['qualityProfileId'] as num?)?.toInt() ?? 0;
      if (qualityProfileId <= 0) {
        final profiles = await _dio.get('$_base/api/v3/qualityprofile');
        if (profiles.statusCode == 200 && profiles.data is List) {
          for (final p in profiles.data as List) {
            if (p is Map && p['name'] == 'HD-1080p') {
              qualityProfileId = (p['id'] as num?)?.toInt() ?? 0;
            }
          }
          if (qualityProfileId <= 0 && (profiles.data as List).isNotEmpty) {
            final first = (profiles.data as List).first;
            if (first is Map) {
              qualityProfileId = (first['id'] as num?)?.toInt() ?? 0;
            }
          }
        }
      }
      String? rootFolderPath = lookupResult['rootFolderPath'] as String?;
      if (rootFolderPath == null || rootFolderPath.isEmpty) {
        final folders = await _dio.get('$_base/api/v3/rootfolder');
        if (folders.statusCode == 200 && folders.data is List) {
          for (final f in folders.data as List) {
            if (f is Map && f['path'] is String) {
              rootFolderPath = f['path'] as String;
              break;
            }
          }
        }
      }
      if (qualityProfileId <= 0 || rootFolderPath == null) {
        debugPrint('[Sonarr] addSeries: no quality profile or root folder');
        return null;
      }
      // Spread FIRST so placeholders inside the lookup result never override
      // the resolved values below.
      final body = {
        ...lookupResult,
        'tvdbId': lookupResult['tvdbId'],
        'tmdbId': lookupResult['tmdbId'],
        'title': lookupResult['title'],
        'titleSlug': lookupResult['titleSlug'],
        'rootFolderPath': rootFolderPath,
        'qualityProfileId': qualityProfileId,
        'languageProfileId': lookupResult['languageProfileId'],
        'monitored': monitored,
        'seasonFolder': true,
        if (!monitored)
          'seasons': [
            for (final s in (lookupResult['seasons'] as List? ?? const []))
              if (s is Map) {...s, 'monitored': false},
          ],
        'addOptions': {
          if (!monitored) 'monitor': 'none',
          'searchForMissingEpisodes': false,
          'searchForCutoffUnmetEpisodes': false,
        },
      };
      final res = await _dio.post('$_base/api/v3/series', data: body);
      if (res.statusCode == 201 && res.data is Map) {
        return SonarrSeries.fromJson(Map<String, dynamic>.from(res.data));
      }
      debugPrint('[Sonarr] addSeries rejected: ${res.statusCode} ${res.data}');
    } catch (e) {
      debugPrint('[Sonarr] addSeries failed: $e');
    }
    return null;
  }

  /// Update the [monitored] flag on the given episode ids.
  Future<bool> setEpisodesMonitored(List<int> episodeIds, bool monitored) async {
    if (episodeIds.isEmpty) return true;
    try {
      final res = await _dio.put(
        '$_base/api/v3/episode/monitor',
        data: {
          'episodeIds': episodeIds,
          'monitored': monitored,
        },
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      debugPrint('[Sonarr] setEpisodesMonitored failed: $e');
      return false;
    }
  }

  /// Trigger an episode search so Sonarr actively looks for the given
  /// monitored episodes on the indexers.
  Future<bool> searchEpisodes(List<int> episodeIds) async {
    if (episodeIds.isEmpty) return true;
    try {
      final res = await _dio.post(
        '$_base/api/v3/command',
        data: {
          'name': 'EpisodeSearch',
          'episodeIds': episodeIds,
        },
      );
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 202;
    } catch (e) {
      debugPrint('[Sonarr] searchEpisodes failed: $e');
      return false;
    }
  }

  /// Tell Sonarr to grab a specific release the user picked in the release
  /// dialog. [guid] is the release guid (Prowlarr hands us the same one
  /// Sonarr queries with) and [indexerId] is the indexer it came from.
  /// Sonarr resolves the guid through its indexer, pushes the torrent to
  /// qBittorrent, and auto-imports the finished files into the library.
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
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 202) {
        return (ok: true, status: res.statusCode, body: null);
      }
      debugPrint(
        '[Sonarr] grabRelease rejected: ${res.statusCode} ${res.data}',
      );
      return (ok: false, status: res.statusCode, body: res.data?.toString());
    } catch (e) {
      debugPrint('[Sonarr] grabRelease failed: $e');
      return (ok: false, status: null, body: e.toString());
    }
  }

  /// Hand a release the Sonarr has never seen to it directly. `/release`
  /// (grab) only knows releases from the Sonarr's own searches and answers
  /// 404 "not in cache" for anything picked from Prowlarr; push makes the
  /// Sonarr download and track it like one of its own.
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
      debugPrint('[Sonarr] pushRelease rejected: $reason');
      return (ok: false, reason: reason);
    } catch (e) {
      debugPrint('[Sonarr] pushRelease failed: $e');
      return (ok: false, reason: e.toString());
    }
  }

  /// Wait until the Sonarr's queue shows a download for [seriesId].
  ///
  /// A grab is not in the queue until the Sonarr next polls the download
  /// client; a search started before that (Seerr does one when a request is
  /// approved) does not see it and grabs a second release.
  Future<bool> waitUntilQueued(int seriesId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await _dio.post('$_base/api/v3/command',
          data: {'name': 'RefreshMonitoredDownloads'});
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final res = await _dio.get('$_base/api/v3/queue/details',
            queryParameters: {'seriesId': seriesId});
        if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
          return true;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('[Sonarr] waitUntilQueued failed: $e');
    }
    return false;
  }

  /// Sonarr's `seasons` list as season number -> monitored.
  static Map<int, bool> seasonMonitoredOf(Object? seasons) => {
        for (final s in (seasons is List ? seasons : const []))
          if (s is Map && s['seasonNumber'] is num)
            (s['seasonNumber'] as num).toInt(): s['monitored'] == true,
      };

  /// The PUT /series/{id} body that turns monitoring of [season] on or off and
  /// changes nothing else. The series counts as monitored while any season
  /// is, and new seasons are never followed on their own.
  @visibleForTesting
  static Map<String, dynamic> seasonMonitorPayload(
    Map<String, dynamic> series,
    int season,
    bool monitored,
  ) {
    final seasons = <Map<String, dynamic>>[
      for (final s in (series['seasons'] as List? ?? const []))
        if (s is Map)
          (s['seasonNumber'] as num?)?.toInt() == season
              ? {...Map<String, dynamic>.from(s), 'monitored': monitored}
              : Map<String, dynamic>.from(s),
    ];
    return {
      ...series,
      'seasons': seasons,
      'monitored': seasons.any((s) => s['monitored'] == true),
      'monitorNewItems': 'none',
    };
  }

  /// Turns Sonarr's monitoring of [season] on or off. Returns the series'
  /// monitoring per season afterwards, or null when Sonarr refused.
  Future<Map<int, bool>?> setSeasonMonitored(
    int seriesId,
    int season,
    bool monitored,
  ) async {
    try {
      final res = await _dio.get('$_base/api/v3/series/$seriesId');
      if (res.statusCode != 200 || res.data is! Map) return null;
      final body = seasonMonitorPayload(
        Map<String, dynamic>.from(res.data as Map),
        season,
        monitored,
      );
      final put = await _dio.put('$_base/api/v3/series/$seriesId', data: body);
      if (put.statusCode != 200 && put.statusCode != 202) {
        debugPrint('[Sonarr] season monitor rejected: ${put.statusCode} ${put.data}');
        return null;
      }
      return seasonMonitoredOf(
        put.data is Map ? (put.data as Map)['seasons'] : body['seasons'],
      );
    } catch (e) {
      debugPrint('[Sonarr] setSeasonMonitored failed: $e');
      return null;
    }
  }

  /// Search for the missing episodes of one season.
  Future<bool> searchSeason(int seriesId, int season) async {
    try {
      final res = await _dio.post(
        '$_base/api/v3/command',
        data: {'name': 'SeasonSearch', 'seriesId': seriesId, 'seasonNumber': season},
      );
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 202;
    } catch (e) {
      debugPrint('[Sonarr] searchSeason failed: $e');
      return false;
    }
  }

  /// Search for all missing episodes in a list of seasons. Used when the
  /// user wants every episode in the season (no per-episode filter).
  Future<bool> searchSeasons(int seriesId, List<int> seasonNumbers) async {
    try {
      final res = await _dio.post(
        '$_base/api/v3/command',
        data: {
          'name': 'SeasonSearch',
          'seriesId': seriesId,
          'seasonNumber': seasonNumbers,
        },
      );
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 202;
    } catch (e) {
      debugPrint('[Sonarr] searchSeasons failed: $e');
      return false;
    }
  }
}
