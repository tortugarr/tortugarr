import 'package:get_it/get_it.dart';

import '../data/repositories/tmdb_repository.dart';
import '../data/services/plugin_sync_service.dart';

/// The titled TMDB thumb the plugin picks for a movie or show from Seerr or an
/// outside list. Null when the plugin can't, so the caller keeps the plain
/// backdrop. [imdbId] only counts when there is no [tmdbId].
String? seerrThumbUrl({
  required String? type,
  String? tmdbId,
  String? imdbId,
}) {
  if (type != 'movie' && type != 'tv') return null;
  if (!GetIt.instance<PluginSyncService>().tmdbThumbsAvailable) return null;
  return GetIt.instance<TmdbRepository>().thumbUrl(
    type: type!,
    tmdbId: tmdbId,
    imdbId: imdbId,
  );
}
