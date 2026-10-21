import 'package:flutter/foundation.dart' show visibleForTesting;

import '../tortugarr/tortugarr_plugin_client.dart';
import 'seerr_api_models.dart';

/// What Radarr and Sonarr are downloading, with the bytes left as
/// qBittorrent reports them now. Seerr copies the figures from Radarr/Sonarr
/// once a minute, and they ask qBittorrent once a minute: on 2026-10-20 the
/// TV showed 17 % for a finished download, and a new download first showed
/// up at 30-60 %. The pollers call [refresh]; [fromItems] prefers these
/// figures when fresh, and [itemsFor] stands in until Seerr has synced.
class LiveDownloadProgress {
  static const _minGap = Duration(seconds: 3);
  static const _maxAge = Duration(seconds: 60);
  static List<TortugarrQueueItem> _queue = const [];
  static Map<String, int> _left = const {};
  static DateTime? _at;

  static Future<void> refresh({bool force = false}) async {
    final at = _at;
    if (!force && at != null && DateTime.now().difference(at) < _minGap) return;
    try {
      _set(await TortugarrPluginClient().downloadQueue());
    } catch (_) {
      // No plugin, or one slow answer: the last queue holds until it is a
      // minute old, then the Seerr figures take over. Clearing it at once
      // made the bar blink out between two good reads.
    }
  }

  static void _set(List<TortugarrQueueItem> queue) {
    _queue = queue;
    _left = {for (final q in queue) q.downloadId: q.sizeLeft};
    _at = DateTime.now();
  }

  static bool get _fresh {
    final at = _at;
    return at != null && DateTime.now().difference(at) <= _maxAge;
  }

  @visibleForTesting
  static void setForTest(Map<String, int>? left) {
    if (left == null) {
      _queue = const [];
      _left = const {};
      _at = null;
      return;
    }
    _set([
      for (final e in left.entries)
        TortugarrQueueItem(downloadId: e.key, kind: 'movie', sizeLeft: e.value),
    ]);
  }

  @visibleForTesting
  static void setQueueForTest(List<TortugarrQueueItem> queue) => _set(queue);

  /// The queue as last read, empty when it is stale or unknown.
  static List<TortugarrQueueItem> get queue => _fresh ? _queue : const [];

  /// True when Radarr/Sonarr no longer have [downloadId] in their queue, so it
  /// was imported (or removed); Seerr only notices on its next sync.
  static bool isGone(String downloadId) =>
      _fresh && !_left.containsKey(downloadId.toUpperCase());

  static int? leftFor(String downloadId) =>
      _fresh ? _left[downloadId.toUpperCase()] : null;

  /// Queue entries for one movie ([tmdbId]) or series ([tvdbId]), in Seerr's
  /// form. Radarr/Sonarr list a grab within seconds; Seerr up to a minute or
  /// more later.
  static List<SeerrDownloadingItem> itemsFor({int? tmdbId, int? tvdbId}) => [
        for (final q in queue)
          if (matches(q, tmdbId: tmdbId, tvdbId: tvdbId))
            SeerrDownloadingItem(
              size: q.size,
              sizeLeft: q.sizeLeft,
              downloadId: q.downloadId,
            ),
      ];

  /// Stops what Radarr/Sonarr download for one movie or series, files and
  /// all. A cancelled request left its torrent running, and the downloads
  /// bar came back with it from the queue (2026-10-21). Best effort.
  static Future<void> removeFor({int? tmdbId, int? tvdbId}) async {
    await refresh(force: true);
    for (final q in queue) {
      if (!matches(q, tmdbId: tmdbId, tvdbId: tvdbId)) continue;
      try {
        await TortugarrPluginClient().removeDownload(q.downloadId);
      } catch (_) {}
    }
    await refresh(force: true);
  }

  static bool matches(TortugarrQueueItem q, {int? tmdbId, int? tvdbId}) =>
      q.kind == 'movie'
          ? tmdbId != null && q.tmdbId == tmdbId
          : tvdbId != null && q.tvdbId == tvdbId;
}

