import '../../../data/models/aggregated_item.dart';
import '../../../data/models/home_row.dart';
import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';

/// Row ids of Tortugarr's smart home rows.
const tortugarrDownloadsRowId = 'tortugarr_downloads';
const tortugarrTonightRowId = 'tortugarr_tonight';

/// Longest film the "Fits tonight" row offers.
const tonightMaxRuntime = Duration(minutes: 105);

String _percent(double f) => '${(f * 100).clamp(0, 99).floor()} %';

String _eta(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final m = (seconds / 60).ceil();
  if (m < 60) return ' · $m min';
  return ' · ${m ~/ 60} h ${m % 60} min';
}

String _status(String? s, double fraction, [int? eta]) => switch (s) {
      'queued' => 'Queued',
      'paused' => 'Paused',
      'importPending' || 'importing' => 'Ready in a moment',
      'failed' || 'warning' => 'Needs a look',
      _ => '${_percent(fraction)}${_eta(eta)}',
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
    final etas = list.map((q) => q.etaSeconds).whereType<int>();
    final eta = etas.isEmpty ? null : etas.reduce((a, b) => a > b ? a : b);
    final status = list.length == 1
        ? _status(first.status, fraction, first.etaSeconds)
        : '${list.length} episodes · ${_percent(fraction)}${_eta(eta)}';
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

/// Unwatched films and next-up episodes that fit an evening: at most
/// [tonightMaxRuntime], in the order given, up to 20.
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

/// Films and next-up episodes taken in turn (film, episode, film …), so the
/// "Fits tonight" row offers both.
List<Map<String, dynamic>> mixTonight({
  required List<Map<String, dynamic>> movies,
  required List<Map<String, dynamic>> episodes,
}) {
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < movies.length || i < episodes.length; i++) {
    if (i < movies.length) out.add(movies[i]);
    if (i < episodes.length) out.add(episodes[i]);
  }
  return out;
}
