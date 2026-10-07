import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../models/aggregated_item.dart';
import '../download/bazarr_client.dart';
import '../subtitle_backend.dart';
import 'tortugarr_plugin_client.dart';
import 'package:moonfin/util/app_l10n.dart';

/// "Find subtitles" in the public build: Bazarr through the server's
/// Tortugarr plugin (spec 3.8). A title is named by its TMDB id (movie) or
/// the series' TVDB id with season and episode, as the plugin expects.
class PluginSubtitleService implements SubtitleBackend<Map<String, Object>> {
  final TortugarrPluginClient _plugin;
  final Dio _dio;

  PluginSubtitleService({TortugarrPluginClient? plugin, Dio? dio})
      : _plugin = plugin ?? TortugarrPluginClient(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ));

  @override
  Future<Map<String, Object>?> resolve(AggregatedItem item) async {
    switch (item.type) {
      case 'Movie':
        final tmdb = int.tryParse(item.providerIds['Tmdb'] ?? '');
        return tmdb == null ? null : {'type': 'movie', 'tmdbId': tmdb};
      case 'Episode':
        final season = item.parentIndexNumber;
        final episode = item.indexNumber;
        final seriesItemId = item.seriesId;
        if (season == null || episode == null || seriesItemId == null) return null;
        final tvdb = int.tryParse((await _seriesProviderIds(seriesItemId))['Tvdb'] ?? '');
        return tvdb == null
            ? null
            : {'type': 'episode', 'tvdbId': tvdb, 'season': season, 'episode': episode};
    }
    return null;
  }

  @override
  Future<BazarrSubtitleState> state(Map<String, Object> target) =>
      _guard(() => _plugin.subtitleState(target));

  @override
  Future<BazarrSubtitleState> searchMissing(
    Map<String, Object> target,
    Iterable<String> languages, {
    Duration timeout = const Duration(seconds: 75),
    Duration pollEvery = const Duration(seconds: 4),
  }) =>
      _guard(() async {
        final wanted = languages.toSet();
        await _plugin.searchSubtitles(target, wanted);
        // Bazarr only queues the search; wait like the private build does.
        final deadline = DateTime.now().add(timeout);
        var latest = await _plugin.subtitleState(target);
        var unchanged = 0;
        while (DateTime.now().isBefore(deadline)) {
          final stillMissing = latest.missing.intersection(wanted);
          if (stillMissing.isEmpty) break;
          if (stillMissing.length < wanted.length && unchanged >= 3) break;
          await Future<void>.delayed(pollEvery);
          final next = await _plugin.subtitleState(target);
          unchanged = setEquals(next.missing, latest.missing) ? unchanged + 1 : 0;
          latest = next;
        }
        return latest;
      });

  @override
  Future<List<BazarrCandidate>> candidates(Map<String, Object> target) =>
      _guard(() => _plugin.subtitleCandidates(target));

  @override
  Future<void> download(Map<String, Object> target, BazarrCandidate candidate) =>
      _guard(() => _plugin.downloadSubtitle(target, candidate));

  /// The dialog shows [BazarrException] messages; plugin errors become those.
  Future<R> _guard<R>(Future<R> Function() call) async {
    try {
      return await call();
    } on TortugarrPluginException catch (e) {
      throw BazarrException(switch (e.code) {
        'not_found' => appL10n().tgBazarrUnknownTitle,
        'not_configured' || 'feature_off' => appL10n().tgBazarrUnreachable,
        _ => e.toString(),
      });
    }
  }

  Future<Map<String, String>> _seriesProviderIds(String itemId) async {
    final client = GetIt.instance<MediaServerClient>();
    final res = await _dio.get(
      '${client.baseUrl}/Items',
      queryParameters: {'ids': itemId, 'Fields': 'ProviderIds'},
      // Jellyfin 12 only accepts this header form.
      options: Options(headers: {'Authorization': 'MediaBrowser Token="${client.accessToken}"'}),
    );
    final items = res.data is Map ? res.data['Items'] : null;
    if (res.statusCode != 200 || items is! List || items.isEmpty) return const {};
    final ids = (items.first as Map)['ProviderIds'];
    return ids is Map ? {for (final e in ids.entries) '${e.key}': '${e.value}'} : const {};
  }
}