/// Aggregated download progress for a Seerr media item, combining the
/// Radarr/Sonarr queue entries the server reports in downloadStatus.
class SeerrDownloadSummary {
  /// Overall progress from 0 to 1, weighted by item size so a large episode
  /// counts more than a small one.
  final double fraction;

  /// True when every item has finished downloading and is being imported, so
  /// the UI can label the full bar instead of showing a stuck 100%.
  final bool isImporting;

  /// Total bytes and how many have arrived. The UI shows these next to the
  /// percentage. Zero when the server reports no usable sizes.
  final int totalBytes;
  final int downloadedBytes;

  const SeerrDownloadSummary({
    required this.fraction,
    required this.isImporting,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
  });

  int get percent => (fraction * 100).round();

  /// Whether the byte counts are worth showing.
  bool get hasSize => totalBytes > 0;

  static const _statusProcessing = 3;
  static const _statusPartiallyAvailable = 4;

  /// Builds a summary for one quality flavor of a media item, or null when
  /// nothing is downloading and the status chip alone should show. The status
  /// gate keeps stale queue entries from drawing a bar after availability.
  ///
  /// With [tmdbId] for a movie or [tvdbId] for a series (never both: TMDB
  /// numbers movies and series apart), a download Radarr or Sonarr already
  /// has but Seerr has not synced yet shows too.
  static SeerrDownloadSummary? forMedia({
    required int? status,
    required List<SeerrDownloadingItem>? items,
    int? tmdbId,
    int? tvdbId,
  }) {
    final early = LiveDownloadProgress.itemsFor(tmdbId: tmdbId, tvdbId: tvdbId);
    if (status != _statusProcessing && status != _statusPartiallyAvailable) {
      // Seerr calls the title available, but Radarr/Sonarr may still be
      // fetching for it: an episode from the missing-episodes list of a
      // series Seerr has as complete. Only their queue counts then.
      return fromItems(early);
    }
    final known = {
      for (final i in items ?? const <SeerrDownloadingItem>[])
        if (i.downloadId != null) i.downloadId!.toUpperCase(),
    };
    return fromItems([
      ...?items,
      for (final i in early)
        if (!known.contains(i.downloadId)) i,
    ]);
  }

  /// Summary for a request card, using the request's quality flavor and
  /// skipping requests that can no longer be downloading.
  static SeerrDownloadSummary? forRequest(SeerrRequest request) {
    if (request.status == SeerrRequest.statusDeclined ||
        request.status == SeerrRequest.statusFailed) {
      return null;
    }
    final media = request.media;
    if (media == null) return null;
    return forMedia(
      status: request.is4k ? media.status4k : media.status,
      items: request.is4k ? media.downloadStatus4k : media.downloadStatus,
      tmdbId: (media.mediaType ?? request.type) == 'movie' ? media.tmdbId : null,
      tvdbId: (media.mediaType ?? request.type) == 'tv' ? media.tvdbId : null,
    );
  }

  static SeerrDownloadSummary? fromItems(List<SeerrDownloadingItem>? items) {
    if (items == null || items.isEmpty) return null;
    var total = 0;
    var left = 0;
    final seen = <String>{};
    for (final item in items) {
      final size = item.size;
      if (size == null || size <= 0) continue;
      // Sonarr lists a season pack once per episode, each with the whole
      // pack's size, so a 9 episode pack counted 9 times. Count a download
      // once. No id means a release Sonarr or Radarr is holding back (a
      // delay profile): nothing is downloading yet, and it may never be the
      // release that gets grabbed, so it is left out.
      final id = item.downloadId;
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      if (LiveDownloadProgress.isGone(id)) continue;
      total += size;
      left += (LiveDownloadProgress.leftFor(id) ?? item.sizeLeft ?? 0).clamp(0, size);
    }
    if (total <= 0) return null;
    return SeerrDownloadSummary(
      fraction: ((total - left) / total).clamp(0.0, 1.0),
      isImporting: left <= 0,
      totalBytes: total,
      downloadedBytes: total - left,
    );
  }
}
