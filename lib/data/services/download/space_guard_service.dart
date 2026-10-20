import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../../../ui/navigation/home_refresh_bus.dart';
import '../tortugarr/download_features.dart';
import '../tortugarr/tortugarr_plugin_client.dart';
import 'download_now_service.dart' show DownloadNowConfig;

/// Tuning for the space guard. Kept together so the numbers the user sees in
/// the dialog ("needs 2x", "10 GB buffer") have one source of truth.
class SpaceGuardConfig {
  /// Head room left on the download disk after everything has landed.
  static const int bufferBytes = 10 * _gb;

  /// How many times a download ends up on the disk. Hardlinks do not work on
  /// these drvfs mounts, but qBittorrent stops at 100% and Radarr/Sonarr
  /// remove completed downloads, so the import is a move: once.
  static const int importCopyFactor = 1;

  /// Never suggest a title added more recently than this.
  static const Duration protectAddedWithin = Duration(days: 30);

  /// A watched title is only suggested when nobody has played it for this long.
  static const Duration watchedStaleAfter = Duration(days: 180);

  /// Container mount points of the *arrs that are not `/media/Windows<X>`, and
  /// the Windows drive they live on (see compose: /mnt/h/Movies -> /movies).
  static const Map<String, String> arrMountDrives = {
    '/movies': 'H',
    '/tv': 'H',
    '/downloads': 'H',
  };

  /// qBittorrent categories Radarr/Sonarr import from. Only torrents in these
  /// categories are ever offered as duplicates.
  static const Set<String> arrCategories = {
    DownloadNowConfig.qbittorrentMovieCategory,
    DownloadNowConfig.qbittorrentTvCategory,
  };
}

const int _gb = 1024 * 1024 * 1024;

enum SpaceCandidateKind { duplicate, movie, series }

/// One thing the user could delete to make room.
class SpaceCandidate {
  final SpaceCandidateKind kind;
  final String title;
  final int? year;
  final int bytes;
  final DateTime? lastPlayed;
  final DateTime? added;

  /// Radarr movie id / Sonarr series id. Unused for duplicates.
  final int arrId;

  /// qBittorrent info hash. Only set for duplicates.
  final String? hash;

  /// Jellyfin item id; the public build deletes titles by it on the plugin.
  final String? jellyfinId;

  const SpaceCandidate({
    required this.kind,
    required this.title,
    required this.bytes,
    this.year,
    this.lastPlayed,
    this.added,
    this.arrId = 0,
    this.hash,
    this.jellyfinId,
  });

  String get key => switch (kind) {
        SpaceCandidateKind.duplicate => 'dup:$hash',
        SpaceCandidateKind.movie => 'movie:$arrId',
        SpaceCandidateKind.series => 'series:$arrId',
      };

  /// The last time anyone cared about this title: played, else added.
  DateTime? get lastActivity => lastPlayed ?? added;
}

/// Free space on the disk qBittorrent downloads to, and what is already
/// promised to torrents that are still running.
class SpaceCheck {
  final String drive;
  final int freeBytes;
  final int pendingBytes;
  final int releaseBytes;

  const SpaceCheck({
    required this.drive,
    required this.freeBytes,
    required this.pendingBytes,
    required this.releaseBytes,
  });

  /// What the new download will occupy once imported, plus the buffer.
  int get neededBytes => releaseBytes > 0
      ? releaseBytes * SpaceGuardConfig.importCopyFactor +
          SpaceGuardConfig.bufferBytes
      : 0;

  int get shortfallBytes =>
      math.max(0, neededBytes + pendingBytes - freeBytes);
}

class SpaceDeleteResult {
  final int deleted;
  final List<String> failed;
  const SpaceDeleteResult({required this.deleted, required this.failed});
}

/// Finds out whether a download fits on the download disk and, when it does
/// not, which titles could go to make room.
///
/// Every source is best effort: [check] returns null when qBittorrent cannot
/// be reached, and a failing Radarr/Sonarr/Jellyfin just contributes no
/// candidates. Movies and series are only suggested when Jellyfin could tell
/// us what has been watched — without that we cannot judge what is safe.
class SpaceGuardService {
  final Dio _dio;
  String? _qbCookie;

  /// Jellyfin connection for tests; the app uses the signed-in client.
  final String? _jellyfinBaseUrl;
  final String? _jellyfinToken;

