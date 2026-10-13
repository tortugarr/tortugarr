import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../../../ui/navigation/home_refresh_bus.dart';
import '../../models/aggregated_item.dart';
import '../../viewmodels/media_bar_view_model.dart';
import 'download_now_service.dart' show DownloadNowConfig;
import 'package:moonfin/util/app_l10n.dart';

enum ArrDeleteOutcome {
  /// Deleted through Radarr/Sonarr.
  deleted,

  /// Radarr/Sonarr do not manage this file; the caller decides what next.
  notManaged,
}

/// Deletes movies and episodes through Radarr/Sonarr instead of Jellyfin.
///
/// Jellyfin mounts the media folders read-only here, so its own delete fails
/// with "Access denied". Radarr/Sonarr can write, and deleting through them
/// also keeps them from downloading the title again. A file is only deleted
/// when Radarr/Sonarr track exactly that file (same file name), so a second
/// copy elsewhere is never removed by mistake.
class ArrDeleteService {
  final Dio _dio;

  ArrDeleteService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              validateStatus: (_) => true,
            ));

  Future<ArrDeleteOutcome> delete(AggregatedItem item) async {
    // Look up the library while Jellyfin still knows the item.
    final library = await _libraryOf(item.id).catchError((Object _) => null);
    final outcome = switch (item.type) {
      'Movie' => await _deleteMovie(item),
      'Episode' => await _deleteEpisodes(item, season: item.parentIndexNumber, episode: item.indexNumber),
      'Season' => await _deleteEpisodes(item, season: item.indexNumber),
      'Series' => await _deleteSeries(item),
      _ => ArrDeleteOutcome.notManaged,
    };
    if (outcome == ArrDeleteOutcome.deleted) _refreshJellyfin(item.id, library);
    return outcome;
  }

  @visibleForTesting
  static bool sameFile(String? jellyfinPath, String? arrPath) {
    if (jellyfinPath == null || jellyfinPath.isEmpty) return true;
    if (arrPath == null || arrPath.isEmpty) return false;
    String base(String p) => p.split('/').last.toLowerCase();
    return base(jellyfinPath) == base(arrPath);
  }

  // ------------------------------------------------------------- movies

  Future<ArrDeleteOutcome> _deleteMovie(AggregatedItem item) async {
    final tmdb = int.tryParse(item.providerIds['Tmdb'] ?? '');
    if (tmdb == null) return ArrDeleteOutcome.notManaged;
    final movies = await _get(_radarr, '/api/v3/movie', {'tmdbId': tmdb});
    if (movies is! List) return ArrDeleteOutcome.notManaged;
    for (final m in movies.whereType<Map>()) {
      if (m['tmdbId'] != tmdb || m['hasFile'] != true) continue;
      final file = m['movieFile'];
      if (file is! Map || !sameFile(item.rawData['Path'] as String?, file['path'] as String?)) {
        continue;
      }
      await _delete(_radarr, '/api/v3/movie/${m['id']}',
          {'deleteFiles': true, 'addImportExclusion': false});
      return ArrDeleteOutcome.deleted;
    }
    return ArrDeleteOutcome.notManaged;
  }

  // ------------------------------------------------------------- series

  Future<Map?> _sonarrSeries(AggregatedItem item) async {
    Map<String, String> ids = item.providerIds;
    if (item.type != 'Series') {
      final seriesId = item.seriesId;
      if (seriesId == null) return null;
      ids = await _jellyfinProviderIds(seriesId);
    }
    final tvdb = int.tryParse(ids['Tvdb'] ?? '');
    if (tvdb == null) return null;
    final series = await _get(_sonarr, '/api/v3/series', {'tvdbId': tvdb});
    if (series is! List) return null;
    for (final s in series.whereType<Map>()) {
      if (s['tvdbId'] == tvdb) return s;
    }
    return null;
  }

  Future<ArrDeleteOutcome> _deleteSeries(AggregatedItem item) async {
    final series = await _sonarrSeries(item);
    if (series == null) return ArrDeleteOutcome.notManaged;
    await _delete(_sonarr, '/api/v3/series/${series['id']}',
        {'deleteFiles': true, 'addImportListExclusion': false});
    return ArrDeleteOutcome.deleted;
  }

  /// One episode, or a whole season when [episode] is null.
  Future<ArrDeleteOutcome> _deleteEpisodes(
    AggregatedItem item, {
    required int? season,
    int? episode,
  }) async {
    if (season == null) return ArrDeleteOutcome.notManaged;
    final series = await _sonarrSeries(item);
    if (series == null) return ArrDeleteOutcome.notManaged;
    final episodes = await _get(_sonarr, '/api/v3/episode',
        {'seriesId': series['id'], 'seasonNumber': season, 'includeEpisodeFile': true});
    if (episodes is! List) return ArrDeleteOutcome.notManaged;

    final fileIds = <int>{};
    final episodeIds = <int>[];
    for (final e in episodes.whereType<Map>()) {
      if (episode != null && e['episodeNumber'] != episode) continue;
      final fileId = (e['episodeFileId'] as num?)?.toInt() ?? 0;
      if (fileId <= 0) continue;
      if (episode != null) {
        final file = e['episodeFile'];
        final arrPath = file is Map ? file['path'] as String? : null;
        if (!sameFile(item.rawData['Path'] as String?, arrPath)) continue;
      }
      fileIds.add(fileId);
      episodeIds.add((e['id'] as num).toInt());
    }
    if (fileIds.isEmpty) return ArrDeleteOutcome.notManaged;

    // Unmonitor first so Sonarr does not go looking for them again.
    await _dio.put(
      '${_sonarr.base}/api/v3/episode/monitor',
      data: {'episodeIds': episodeIds, 'monitored': false},
      options: Options(headers: {'X-Api-Key': _sonarr.key}),
    );
    for (final id in fileIds) {
      await _delete(_sonarr, '/api/v3/episodefile/$id', const {});
    }
    return ArrDeleteOutcome.deleted;
  }

  // ------------------------------------------------------------ helpers

  ({String base, String key}) get _radarr =>
      (base: DownloadNowConfig.radarrBaseUrl, key: DownloadNowConfig.radarrApiKey);
  ({String base, String key}) get _sonarr =>
      (base: DownloadNowConfig.sonarrBaseUrl, key: DownloadNowConfig.sonarrApiKey);

  Future<dynamic> _get(
    ({String base, String key}) arr,
    String path,
    Map<String, dynamic> query,
  ) async {
    final res = await _dio.get('${arr.base}$path',
        queryParameters: query, options: Options(headers: {'X-Api-Key': arr.key}));
    if (res.statusCode != 200) {
      throw Exception('${arr.base}$path svarte HTTP ${res.statusCode}');
    }
    return res.data;
  }

  Future<void> _delete(
    ({String base, String key}) arr,
    String path,
    Map<String, dynamic> query,
  ) async {
    final res = await _dio.delete('${arr.base}$path',
        queryParameters: query, options: Options(headers: {'X-Api-Key': arr.key}));
    if (res.statusCode != 200) {
      throw Exception(appL10n().tgDeleteFailed('${res.statusCode}'));
    }
  }

  Future<Map<String, String>> _jellyfinProviderIds(String itemId) async {
    final res = await _dio.get(
      '$_jellyfinBase/Items',
      queryParameters: {'ids': itemId, 'Fields': 'ProviderIds'},
      options: Options(headers: _jellyfinAuth),
    );
    final items = res.data is Map ? res.data['Items'] : null;
    if (res.statusCode != 200 || items is! List || items.isEmpty) return const {};
    final ids = (items.first as Map)['ProviderIds'];
    return ids is Map
        ? {for (final e in ids.entries) '${e.key}': '${e.value}'}
        : const {};
  }

  Map<String, String> get _jellyfinAuth => {
        // Jellyfin 12 only accepts this header form.
        'Authorization':
            'MediaBrowser Token="${GetIt.instance<MediaServerClient>().accessToken}"',
      };

  String get _jellyfinBase => GetIt.instance<MediaServerClient>().baseUrl;

  /// The library folder holding [itemId]: the ancestor right below
  /// Jellyfin's root (ancestors come nearest first).
  Future<String?> _libraryOf(String itemId) async {
    final res = await _dio.get('$_jellyfinBase/Items/$itemId/Ancestors',
        options: Options(headers: _jellyfinAuth));
    if (res.statusCode != 200 || res.data is! List) return null;
    final ancestors = (res.data as List).whereType<Map>().toList();
    for (var i = 0; i < ancestors.length; i++) {
      final type = ancestors[i]['Type'];
      if (type == 'CollectionFolder') return ancestors[i]['Id'] as String?;
      if (type == 'AggregateFolder' && i > 0) {
        return ancestors[i - 1]['Id'] as String?;
      }
    }
    return null;
  }

  /// Rescan only the item's library and refresh the home screen once the
  /// item is really gone; a full scan of every library takes minutes, and
  /// refreshing before it finishes shows the deleted title again.
  void _refreshJellyfin(String itemId, String? libraryId) {
    () async {
      try {
        if (libraryId != null) {
          await _dio.post(
            '$_jellyfinBase/Items/$libraryId/Refresh',
            queryParameters: {
              'Recursive': true,
              'MetadataRefreshMode': 'Default',
              'ImageRefreshMode': 'Default',
              'ReplaceAllMetadata': false,
              'ReplaceAllImages': false,
            },
            options: Options(headers: _jellyfinAuth),
          );
        } else {
          await GetIt.instance<MediaServerClient>().adminLibraryApi.refreshLibrary();
        }
      } catch (e) {
        debugPrint('[ArrDelete] library refresh failed: $e');
      }
      await awaitRemoval(itemId);
    }();
  }

  /// Waits (every 3 s, up to 3 min) until Jellyfin no longer knows [itemId],
  /// then refreshes the home screen. Also used after the Tortugarr plugin
  /// deleted a title, which rescans the library itself.
  Future<void> awaitRemoval(String itemId) async {
    try {
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        final res = await _dio.get('$_jellyfinBase/Items',
            queryParameters: {'ids': itemId},
            options: Options(headers: _jellyfinAuth));
        final items = res.data is Map ? res.data['Items'] : null;
        if (res.statusCode == 200 && items is List && items.isEmpty) break;
      }
    } catch (e) {
      debugPrint('[ArrDelete] waiting for the removal failed: $e');
    }
    // The media bar loads once and a home refresh leaves it alone, so a
    // deleted title stayed in it (and gave a 404 when opened).
    if (GetIt.instance.isRegistered<MediaBarViewModel>()) {
      unawaited(GetIt.instance<MediaBarViewModel>().load(force: true));
    }
    homeRefreshBus.requestNowOrAfterNavigation();
  }
}
