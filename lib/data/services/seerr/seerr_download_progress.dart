import 'package:flutter/foundation.dart' show visibleForTesting;

import '../tortugarr/tortugarr_plugin_client.dart';
import 'seerr_api_models.dart';

/// Bytes left per download as qBittorrent reports them now. Seerr copies the
/// figures from Radarr/Sonarr once a minute, and they ask qBittorrent once a
/// minute: on 2026-10-20 the TV showed 17 % for a finished download. The
/// pollers call [refresh]; [fromItems] prefers these figures when fresh.
class LiveDownloadProgress {
  static const _minGap = Duration(seconds: 3);
  static const _maxAge = Duration(seconds: 60);
  static Map<String, int> _left = const {};
  static DateTime? _at;

  static Future<void> refresh() async {
    final at = _at;
    if (at != null && DateTime.now().difference(at) < _minGap) return;
    try {
      _left = await TortugarrPluginClient().downloadsLeft();
      _at = DateTime.now();
    } catch (_) {
      // No plugin or no qBittorrent: the Seerr figures stay.
      _left = const {};
      _at = null;
    }
  }

  @visibleForTesting
  static void setForTest(Map<String, int>? left) {
    _left = left ?? const {};
    _at = left == null ? null : DateTime.now();
  }

  static int? leftFor(String downloadId) {
    final at = _at;
    if (at == null || DateTime.now().difference(at) > _maxAge) return null;
    return _left[downloadId.toUpperCase()];
  }
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
  static SeerrDownloadSummary? forMedia({
    required int? status,
    required List<SeerrDownloadingItem>? items,
  }) {
    if (status != _statusProcessing && status != _statusPartiallyAvailable) {
      return null;
    }
    return fromItems(items);
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
