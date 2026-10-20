import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../../models/aggregated_item.dart';
import '../subtitle_backend.dart';
import 'download_now_service.dart' show DownloadNowConfig;
import 'package:moonfin/util/app_l10n.dart';

/// The languages Bazarr's profile asks for, in the order they are shown.
const bazarrWantedLanguages = [('no', 'Norsk'), ('en', 'Engelsk')];

/// What Bazarr calls a title: a Radarr movie, or a Sonarr episode.
class BazarrTarget {
  final int? radarrId;
  final int? seriesId;
  final int? episodeId;

  const BazarrTarget.movie(int this.radarrId)
      : seriesId = null,
        episodeId = null;
  const BazarrTarget.episode({required int this.seriesId, required int this.episodeId})
      : radarrId = null;

  bool get isMovie => radarrId != null;
}

/// Which languages a title has subtitles for, and which Bazarr still misses.
class BazarrSubtitleState {
  final Set<String> have;
  final Set<String> missing;

  const BazarrSubtitleState({required this.have, required this.missing});
}

/// One subtitle a provider offers in a manual search.
class BazarrCandidate {
  final String language;
  final String provider;
  final int score;
  final String release;
  final String subtitleId;
  final String hearingImpaired;
  final String forced;
  final String originalFormat;

  const BazarrCandidate({
    required this.language,
    required this.provider,
    required this.score,
    required this.release,
    required this.subtitleId,
    required this.hearingImpaired,
    required this.forced,
    required this.originalFormat,
  });
}

class BazarrException implements Exception {
  final String message;
  const BazarrException(this.message);
  @override
  String toString() => message;
}

/// Finds subtitles for one movie or episode through Bazarr.
///
/// Bazarr already looks for Norwegian and English subtitles on its own once
/// a day; this lets the user ask right away, or pick one by hand when the
/// automatic match is missing or wrong. Bazarr refreshes the Jellyfin item
/// itself after a download, so the new track shows up in the subtitle menu.
class BazarrSubtitleService implements SubtitleBackend<BazarrTarget> {
  final Dio _dio;