  SpaceGuardService({
    Dio? dio,
    @visibleForTesting String? jellyfinBaseUrl,
    @visibleForTesting String? jellyfinToken,
  })  : _jellyfinBaseUrl = jellyfinBaseUrl,
        _jellyfinToken = jellyfinToken,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
              validateStatus: (_) => true,
            ));

  // ---------------------------------------------------------------- space

  Future<SpaceCheck?> check({int releaseBytes = 0}) async {
    if (DownloadFeatures.viaPlugin) return _checkViaPlugin(releaseBytes);
    try {
      final main = await _qbGet('/api/v2/sync/maindata');
      final state = main is Map ? main['server_state'] : null;
      final free = state is Map ? (state['free_space_on_disk'] as num?) : null;
      if (free == null) return null;

      final torrents = await _qbGet('/api/v2/torrents/info');
      var pending = 0;
      if (torrents is List) {
        for (final t in torrents.whereType<Map>()) {
          final progress = (t['progress'] as num?)?.toDouble() ?? 1;
          final st = (t['state'] as String?) ?? '';
          if (progress >= 1 || _qbInactiveStates.contains(st)) continue;
          pending += (t['amount_left'] as num?)?.toInt() ?? 0;
        }
      }
      return SpaceCheck(
        drive: await _downloadDrive(),
        freeBytes: free.toInt(),
        pendingBytes: pending,
        releaseBytes: releaseBytes,
      );
    } catch (e) {
      debugPrint('[SpaceGuard] check failed: $e');
      return null;
    }
  }

  static const _qbInactiveStates = {
    'pausedDL',
    'stoppedDL',
    'error',
    'missingFiles',
  };

  Future<String> _downloadDrive() async {
    final path = await _qbGet('/api/v2/app/defaultSavePath');
    return _windowsDrive(path?.toString()) ?? 'H';
  }

  static String? _windowsDrive(String? path) {
    final m = RegExp(r'^([A-Za-z]):').firstMatch(path?.trim() ?? '');
    return m?.group(1)!.toUpperCase();
  }

  /// Which Windows drive a Radarr/Sonarr container path lives on.
  @visibleForTesting
  static String? driveOfArrPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final m = RegExp(r'^/media/Windows([A-Za-z])(/|$)').firstMatch(path);
    if (m != null) return m.group(1)!.toUpperCase();
    for (final e in SpaceGuardConfig.arrMountDrives.entries) {
      if (path == e.key || path.startsWith('${e.key}/')) return e.value;
    }
    return null;
  }

  // ----------------------------------------------------------- candidates

  /// Everything that could be deleted on [drive], best candidates first:
  /// imported duplicates (they cost nothing), then movies and series by how
  /// long nobody has touched them.
  Future<List<SpaceCandidate>> candidates({required String drive}) async {
    if (DownloadFeatures.viaPlugin) return _candidatesViaPlugin();
    final now = DateTime.now().toUtc();
    final results = await Future.wait([
      _duplicates(drive).catchError((Object e) {
        debugPrint('[SpaceGuard] duplicates failed: $e');
        return <SpaceCandidate>[];
      }),
      _library(drive, now).catchError((Object e) {
        debugPrint('[SpaceGuard] library failed: $e');
        return <SpaceCandidate>[];
      }),
    ]);
    final dupes = [...results[0]]
      ..sort((a, b) => _compareDates(a.added, b.added));
    final library = [...results[1]]
      ..sort((a, b) => _compareDates(a.lastActivity, b.lastActivity));
    return [...dupes, ...library];
  }

  // ------------------------------------------------- public build (plugin)

  /// The drive label the dialog shows; the server's download disk has no
  /// Windows drive letter in the public build.
  static const _serverDrive = 'Server';

  Future<SpaceCheck?> _checkViaPlugin(int releaseBytes) async {
    try {
      final data = await TortugarrPluginClient().spaceCheck(releaseBytes);
      final free = (data['freeBytes'] as num?)?.toInt();
      if (free == null) return null;
      return SpaceCheck(
        drive: _serverDrive,
        freeBytes: free,
        pendingBytes: (data['pendingBytes'] as num?)?.toInt() ?? 0,
        releaseBytes: releaseBytes,
      );
    } catch (e) {
      // Never block a download on a failed check (as the private build).
      debugPrint('[SpaceGuard] plugin check failed: $e');
      return null;
    }
  }

  /// The plugin supplies the data; the staleness rules, the favorite
  /// exclusion and the order are the same as [candidates] above.
  Future<List<SpaceCandidate>> _candidatesViaPlugin() async {
    final now = DateTime.now().toUtc();
    final data = await TortugarrPluginClient().spaceCandidates();
    DateTime? date(Object? v) => DateTime.tryParse('${v ?? ''}');
    final dupes = [
      for (final d in (data['duplicates'] as List? ?? const []).whereType<Map>())
        SpaceCandidate(
          kind: SpaceCandidateKind.duplicate,
          title: '${d['name'] ?? ''}',
          bytes: (d['bytes'] as num?)?.toInt() ?? 0,
          added: date(d['added']),
          hash: d['hash'] as String?,
        ),
    ]..sort((a, b) => _compareDates(a.added, b.added));
    final library = <SpaceCandidate>[];
    for (final t in (data['titles'] as List? ?? const []).whereType<Map>()) {
      if (t['favorite'] == true || t['jellyfinId'] == null) continue;
      final c = SpaceCandidate(
        kind: t['kind'] == 'series' ? SpaceCandidateKind.series : SpaceCandidateKind.movie,
        title: '${t['title'] ?? ''}',
        year: (t['year'] as num?)?.toInt(),
        bytes: (t['bytes'] as num?)?.toInt() ?? 0,
        lastPlayed: date(t['lastPlayed']),
        added: date(t['added']),
        arrId: (t['arrId'] as num?)?.toInt() ?? 0,
        jellyfinId: t['jellyfinId'] as String?,
      );
      if (_isStale(c, now)) library.add(c);
    }
    library.sort((a, b) => _compareDates(a.lastActivity, b.lastActivity));
    return [...dupes, ...library];
  }

  Future<bool> _deleteViaPlugin(SpaceCandidate c) async {
    final plugin = TortugarrPluginClient();
    switch (c.kind) {
      case SpaceCandidateKind.duplicate:
        await plugin.deleteDuplicate(c.hash!);
        return true;
      case SpaceCandidateKind.movie:
      case SpaceCandidateKind.series:
        final id = c.jellyfinId;
        if (id == null) return false;
        await plugin.deleteTitle(id);
        return true;
    }
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  Future<List<SpaceCandidate>> _duplicates(String drive) async {
    final imported = <String, String?>{
      ...await _importedHashes(
        DownloadNowConfig.radarrBaseUrl,
        DownloadNowConfig.radarrApiKey,
        {'includeMovie': true},
      ),
      ...await _importedHashes(
        DownloadNowConfig.sonarrBaseUrl,
        DownloadNowConfig.sonarrApiKey,
        {'includeSeries': true, 'includeEpisode': true},
      ),
    };
    if (imported.isEmpty) return const [];

    final savePath = (await _qbGet('/api/v2/app/defaultSavePath'))
        ?.toString()
        .toLowerCase();
    final torrents = await _qbGet('/api/v2/torrents/info');
    if (torrents is! List || savePath == null || savePath.isEmpty) {
      return const [];
    }
    final out = <SpaceCandidate>[];
    for (final t in torrents.whereType<Map>()) {
      final hash = (t['hash'] as String?)?.toLowerCase();
      final category = t['category'] as String? ?? '';
      final content = (t['content_path'] as String? ?? '').toLowerCase();
      final progress = (t['progress'] as num?)?.toDouble() ?? 0;
      // Only finished torrents Radarr/Sonarr already imported, and only when
      // the files sit inside the downloads folder — a torrent seeding straight
      // from the library would take the library copy with it.
      if (hash == null ||
          progress < 1 ||
          !imported.containsKey(hash) ||
          !SpaceGuardConfig.arrCategories.contains(category) ||
          !content.startsWith(savePath) ||
          _windowsDrive(content) != drive) {
        continue;
      }
      final completed = (t['completion_on'] as num?)?.toInt() ?? 0;
      out.add(SpaceCandidate(
        kind: SpaceCandidateKind.duplicate,
        title: imported[hash] ?? t['name'] as String? ?? hash,
        bytes: (t['size'] as num?)?.toInt() ?? 0,
        added: completed > 0
            ? DateTime.fromMillisecondsSinceEpoch(completed * 1000, isUtc: true)
            : null,
        hash: hash,
      ));
    }
    return out;
  }

  /// Download ids (torrent hashes) Radarr/Sonarr imported, mapped to the
  /// library title they became, so the user sees "Kraken (2026)" rather than
  /// a release name.
  Future<Map<String, String?>> _importedHashes(
    String base,
    String key,
    Map<String, dynamic> include,
  ) async {
    // eventType 3 = downloadFolderImported in both Radarr and Sonarr.
    final res = await _dio.get(
      '$base/api/v3/history',
      queryParameters: {'eventType': 3, 'pageSize': 5000, ...include},
      options: Options(headers: {'X-Api-Key': key}),
    );
    final records = res.data is Map ? res.data['records'] : null;
    if (res.statusCode != 200 || records is! List) return const {};
    final out = <String, String?>{};
    for (final r in records.whereType<Map>()) {
      final id = (r['downloadId'] as String?)?.toLowerCase();
      if (id == null || id.isEmpty) continue;
      out[id] ??= _libraryTitle(r);
    }
    return out;
  }

  static String? _libraryTitle(Map record) {
    final movie = record['movie'];
    if (movie is Map && movie['title'] is String) {
      final year = movie['year'];
      return year is num && year > 0
          ? '${movie['title']} ($year)'
          : movie['title'] as String;
    }
    final series = record['series'];
    if (series is Map && series['title'] is String) {
      final ep = record['episode'];
      if (ep is Map && ep['seasonNumber'] is num && ep['episodeNumber'] is num) {
        String two(Object n) => n.toString().padLeft(2, '0');
        return '${series['title']} · '
            'S${two(ep['seasonNumber'])}E${two(ep['episodeNumber'])}';
      }
      return series['title'] as String;
    }
    return null;
  }

  Future<List<SpaceCandidate>> _library(String drive, DateTime now) async {
    final watch = await _JellyfinWatchData.load(
      baseUrl: _jellyfinBaseUrl,
      token: _jellyfinToken,
    );
    if (watch == null) return const [];

    final out = <SpaceCandidate>[];

    final movies = await _dio.get(
      '${DownloadNowConfig.radarrBaseUrl}/api/v3/movie',
      options: Options(headers: {'X-Api-Key': DownloadNowConfig.radarrApiKey}),
    );
    if (movies.statusCode == 200 && movies.data is List) {
      for (final m in (movies.data as List).whereType<Map>()) {
        final file = m['movieFile'];
        if (m['hasFile'] != true || file is! Map) continue;
        if (driveOfArrPath(m['path'] as String?) != drive) continue;
        final w = watch.movies['${m['tmdbId']}'];
        if (w == null) continue; // not in Jellyfin (yet) — cannot judge
        final c = SpaceCandidate(
          kind: SpaceCandidateKind.movie,
          title: m['title'] as String? ?? '',
          year: (m['year'] as num?)?.toInt(),
          bytes: (file['size'] as num?)?.toInt() ?? 0,
          lastPlayed: w.lastPlayed,
          added: DateTime.tryParse(file['dateAdded'] as String? ?? ''),
          arrId: (m['id'] as num).toInt(),
        );
        if (!w.favorite && _isStale(c, now)) out.add(c);
      }
    }

    final series = await _dio.get(
      '${DownloadNowConfig.sonarrBaseUrl}/api/v3/series',
      options: Options(headers: {'X-Api-Key': DownloadNowConfig.sonarrApiKey}),
    );
    if (series.statusCode == 200 && series.data is List) {
      for (final s in (series.data as List).whereType<Map>()) {
        final stats = s['statistics'];
        final size = stats is Map ? (stats['sizeOnDisk'] as num?)?.toInt() : 0;
        if (size == null || size <= 0) continue;
        if (driveOfArrPath(s['path'] as String?) != drive) continue;
        final w = watch.series['tvdb:${s['tvdbId']}'] ??
            watch.series['tmdb:${s['tmdbId']}'];
        if (w == null) continue;
        final c = SpaceCandidate(
          kind: SpaceCandidateKind.series,
          title: s['title'] as String? ?? '',
          year: (s['year'] as num?)?.toInt(),
          bytes: size,
          lastPlayed: w.lastPlayed,
          added: DateTime.tryParse(s['added'] as String? ?? ''),
          arrId: (s['id'] as num).toInt(),
        );
        if (!w.favorite && _isStale(c, now)) out.add(c);
      }
    }
    return out;
  }

  /// Never watched and not new, or watched but not for a long time.
  static bool _isStale(SpaceCandidate c, DateTime now) {
    if (c.bytes <= 0) return false;
    final played = c.lastPlayed;
    if (played != null) {
      return now.difference(played) > SpaceGuardConfig.watchedStaleAfter;
    }
    final added = c.added;
    return added != null &&
        now.difference(added) > SpaceGuardConfig.protectAddedWithin;
  }

  // ------------------------------------------------------------- deleting

  /// Delete [items] one by one. Movies and series go through Radarr/Sonarr so
  /// they stop tracking them (a monitored title with a missing file would be
  /// downloaded again); duplicates are removed from qBittorrent with files.
  Future<SpaceDeleteResult> delete(
    List<SpaceCandidate> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    var deleted = 0;
    final failed = <String>[];
    for (var i = 0; i < items.length; i++) {
      onProgress?.call(i, items.length);
      final c = items[i];
      bool ok;
      try {
        if (DownloadFeatures.viaPlugin) {
          ok = await _deleteViaPlugin(c);
        } else {
          ok = switch (c.kind) {
            SpaceCandidateKind.duplicate => await _deleteTorrent(c.hash!),
            SpaceCandidateKind.movie => await _deleteArr(
                DownloadNowConfig.radarrBaseUrl,
                DownloadNowConfig.radarrApiKey,
                '/api/v3/movie/${c.arrId}',
                {'deleteFiles': true, 'addImportExclusion': false},
              ),
            SpaceCandidateKind.series => await _deleteArr(
                DownloadNowConfig.sonarrBaseUrl,
                DownloadNowConfig.sonarrApiKey,
                '/api/v3/series/${c.arrId}',
                {'deleteFiles': true, 'addImportListExclusion': false},
              ),
          };
        }
      } catch (e) {
        debugPrint('[SpaceGuard] delete ${c.key} failed: $e');
        ok = false;
      }
      if (ok) {
        deleted++;
      } else {
        failed.add(c.title);
      }
    }
    onProgress?.call(items.length, items.length);
    // The plugin rescans the affected library itself.
    if (!DownloadFeatures.viaPlugin &&
        items.any((c) => c.kind != SpaceCandidateKind.duplicate)) {
      _refreshJellyfin();
    }
    return SpaceDeleteResult(deleted: deleted, failed: failed);
  }

  Future<bool> _deleteArr(
    String base,
    String key,
    String path,
    Map<String, dynamic> query,
  ) async {
    final res = await _dio.delete(
      '$base$path',
      queryParameters: query,
      options: Options(headers: {'X-Api-Key': key}),
    );
    return res.statusCode == 200;
  }

  Future<bool> _deleteTorrent(String hash) async {
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

  void _refreshJellyfin() {
    // Radarr/Sonarr cannot notify this Jellyfin (see its auth header change),
    // so rescan ourselves or deleted titles linger as broken tiles.
    () async {
      try {
        if (GetIt.instance.isRegistered<MediaServerClient>()) {
          await GetIt.instance<MediaServerClient>()
              .adminLibraryApi
              .refreshLibrary();
        }
      } catch (e) {
        debugPrint('[SpaceGuard] library refresh failed: $e');
      }
      homeRefreshBus.requestNowOrAfterNavigation();
    }();
  }

  // ---------------------------------------------------------- qBittorrent

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

  Future<dynamic> _qbGet(String path) async {
    if (!await _qbLogin()) throw Exception('qBittorrent login failed');
    final res = await _dio.get(
      '${DownloadNowConfig.qbittorrentBaseUrl}$path',
      options: Options(headers: _qbHeaders),
    );
    if (res.statusCode != 200) {
      throw Exception('qBittorrent $path HTTP ${res.statusCode}');
    }
    return res.data;
  }
}

class _Watch {
  DateTime? lastPlayed;
  bool favorite = false;

  void addPlay(DateTime? at) {
    if (at == null) return;
    if (lastPlayed == null || at.isAfter(lastPlayed!)) lastPlayed = at;
  }
}

/// What every Jellyfin user has watched, keyed by TMDB id for movies and by
/// `tvdb:<id>` / `tmdb:<id>` for series. Merged across users so a title
/// someone else is watching is never suggested.
class _JellyfinWatchData {
  final Map<String, _Watch> movies;
  final Map<String, _Watch> series;

  _JellyfinWatchData(this.movies, this.series);

  static Future<_JellyfinWatchData?> load({
    String? baseUrl,
    String? token,
  }) async {
    String? fallbackUserId;
    if (baseUrl == null || token == null) {
      if (!GetIt.instance.isRegistered<MediaServerClient>()) return null;
      final client = GetIt.instance<MediaServerClient>();
      baseUrl = client.baseUrl;
      token = client.accessToken;
      fallbackUserId = client.userId;
    }
    if (token == null || token.isEmpty) return null;
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (_) => true,
      // Jellyfin 12 only accepts this header form.
      headers: {'Authorization': 'MediaBrowser Token="$token"'},
    ));

    Future<List<Map>> items(String userId, Map<String, dynamic> q) async {
      final res = await dio.get('/Items', queryParameters: {
        'userId': userId,
        'Recursive': true,
        'EnableUserData': true,
        'EnableImages': false,
        ...q,
      });
      final list = res.data is Map ? res.data['Items'] : null;
      if (res.statusCode != 200 || list is! List) {
        throw Exception('Jellyfin /Items HTTP ${res.statusCode}');
      }
      return list.whereType<Map>().toList();
    }

    try {
      final usersRes = await dio.get('/Users');
      final userIds = <String>[
        if (usersRes.statusCode == 200 && usersRes.data is List)
          for (final u in (usersRes.data as List).whereType<Map>())
            if (u['Id'] is String) u['Id'] as String,
      ];
      if (userIds.isEmpty && fallbackUserId != null) userIds.add(fallbackUserId);
      if (userIds.isEmpty) return null;

      final movies = <String, _Watch>{};
      final series = <String, _Watch>{};
      final seriesKeysById = <String, List<String>>{};

      for (final uid in userIds) {
        for (final m in await items(uid, {
          'IncludeItemTypes': 'Movie',
          'Fields': 'ProviderIds',
        })) {
          final tmdb = (m['ProviderIds'] as Map?)?['Tmdb'];
          if (tmdb == null) continue;
          final w = movies.putIfAbsent('$tmdb', _Watch.new);
          final ud = m['UserData'] as Map? ?? const {};
          w.favorite |= ud['IsFavorite'] == true;
          w.addPlay(DateTime.tryParse(ud['LastPlayedDate'] as String? ?? ''));
        }

        for (final s in await items(uid, {
          'IncludeItemTypes': 'Series',
          'Fields': 'ProviderIds',
        })) {
          final ids = s['ProviderIds'] as Map? ?? const {};
          final keys = [
            if (ids['Tvdb'] != null) 'tvdb:${ids['Tvdb']}',
            if (ids['Tmdb'] != null) 'tmdb:${ids['Tmdb']}',
          ];
          if (keys.isEmpty || s['Id'] is! String) continue;
          seriesKeysById[s['Id'] as String] = keys;
          final w = series.putIfAbsent(keys.first, _Watch.new);
          for (final k in keys.skip(1)) {
            series[k] = w;
          }
          final ud = s['UserData'] as Map? ?? const {};
          w.favorite |= ud['IsFavorite'] == true;
        }

        // Played and half-watched episodes carry the dates a series lacks.
        for (final filter in ['IsPlayed', 'IsResumable']) {
          for (final e in await items(uid, {
            'IncludeItemTypes': 'Episode',
            'Filters': filter,
            'Fields': 'SeriesId',
          })) {
            final keys = seriesKeysById[e['SeriesId']];
            if (keys == null) continue;
            final ud = e['UserData'] as Map? ?? const {};
            series[keys.first]?.addPlay(
              DateTime.tryParse(ud['LastPlayedDate'] as String? ?? ''),
            );
          }
        }
      }
      return _JellyfinWatchData(movies, series);
    } catch (e) {
      debugPrint('[SpaceGuard] Jellyfin watch data failed: $e');
      return null;
    }
  }
}
