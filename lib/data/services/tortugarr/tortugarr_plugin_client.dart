import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../../preference/user_preferences.dart';
import '../../../util/app_l10n.dart';
import '../download/bazarr_client.dart' show BazarrCandidate, BazarrSubtitleState;

/// What the server's Tortugarr plugin allows the logged-in user
/// (`GET /Tortugarr/v1/Capabilities`). A server without the plugin, or any
/// error, gives [TortugarrCapabilities.none]: every feature off.
class TortugarrCapabilities {
  final bool isAdmin;
  final bool downloadNow;
  final bool downloads;
  final bool diskSpace;
  final bool videoCheck;
  final bool subtitles;
  final bool deleteTitles;
  final bool missingEpisodes;
  final bool freeSpace;
  final bool adult;

  /// Set for a limited downloader (a non-administrator with download
  /// limits); null for administrators and everyone else.
  final TortugarrUserLimits? limits;

  const TortugarrCapabilities({
    this.isAdmin = false,
    this.downloadNow = false,
    this.downloads = false,
    this.diskSpace = false,
    this.videoCheck = false,
    this.subtitles = false,
    this.deleteTitles = false,
    this.missingEpisodes = false,
    this.freeSpace = false,
    this.adult = false,
    this.limits,
  });

  static const none = TortugarrCapabilities();

