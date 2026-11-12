import '../../../data/models/aggregated_item.dart';
import '../../../data/models/home_row.dart';
import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';

/// Row ids of Tortugarr's smart home rows.
const tortugarrDownloadsRowId = 'tortugarr_downloads';
const tortugarrTonightRowId = 'tortugarr_tonight';

/// Longest film the "Fits tonight" row offers.
const tonightMaxRuntime = Duration(minutes: 105);

String _percent(double f) => '${(f * 100).clamp(0, 99).floor()} %';

String _status(String? s, double fraction) => switch (s) {
      'queued' => 'Queued',
      'paused' => 'Paused',
      'importPending' || 'importing' => 'Ready in a moment',
      'failed' || 'warning' => 'Needs a look',
      _ => _percent(fraction),
    };

/// What Radarr and Sonarr are downloading, as one card per title: episodes
/// of one series are folded into one card. Progress shows as the card's
/// progress bar and in its subtitle. Titles already imported are left out.
/// [posters] maps 'movie:<tmdb>' / 'tv:<tmdb|tvdb>' to a poster URL.
HomeRow? mapDownloadsRow(
  List<TortugarrQueueItem> queue, {
  required String title,
  Map<String, String> posters = const {},
}) {
  final groups = <String, List<TortugarrQueueItem>>{};
  for (final q in queue) {
    if (q.isImported) continue;
    final movie = q.kind == 'movie';
    final id = movie ? q.tmdbId : (q.tmdbId ?? q.tvdbId);
    final key = id == null ? 'name:${q.name ?? q.downloadId}' : '${movie ? 'movie' : 'tv'}:$id';
    groups.putIfAbsent(key, () => []).add(q);
  }
  if (groups.isEmpty) return null;
  final items = <AggregatedItem>[];
  for (final MapEntry(key: key, value: list) in groups.entries) {
    final first = list.first;
    final movie = first.kind == 'movie';
    final size = list.fold<int>(0, (a, q) => a + q.size);
    final left = list.fold<int>(0, (a, q) => a + q.sizeLeft);
    final fraction = size > 0 ? (size - left) / size : 0.0;
    final status = list.length == 1
        ? _status(first.status, fraction)
        : '${list.length} episodes · ${_percent(fraction)}';
    final tmdb = first.tmdbId;
    items.add(AggregatedItem(
      id: tmdb != null && tmdb > 0 ? '$tmdb' : key,
      serverId: 'seerr',
      rawData: {
        'Name': first.name ?? '',
        'Type': movie ? 'Movie' : 'Series',
        'SeerrMediaType': movie ? 'movie' : 'tv',
        'PosterPath': posters[key] ?? '',
        'Subtitle': status,
        'UserData': {'PlayedPercentage': (fraction * 100).clamp(1, 99)},
        'ProviderIds': {
          if (tmdb != null) 'Tmdb': '$tmdb',
          if (first.tvdbId != null) 'Tvdb': '${first.tvdbId}',
        },
      },
    ));
  }
  return HomeRow(
    id: tortugarrDownloadsRowId,
    title: title,
    rowType: HomeRowType.pluginDynamic,
    items: items,
  );
}

/// Unwatched films that fit an evening: at most [tonightMaxRuntime], in the
/// order given (the caller asks the server for a random order), up to 20.
HomeRow? mapTonightRow(
  List<Map<String, dynamic>> movies, {
  required String title,
  required String serverId,
}) {
  final maxTicks = tonightMaxRuntime.inMicroseconds * 10;
  final items = <AggregatedItem>[
    for (final m in movies)
      if (m['RunTimeTicks'] is num &&
          (m['RunTimeTicks'] as num) > 0 &&
          (m['RunTimeTicks'] as num) <= maxTicks)
        AggregatedItem(id: '${m['Id']}', serverId: serverId, rawData: m),
  ].take(20).toList();
  if (items.isEmpty) return null;
  return HomeRow(
    id: tortugarrTonightRowId,
    title: title,
    rowType: HomeRowType.pluginDynamic,
    items: items,
  );
}