  BazarrSubtitleService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              // A manual search asks every provider and can take a minute.
              receiveTimeout: const Duration(seconds: 120),
              validateStatus: (_) => true,
            ));

  static bool get isConfigured =>
      DownloadNowConfig.bazarrBaseUrl.isNotEmpty &&
      DownloadNowConfig.bazarrApiKey.isNotEmpty;

  /// The Bazarr ids for [item], or null when Radarr/Sonarr do not manage it
  /// (Bazarr only knows what they know).
  @override
  Future<BazarrTarget?> resolve(AggregatedItem item) async {
    switch (item.type) {
      case 'Movie':
        final tmdb = int.tryParse(item.providerIds['Tmdb'] ?? '');
        if (tmdb == null) return null;
        final movies = await _arrGet(_radarr, '/api/v3/movie', {'tmdbId': tmdb});
        final id = radarrIdFor(movies, tmdb);
        return id == null ? null : BazarrTarget.movie(id);
      case 'Episode':
        final season = item.parentIndexNumber;
        final episode = item.indexNumber;
        final seriesItemId = item.seriesId;
        if (season == null || episode == null || seriesItemId == null) return null;
        final tvdb = int.tryParse((await _jellyfinProviderIds(seriesItemId))['Tvdb'] ?? '');
        if (tvdb == null) return null;
        final series = await _arrGet(_sonarr, '/api/v3/series', {'tvdbId': tvdb});
        final seriesId = sonarrSeriesIdFor(series, tvdb);
        if (seriesId == null) return null;
        final episodes = await _arrGet(_sonarr, '/api/v3/episode',
            {'seriesId': seriesId, 'seasonNumber': season});
        final episodeId = sonarrEpisodeIdFor(episodes, season, episode);
        return episodeId == null
            ? null
            : BazarrTarget.episode(seriesId: seriesId, episodeId: episodeId);
      default:
        return null;
    }
  }

  @override
  Future<BazarrSubtitleState> state(BazarrTarget target) async {
    final data = target.isMovie
        ? await _get('/api/movies', {'radarrid[]': target.radarrId})
        : await _get('/api/episodes', {'episodeid[]': target.episodeId});
    final state = parseState(data);
    if (state == null) {
      throw BazarrException(appL10n().tgBazarrUnknownTitle);
    }
    return state;
  }

  /// Lets Bazarr pick the best match for each missing language. Returns the
  /// state afterwards so the caller can tell what was found.
  ///
  /// Bazarr only queues the search and answers at once, so this polls the
  /// state until every language is found, the result has settled, or
  /// [timeout] runs out.
  @override
  Future<BazarrSubtitleState> searchMissing(
    BazarrTarget target,
    Iterable<String> languages, {
    Duration timeout = const Duration(seconds: 75),
    Duration pollEvery = const Duration(seconds: 4),
  }) async {
    final wanted = languages.toSet();
    for (final language in wanted) {
      final query = <String, dynamic>{
        if (target.isMovie) 'radarrid': target.radarrId,
        if (!target.isMovie) 'seriesid': target.seriesId,
        if (!target.isMovie) 'episodeid': target.episodeId,
        'language': language,
        'forced': 'false',
        'hi': 'false',
      };
      final res = await _dio.patch(
        '$_base/api/${target.isMovie ? 'movies' : 'episodes'}/subtitles',
        queryParameters: query,
        options: _auth,
      );
      _check(res);
    }
    return _waitForSearch(target, wanted, timeout, pollEvery);
  }

  Future<BazarrSubtitleState> _waitForSearch(
    BazarrTarget target,
    Set<String> wanted,
    Duration timeout,
    Duration pollEvery,
  ) async {
    final deadline = DateTime.now().add(timeout);
    var latest = await state(target);
    // Once something has been found, a few unchanged polls in a row mean the
    // remaining languages were not found this time.
    var unchanged = 0;
    while (DateTime.now().isBefore(deadline)) {
      final stillMissing = latest.missing.intersection(wanted);
      if (stillMissing.isEmpty) break;
      if (stillMissing.length < wanted.length && unchanged >= 3) break;
      await Future<void>.delayed(pollEvery);
      final next = await state(target);
      unchanged = setEquals(next.missing, latest.missing) ? unchanged + 1 : 0;
      latest = next;
    }
    return latest;
  }

  /// Every subtitle the providers offer, best match first.
  @override
  Future<List<BazarrCandidate>> candidates(BazarrTarget target) async {
    final data = target.isMovie
        ? await _get('/api/providers/movies', {'radarrid': target.radarrId})
        : await _get('/api/providers/episodes', {'episodeid': target.episodeId});
    return parseCandidates(data);
  }

  @override
  Future<void> download(BazarrTarget target, BazarrCandidate candidate) async {
    final res = await _dio.post(
      '$_base/api/providers/${target.isMovie ? 'movies' : 'episodes'}',
      queryParameters: {
        if (target.isMovie) 'radarrid': target.radarrId,
        if (!target.isMovie) 'seriesid': target.seriesId,
        if (!target.isMovie) 'episodeid': target.episodeId,
        'hi': candidate.hearingImpaired,
        'forced': candidate.forced,
        'original_format': candidate.originalFormat,
        'provider': candidate.provider,
        'subtitle': candidate.subtitleId,
      },
      options: _auth,
    );
    _check(res);
  }

  // ------------------------------------------------------------- parsing

  @visibleForTesting
  static int? radarrIdFor(dynamic movies, int tmdb) {
    if (movies is! List) return null;
    for (final m in movies.whereType<Map>()) {
      if (m['tmdbId'] == tmdb) return (m['id'] as num?)?.toInt();
    }
    return null;
  }

  @visibleForTesting
  static int? sonarrSeriesIdFor(dynamic series, int tvdb) {
    if (series is! List) return null;
    for (final s in series.whereType<Map>()) {
      if (s['tvdbId'] == tvdb) return (s['id'] as num?)?.toInt();
    }
    return null;
  }

  @visibleForTesting
  static int? sonarrEpisodeIdFor(dynamic episodes, int season, int episode) {
    if (episodes is! List) return null;
    for (final e in episodes.whereType<Map>()) {
      if (e['seasonNumber'] == season && e['episodeNumber'] == episode) {
        return (e['id'] as num?)?.toInt();
      }
    }
    return null;
  }

  @visibleForTesting
  static BazarrSubtitleState? parseState(dynamic body) {
    final list = body is Map ? body['data'] : null;
    if (list is! List || list.isEmpty || list.first is! Map) return null;
    final item = list.first as Map;
    Set<String> codes(dynamic subs) => {
          if (subs is List)
            for (final s in subs.whereType<Map>())
              if (s['code2'] is String && s['forced'] != true) s['code2'] as String,
        };
    return BazarrSubtitleState(
      have: codes(item['subtitles']),
      missing: codes(item['missing_subtitles']),
    );
  }

  @visibleForTesting
  static List<BazarrCandidate> parseCandidates(dynamic body) {
    final list = body is Map ? body['data'] : null;
    if (list is! List) return const [];
    final out = <BazarrCandidate>[];
    for (final c in list.whereType<Map>()) {
      final id = c['subtitle'];
      final provider = c['provider'];
      if (id is! String || provider is! String) continue;
      final release = c['release_info'];
      out.add(BazarrCandidate(
        language: '${c['language'] ?? ''}',
        provider: provider,
        score: (c['score'] as num?)?.toInt() ?? 0,
        release: release is List && release.isNotEmpty ? '${release.first}' : '',
        subtitleId: id,
        hearingImpaired: '${c['hearing_impaired'] ?? 'False'}',
        forced: '${c['forced'] ?? 'False'}',
        originalFormat: '${c['original_format'] ?? 'False'}',
      ));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  // ------------------------------------------------------------- helpers

  String get _base => DownloadNowConfig.bazarrBaseUrl;
  Options get _auth => Options(headers: {'X-API-KEY': DownloadNowConfig.bazarrApiKey});

  ({String base, String key}) get _radarr =>
      (base: DownloadNowConfig.radarrBaseUrl, key: DownloadNowConfig.radarrApiKey);
  ({String base, String key}) get _sonarr =>
      (base: DownloadNowConfig.sonarrBaseUrl, key: DownloadNowConfig.sonarrApiKey);

  void _check(Response res) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    debugPrint('[Bazarr] ${res.requestOptions.path} HTTP $code ${res.data}');
    throw BazarrException(code == 404
        ? appL10n().tgBazarrUnknownTitle
        : appL10n().tgBazarrError(code));
  }

  Future<dynamic> _get(String path, Map<String, dynamic> query) async {
    final res = await _dio.get('$_base$path', queryParameters: query, options: _auth);
    _check(res);
    return res.data;
  }

  Future<dynamic> _arrGet(
    ({String base, String key}) arr,
    String path,
    Map<String, dynamic> query,
  ) async {
    final res = await _dio.get('${arr.base}$path',
        queryParameters: query, options: Options(headers: {'X-Api-Key': arr.key}));
    return res.statusCode == 200 ? res.data : null;
  }

  Future<Map<String, String>> _jellyfinProviderIds(String itemId) async {
    final client = GetIt.instance<MediaServerClient>();
    final res = await _dio.get(
      '${client.baseUrl}/Items',
      queryParameters: {'ids': itemId, 'Fields': 'ProviderIds'},
      options: Options(headers: {
        // Jellyfin 12 only accepts this header form.
        'Authorization': 'MediaBrowser Token="${client.accessToken}"',
      }),
    );
    final items = res.data is Map ? res.data['Items'] : null;
    if (res.statusCode != 200 || items is! List || items.isEmpty) return const {};
    final ids = (items.first as Map)['ProviderIds'];
    return ids is Map ? {for (final e in ids.entries) '${e.key}': '${e.value}'} : const {};
  }
}