  factory TortugarrCapabilities.fromJson(Map<String, dynamic> json) {
    final f = (json['features'] as Map?)?.cast<String, dynamic>() ?? const {};
    bool on(String key) => f[key] == true;
    return TortugarrCapabilities(
      isAdmin: json['isAdmin'] == true,
      downloadNow: on('downloadNow'),
      downloads: on('downloads'),
      diskSpace: on('diskSpace'),
      videoCheck: on('videoCheck'),
      subtitles: on('subtitles'),
      deleteTitles: on('deleteTitles'),
      missingEpisodes: on('missingEpisodes'),
      freeSpace: on('freeSpace'),
      adult: on('adult'),
      limits: json['limits'] is Map
          ? TortugarrUserLimits.fromJson((json['limits'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// A user's download limits and what they used this week (spec 3.16).
/// 0 means no limit for that field.
class TortugarrUserLimits {
  final bool enabled;
  final int maxMovieMb;
  final int maxEpisodeMb;
  final int moviesPerWeek;
  final int episodesPerWeek;
  final int moviesUsed;
  final int episodesUsed;

  const TortugarrUserLimits({
    this.enabled = true,
    this.maxMovieMb = 0,
    this.maxEpisodeMb = 0,
    this.moviesPerWeek = 0,
    this.episodesPerWeek = 0,
    this.moviesUsed = 0,
    this.episodesUsed = 0,
  });

  factory TortugarrUserLimits.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return TortugarrUserLimits(
      enabled: json['enabled'] != false,
      maxMovieMb: n('maxMovieMb'),
      maxEpisodeMb: n('maxEpisodeMb'),
      moviesPerWeek: n('moviesPerWeek'),
      episodesPerWeek: n('episodesPerWeek'),
      moviesUsed: n('moviesUsed'),
      episodesUsed: n('episodesUsed'),
    );
  }

  /// The body of `PUT Users/{id}/Limits`; the used counts are read-only.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'maxMovieMb': maxMovieMb,
        'maxEpisodeMb': maxEpisodeMb,
        'moviesPerWeek': moviesPerWeek,
        'episodesPerWeek': episodesPerWeek,
      };

  /// "This week: 1 of 4 movies, 3 of 5 episodes · max 2.5 GB per movie,
  /// 950 MB per episode" - the parts that have a limit.
  String describe() {
    final l = appL10n();
    final used = [
      if (moviesPerWeek > 0) l.tgLimitMoviesUsed(moviesUsed, moviesPerWeek),
      if (episodesPerWeek > 0) l.tgLimitEpisodesUsed(episodesUsed, episodesPerWeek),
    ];
    final sizes = [
      if (maxMovieMb > 0) l.tgLimitMaxMovie(showMb(maxMovieMb)),
      if (maxEpisodeMb > 0) l.tgLimitMaxEpisode(showMb(maxEpisodeMb)),
    ];
    return [
      if (used.isNotEmpty) l.tgLimitThisWeek(used.join(', ')),
      if (sizes.isNotEmpty) sizes.join(', '),
    ].join(' · ');
  }

  /// 950 MB, 2.5 GB - as the plugin writes it.
  static String showMb(int mb) {
    if (mb < 1024) return '$mb MB';
    final gb = mb / 1024;
    return '${gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB';
  }
}

/// The user's text for a refused download of a limited downloader
/// (`forbidden`, `limit_exceeded`, `quota_exceeded`), or null for other
/// errors.
String? limitErrorText(TortugarrPluginException e) => switch (e.code) {
      'forbidden' => appL10n().tgPluginForbidden,
      'limit_exceeded' => appL10n().tgLimitExceeded(_limitDetail(e.message)),
      'quota_exceeded' => appL10n().tgQuotaExceeded(_quotaDetail(e.message)),
      _ => null,
    };

/// "2.5 GB per movie" from "Over your size limit (2.5 GB per movie)", in the
/// user's language.
String _limitDetail(String message) =>
    (overLimitLabel(message) ?? message).replaceFirst(RegExp(r'^[^(]*\('), '').replaceFirst(RegExp(r'\)$'), '');

/// "4 of 4 movies" from "You have used 4 of 4 movies this week", in the
/// user's language.
String _quotaDetail(String message) {
  final m = RegExp(r'(\d+) of (\d+) (movies|episodes)').firstMatch(message);
  if (m == null) return message;
  final used = int.parse(m.group(1)!), limit = int.parse(m.group(2)!);
  return m.group(3) == 'movies'
      ? appL10n().tgLimitMoviesUsed(used, limit)
      : appL10n().tgLimitEpisodesUsed(used, limit);
}

/// The user's language for a size-limit reason from the plugin ("Over your
/// size limit (2.5 GB per movie)"), or null when [rejection] is another
/// reason.
String? overLimitLabel(String rejection) {
  if (!rejection.startsWith('Over your size limit')) return null;
  final detail = RegExp(r'\((\S+ [GM]B) per (movie|episode)\)').firstMatch(rejection);
  final l = appL10n();
  if (detail == null) return l.tgOverSizeLimitUnknown;
  return detail.group(2) == 'movie'
      ? l.tgOverSizeLimit(l.tgLimitMaxMovie(detail.group(1)!))
      : l.tgOverSizeLimit(l.tgLimitMaxEpisode(detail.group(1)!));
}

/// One release from a plugin search, already filtered and sorted by the
/// plugin (spec section 4).
class TortugarrRelease {
  final String guid;
  final int indexerId;
  final String indexer;
  final String title;
  final int size;
  final int seeders;
  final int leechers;
  final String protocol;
  final String? quality;
  final DateTime? publishDate;
  final bool seasonPack;
  final bool approved;
  final bool recommended;
  final List<String> rejections;

  /// Below the quality minimum, kept because the search asked for SD.
  final bool sd;

  /// Over the searching user's size limit (limited downloaders): shown
  /// greyed and never offered (spec 3.16).
  final bool overLimit;

  const TortugarrRelease({
    required this.guid,
    required this.indexerId,
    required this.indexer,
    required this.title,
    required this.size,
    required this.seeders,
    required this.leechers,
    this.protocol = 'torrent',
    this.quality,
    this.publishDate,
    this.seasonPack = false,
    this.approved = true,
    this.recommended = true,
    this.rejections = const [],
    this.sd = false,
    this.overLimit = false,
  });

  factory TortugarrRelease.fromJson(Map<String, dynamic> json) => TortugarrRelease(
        guid: json['guid'] as String? ?? '',
        indexerId: (json['indexerId'] as num?)?.toInt() ?? 0,
        indexer: json['indexer'] as String? ?? '',
        title: json['title'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        seeders: (json['seeders'] as num?)?.toInt() ?? 0,
        leechers: (json['leechers'] as num?)?.toInt() ?? 0,
        protocol: json['protocol'] as String? ?? 'torrent',
        quality: json['quality'] as String?,
        publishDate: DateTime.tryParse(json['publishDate'] as String? ?? ''),
        seasonPack: json['seasonPack'] == true,
        approved: json['approved'] != false,
        recommended: json['recommended'] != false,
        sd: json['sd'] == true,
        overLimit: json['overLimit'] == true,
        rejections: [
          for (final r in (json['rejections'] as List? ?? const [])) '$r',
        ],
      );
}

/// A finished movie/episode/season search.
class TortugarrSearchResult {
  final String title;
  final int? year;
  final int arrId;
  final int droppedEarly;
  final List<TortugarrRelease> releases;

  /// What the plugin's filters left out, by reason ("below the quality
  /// minimum": 3, ...), so the app can say why a search shows nothing.
  final Map<String, int> dropped;

  /// Indexers switched off after failures right now; their releases are
  /// missing from this search (spec 3.2).
  final List<String> unavailableIndexers;

  const TortugarrSearchResult({
    required this.title,
    this.year,
    required this.arrId,
    this.droppedEarly = 0,
    this.releases = const [],
    this.dropped = const {},
    this.unavailableIndexers = const [],
  });

  /// Releases the search found before the filters.
  int get found => releases.length + droppedEarly + dropped.values.fold(0, (a, b) => a + b);

  /// Everything left out was below the quality minimum (SD): showing SD
  /// releases would bring them back.
  bool get onlySdDropped =>
      releases.isEmpty &&
      droppedEarly == 0 &&
      dropped.isNotEmpty &&
      dropped.keys.every((k) => k.toLowerCase().contains('quality'));

  factory TortugarrSearchResult.fromJson(Map<String, dynamic> json) =>
      TortugarrSearchResult(
        title: json['title'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        arrId: (json['arrId'] as num?)?.toInt() ?? 0,
        droppedEarly: (json['droppedEarly'] as num?)?.toInt() ?? 0,
        unavailableIndexers: [
          for (final n in (json['unavailableIndexers'] as List? ?? const []))
            if ('$n'.isNotEmpty) '$n',
        ],
        dropped: {
          if (json['dropped'] is Map)
            for (final e in (json['dropped'] as Map).entries)
              if (e.value is num && (e.value as num) > 0) '${e.key}': (e.value as num).toInt(),
        },
        releases: [
          for (final r in (json['releases'] as List? ?? const []))
            if (r is Map) TortugarrRelease.fromJson(r.cast<String, dynamic>()),
        ],
      );
}

class TortugarrGrabResult {
  final String? downloadId;
  final String title;
  final bool queued;
  const TortugarrGrabResult({this.downloadId, required this.title, this.queued = false});
}

/// Outcome of the plugin's video check (spec 3.6).
enum TortugarrVideoAction { kept, removed, wait }

class TortugarrVideoCheck {
  final bool? hasVideo;
  final TortugarrVideoAction action;
  final List<String> fileNames;
  const TortugarrVideoCheck(this.hasVideo, this.action, [this.fileNames = const []]);
}

/// The plugin answered with an error (spec section 2). [code] is the
/// plugin's code (`not_admin`, `search_expired`, `upstream_failed`, ...),
/// or `http_<status>` when the body had none.
class TortugarrPluginException implements Exception {
  final int? status;
  final String code;
  final String message;

  /// Extra fields of the error, e.g. `progress` and `category` for
  /// `already_in_client` (spec 3.3).
  final Map<String, dynamic> details;
  const TortugarrPluginException(this.status, this.code, this.message, [this.details = const {}]);

  /// `already_in_client`: how far the existing torrent is (0-1), if given.
  double? get progress => (details['progress'] as num?)?.toDouble();

  @override
  String toString() => message.isEmpty ? code : message;
}

/// Client for the server-side Tortugarr Jellyfin plugin
/// (`{jellyfin}/Tortugarr/v1/...`). It sends only the app's normal Jellyfin
/// session; the *arr keys stay on the server.
class TortugarrPluginClient {
  final Dio _dio;
  final MediaServerClient? _clientOverride;

  TortugarrPluginClient({Dio? dio, MediaServerClient? client})
      : _clientOverride = client,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 90),
              validateStatus: (_) => true,
            ));

  static bool _showSd() =>
      GetIt.instance.isRegistered<UserPreferences>() &&
      GetIt.instance<UserPreferences>().get(UserPreferences.showSdReleases);

  MediaServerClient? get _client =>
      _clientOverride ??
      (GetIt.instance.isRegistered<MediaServerClient>()
          ? GetIt.instance<MediaServerClient>()
          : null);

  String get _base {
    final c = _client;
    if (c == null) throw const TortugarrPluginException(null, 'no_server', 'Not logged in');
    return '${c.baseUrl}/Tortugarr/v1';
  }

  Options get _auth {
    final c = _client;
    final token = c?.accessToken;
    if (c == null || token == null || token.isEmpty) {
      throw const TortugarrPluginException(null, 'no_server', 'Not logged in');
    }
    return Options(headers: {
      'Authorization': buildServerAuthorizationHeader(
        scheme: 'MediaBrowser',
        deviceInfo: c.deviceInfo,
        accessToken: token,
      ),
    });
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    final res = await _dio.request<dynamic>(
      '$_base$path',
      data: body,
      queryParameters: query,
      options: _auth.copyWith(method: method),
    );
    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return res.data;
    final err = res.data is Map ? (res.data as Map)['error'] : null;
    if (err is Map) {
      throw TortugarrPluginException(
        status,
        '${err['code'] ?? 'http_$status'}',
        '${err['message'] ?? ''}',
        err.cast<String, dynamic>(),
      );
    }
    throw TortugarrPluginException(status, 'http_$status', 'Server answered $status');
  }

  /// Provider ids (Tmdb, Tvdb, ...) of a Jellyfin item, e.g. the TVDB id a
  /// series needs for a plugin search. Uses only the Jellyfin session.
  Future<Map<String, String>> jellyfinProviderIds(String itemId) async {
    final c = _client;
    if (c == null) return const {};
    final res = await _dio.get<dynamic>(
      '${c.baseUrl}/Items',
      queryParameters: {'ids': itemId, 'Fields': 'ProviderIds'},
      options: _auth,
    );
    final items = res.data is Map ? res.data['Items'] : null;
    if (res.statusCode != 200 || items is! List || items.isEmpty) return const {};
    final ids = (items.first as Map)['ProviderIds'];
    return ids is Map ? {for (final e in ids.entries) '${e.key}': '${e.value}'} : const {};
  }

  /// The user's capabilities; [TortugarrCapabilities.none] when the plugin
  /// is missing (404) or the server cannot be reached.
  Future<TortugarrCapabilities> capabilities() async {
    try {
      final data = await _send('GET', '/Capabilities');
      if (data is Map) return TortugarrCapabilities.fromJson(data.cast<String, dynamic>());
    } catch (e) {
      debugPrint('[Tortugarr] capabilities unavailable: $e');
    }
    return TortugarrCapabilities.none;
  }

  /// A user's download limits (spec 3.16, administrators).
  Future<TortugarrUserLimits> userLimits(String userId) async {
    final data = await _send('GET', '/Users/$userId/Limits');
    return TortugarrUserLimits.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Saves a user's download limits (spec 3.16, administrators).
  Future<TortugarrUserLimits> setUserLimits(String userId, TortugarrUserLimits limits) async {
    final data = await _send('PUT', '/Users/$userId/Limits', body: limits.toJson());
    return TortugarrUserLimits.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Starts a search and waits for it (spec 3.2). [body] is
  /// `{type: movie, tmdbId}` / `{type: episode, tvdbId, season, episode}` /
  /// `{type: season, tvdbId, season}`.
  Future<TortugarrSearchResult> search(
    Map<String, dynamic> body, {
    bool Function()? isCancelled,
  }) async {
    final job = await _send('POST', '/Searches', body: {
      ...body,
      // The user's "Show SD releases" setting (spec 3.2).
      if (_showSd()) 'allowSd': true,
    }) as Map;
    final path = '/Searches/${job['searchId']}';
    try {
      final result = await _poll(path, job['pollAfterSeconds'], isCancelled: isCancelled);
      return TortugarrSearchResult.fromJson(result);
    } on TortugarrPluginException catch (e) {
      // Let the server stop asking the indexers; an older plugin without the
      // route just answers 404.
      if (e.code == 'cancelled') unawaited(_send('DELETE', path).catchError((_) => null));
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _poll(
    String path,
    Object? pollAfter, {
    bool Function()? isCancelled,
  }) async {
    final every = Duration(seconds: (pollAfter as num?)?.toInt() ?? 2);
    // The server ends a search after 150 s; stop a little later.
    final deadline = DateTime.now().add(const Duration(seconds: 170));
    void checkCancelled() {
      if (isCancelled?.call() ?? false) {
        throw const TortugarrPluginException(null, 'cancelled', 'Search cancelled');
      }
    }

    while (DateTime.now().isBefore(deadline)) {
      // Wait in short steps so a cancel stops the polling at once.
      final next = DateTime.now().add(every);
      while (DateTime.now().isBefore(next)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        checkCancelled();
      }
      final data = (await _send('GET', path) as Map).cast<String, dynamic>();
      switch (data['status']) {
        case 'done':
          return (data['result'] as Map? ?? const {}).cast<String, dynamic>();
        case 'failed':
          final err = (data['error'] as Map? ?? const {}).cast<String, dynamic>();
          throw TortugarrPluginException(
            null,
            '${err['code'] ?? 'failed'}',
            '${err['message'] ?? 'The search failed'}',
            err,
          );
      }
    }
    throw const TortugarrPluginException(null, 'timeout', 'The search took too long');
  }

  /// Grabs a release from the last search (spec 3.3). [type] is `movie`,
  /// `episode` or `season`; [force] takes a soft-rejected release.
  Future<TortugarrGrabResult> grab({
    required String type,
    required int arrId,
    required TortugarrRelease release,
    bool force = false,
  }) async {
    final data = (await _send('POST', '/Grab', body: {
      'type': type,
      'arrId': arrId,
      'guid': release.guid,
      'indexerId': release.indexerId,
      if (force) 'force': true,
    }) as Map)
        .cast<String, dynamic>();
    return TortugarrGrabResult(
      downloadId: data['downloadId'] as String?,
      title: data['title'] as String? ?? release.title,
      queued: data['queued'] == true,
    );
  }

  /// Deletes the Jellyfin item [itemId] through Radarr/Sonarr (spec 3.10):
  /// files, monitoring and Seerr are handled on the server. Returns what was
  /// deleted (`movie`, `episode`, `season`, `series`).
  Future<String> deleteTitle(String itemId) async {
    final data = await _send('DELETE', '/Library/${Uri.encodeComponent(itemId)}');
    return data is Map ? '${data['deleted'] ?? ''}' : '';
  }

  /// Adult library search (spec 3.9): the phrase and each word, ranked on
  /// the server. Returns the search id (needed to grab) and the releases.
  Future<(String, List<TortugarrRelease>, List<String>)> adultSearch(
    String query, {
    bool Function()? isCancelled,
  }) async {
    final job = await _send('POST', '/Adult/Searches', body: {'query': query}) as Map;
    final searchId = '${job['searchId']}';
    final result = await _poll('/Adult/Searches/$searchId', job['pollAfterSeconds'],
        isCancelled: isCancelled);
    return (
      searchId,
      [
        for (final r in (result['releases'] as List? ?? const []))
          if (r is Map) TortugarrRelease.fromJson(r.cast<String, dynamic>()),
      ],
      [for (final n in (result['unavailableIndexers'] as List? ?? const [])) '$n'],
    );
  }

  /// Adds an adult release from [searchId] to the download client; returns
  /// the torrent hash (the download id).
  Future<String?> adultGrab(String searchId, TortugarrRelease release) async {
    final data = await _send('POST', '/Adult/Grab', body: {
      'searchId': searchId,
      'guid': release.guid,
      'indexerId': release.indexerId,
    });
    return data is Map ? data['downloadId'] as String? : null;
  }

  /// Which subtitle languages a title has and which Bazarr still misses
  /// (spec 3.8, State). [target] is `{type: movie, tmdbId}` or
  /// `{type: episode, tvdbId, season, episode}`.
  Future<BazarrSubtitleState> subtitleState(Map<String, Object> target) async {
    final data = await _send('GET', '/Subtitles/State', query: target);
    final map = data is Map ? data : const {};
    Set<String> codes(Object? list) => {for (final c in (list as List? ?? const [])) '$c'};
    return BazarrSubtitleState(have: codes(map['have']), missing: codes(map['missing']));
  }

  /// Lets Bazarr search the [languages] it misses for [target] (spec 3.8,
  /// Search); it only queues the search.
  Future<void> searchSubtitles(Map<String, Object> target, Set<String> languages) async {
    await _send('POST', '/Subtitles/Search', body: {...target, 'languages': languages.toList()});
  }

  /// Every subtitle the providers offer for [target] (spec 3.8).
  Future<List<BazarrCandidate>> subtitleCandidates(Map<String, Object> target) async {
    final data = await _send('GET', '/Subtitles', query: target);
    String flag(Object? v) => v == true ? 'True' : 'False';
    return [
      for (final c in ((data is Map ? data['candidates'] : null) as List? ?? const []))
        if (c is Map)
          BazarrCandidate(
            language: '${c['language'] ?? ''}',
            provider: '${c['provider'] ?? ''}',
            score: (c['score'] as num?)?.toInt() ?? 0,
            release: [for (final r in (c['releaseInfo'] as List? ?? const [])) '$r'].join(' · '),
            subtitleId: '${c['id'] ?? ''}',
            hearingImpaired: flag(c['hearingImpaired']),
            forced: flag(c['forced']),
            originalFormat: flag(c['originalFormat']),
          ),
    ];
  }

  /// Bazarr downloads [candidate] next to the video (spec 3.8).
  Future<void> downloadSubtitle(Map<String, Object> target, BazarrCandidate candidate) async {
    await _send('POST', '/Subtitles', body: {
      ...target,
      'id': candidate.subtitleId,
      'provider': candidate.provider,
      'language': candidate.language,
      'hearingImpaired': candidate.hearingImpaired == 'True',
      'forced': candidate.forced == 'True',
      'originalFormat': candidate.originalFormat == 'True',
    });
  }

  /// Sonarr's view of a series (spec 3.14), or null when Sonarr does not
  /// have it (`inSonarr: false`).
  Future<Map<String, dynamic>?> seriesStatus(int tvdbId) async {
    final data = await _send('GET', '/Series/$tvdbId');
    if (data is! Map || data['inSonarr'] == false) return null;
    return data.cast<String, dynamic>();
  }

  /// Turns a season's monitoring on or off (spec 3.14); adds the series to
  /// Sonarr unmonitored first when needed. Returns the monitoring per season.
  Future<({Map<int, bool> seasons, bool searchQueued, String? message})> setSeasonMonitoring(
    int tvdbId,
    int season, {
    required bool monitored,
    bool search = false,
  }) async {
    final data = (await _send('PUT', '/Series/$tvdbId/Seasons/$season',
            body: {'monitored': monitored, 'search': search}) as Map)
        .cast<String, dynamic>();
    return (
      seasons: seasonMonitoringOf(data['seasonMonitoring']),
      searchQueued: data['searchQueued'] == true,
      message: data['message'] as String?,
    );
  }

  /// `{"1": true}` → `{1: true}`.
  static Map<int, bool> seasonMonitoringOf(Object? raw) => {
        if (raw is Map)
          for (final e in raw.entries)
            if (int.tryParse('${e.key}') != null) int.parse('${e.key}'): e.value == true,
      };

  /// Free space and what is still downloading (spec 3.15, Space/Check).
  Future<Map<String, dynamic>> spaceCheck(int bytes) async =>
      ((await _send('GET', '/Space/Check', query: {'bytes': bytes})) as Map).cast<String, dynamic>();

  /// Duplicates and library titles that could go (spec 3.15); the app
  /// applies its own staleness rules and order.
  Future<Map<String, dynamic>> spaceCandidates() async =>
      ((await _send('GET', '/Space/Candidates')) as Map).cast<String, dynamic>();

  /// Removes an imported duplicate torrent with its files (spec 3.15).
  Future<void> deleteDuplicate(String hash) async {
    await _send('DELETE', '/Space/Duplicates/${Uri.encodeComponent(hash)}');
  }

  /// Removes a download from Radarr's/Sonarr's queue and from the download
  /// client, with its files (spec 3.5).
  Future<void> removeDownload(String downloadId) async {
    await _send('DELETE', '/Downloads/${Uri.encodeComponent(downloadId)}');
  }

  /// What Radarr and Sonarr are downloading, with the bytes left taken from
  /// qBittorrent itself (spec 3.4).
  Future<List<TortugarrQueueItem>> downloadQueue() async {
    final data = await _send('GET', '/Downloads');
    final items = data is Map ? data['items'] : null;
    return [
      for (final i in (items is List ? items : const []))
        if (i is Map && i['downloadId'] is String && i['kind'] != 'adult')
          TortugarrQueueItem.fromJson(i.cast<String, dynamic>()),
    ];
  }

  /// Video check of a download (spec 3.6).
  Future<TortugarrVideoCheck> checkVideo(String downloadId) async {
    final data = (await _send('POST', '/Downloads/${Uri.encodeComponent(downloadId)}/Check') as Map)
        .cast<String, dynamic>();
    final action = switch (data['action']) {
      'removed' => TortugarrVideoAction.removed,
      'kept' => TortugarrVideoAction.kept,
      _ => TortugarrVideoAction.wait,
    };
    return TortugarrVideoCheck(data['hasVideo'] as bool?, action, [
      for (final f in (data['files'] as List? ?? const []))
        if (f is Map) '${f['name']}',
    ]);
  }

  /// Polls [checkVideo] until the torrent's file list is known (about
  /// [timeout]), then returns the final outcome.
  Future<TortugarrVideoCheck> watchVideo(
    String downloadId, {
    Duration every = const Duration(seconds: 10),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final check = await checkVideo(downloadId);
      if (check.action != TortugarrVideoAction.wait || DateTime.now().isAfter(deadline)) {
        return check;
      }
      await Future<void>.delayed(every);
    }
  }
}

/// One download in Radarr's or Sonarr's queue (spec 3.4).
class TortugarrQueueItem {
  const TortugarrQueueItem({
    required this.downloadId,
    required this.kind,
    this.name,
    this.tmdbId,
    this.tvdbId,
    this.size = 0,
    this.sizeLeft = 0,
  });

  factory TortugarrQueueItem.fromJson(Map<String, dynamic> j) {
    final left = (j['sizeLeft'] as num?)?.toInt() ?? 0;
    final progress = (j['progress'] as num?)?.toDouble() ?? 0;
    // A plugin before 1.2.3.0 sends no size; work it out from the progress.
    final size = (j['size'] as num?)?.toInt() ??
        (progress < 1 ? (left / (1 - progress)).round() : left);
    return TortugarrQueueItem(
      downloadId: (j['downloadId'] as String).toUpperCase(),
      kind: '${j['kind']}',
      name: (j['name'] ?? j['title']) as String?,
      tmdbId: (j['tmdbId'] as num?)?.toInt(),
      tvdbId: (j['tvdbId'] as num?)?.toInt(),
      size: size,
      sizeLeft: left,
    );
  }

  /// The download client's id, upper case.
  final String downloadId;

  /// 'movie' or 'episode'.
  final String kind;

  /// The movie's or series' title.
  final String? name;
  final int? tmdbId;
  final int? tvdbId;
  final int size;
  final int sizeLeft;
}
