import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../repositories/seerr_repository.dart';
import '../../ui/navigation/home_refresh_bus.dart';
import 'seerr/seerr_api_models.dart';
import 'seerr/seerr_download_progress.dart';
import 'tortugarr/tortugarr_plugin_client.dart' show TortugarrQueueItem;
import '../../preference/seerr_preferences.dart' show SeerrPreferences;

/// One active Seerr download — a request whose media is in a non-final
/// status (processing, partially available, pending approval, etc).
class SeerrActiveDownload {
  final int requestId;
  final String title;
  final String mediaType; // 'movie' | 'tv'
  final SeerrDownloadSummary? hdSummary;
  final SeerrDownloadSummary? uhdSummary;
  final bool is4k;

  const SeerrActiveDownload({
    required this.requestId,
    required this.title,
    required this.mediaType,
    required this.is4k,
    this.hdSummary,
    this.uhdSummary,
  });

  /// Combined best-known fraction across both quality flavors.
  double get fraction {
    final hd = hdSummary?.fraction ?? 0;
    final uhd = uhdSummary?.fraction ?? 0;
    return hd > uhd ? hd : uhd;
  }

  bool get isImporting => (hdSummary?.isImporting ?? false) ||
      (uhdSummary?.isImporting ?? false);
}

/// Polls Seerr for in-flight requests and surfaces them as a
/// `ChangeNotifier` so the global status bar can react in real time.
///
/// Seerr exposes each request's media with byte-level progress for HD and
/// 4K — that is all the bar needs, no extra endpoints.
class SeerrActiveDownloadsService extends ChangeNotifier {
  static const Duration _stuckImportTimeout = Duration(minutes: 5);

  Timer? _timer;
  bool _polling = false;
  bool _started = false;
  List<SeerrActiveDownload> _downloads = const [];
  final Set<int> _dismissedRequestIds = <int>{};
  final Set<String> _dismissedTitles = <String>{};
  final Map<int, DateTime> _firstSeen = <int, DateTime>{};
  final Map<int, double> _lastFraction = <int, double>{};
  final Map<int, bool> _lastImporting = <int, bool>{};

  List<SeerrActiveDownload> get downloads => _downloads;
  bool get hasActive => _downloads.isNotEmpty;

  void start() {
    if (_started) return;
    _started = true;
    _scheduleNext(initial: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// User-driven hide for one download. The dismiss survives the next poll
  /// and is dropped once the underlying request no longer shows up.
  void dismiss(int requestId) {
    _dismissedRequestIds.add(requestId);
    final filtered = _downloads.where((d) => d.requestId != requestId).toList();
    if (filtered.length != _downloads.length) {
      _downloads = filtered;
      notifyListeners();
    }
  }

  /// Hides the entire bar until the next genuine change. Useful when the user
  /// already handled the downloads elsewhere (e.g. removed the torrent).
  void dismissAll() {
    for (final d in _downloads) {
      _dismissedRequestIds.add(d.requestId);
      if (d.title.isNotEmpty) _dismissedTitles.add(d.title);
    }
    _downloads = const [];
    notifyListeners();
  }

  void _scheduleNext({bool initial = false}) {
    _timer?.cancel();
    // Slow down once we know nothing is downloading. Five seconds while busy
    // gives near-realtime feedback without hammering the server.
    final delay = initial
        ? const Duration(milliseconds: 1500)
        : (_downloads.isNotEmpty
            ? const Duration(seconds: 5)
            : const Duration(seconds: 10));
    _timer = Timer(delay, _poll);
  }

  Future<void> _poll() async {
    if (_polling) {
      _scheduleNext();
      return;
    }
    _polling = true;
    try {
      final fetched = await _fetch();
      final now = DateTime.now();

      // Track first-seen and last-change times so we can auto-drop
      // downloads that look stuck on "importing" with no byte progress.
      for (final d in fetched) {
        _firstSeen.putIfAbsent(d.requestId, () => now);
        _lastFraction.putIfAbsent(d.requestId, () => d.fraction);
        _lastImporting.putIfAbsent(d.requestId, () => d.isImporting);
      }

      final visible = <SeerrActiveDownload>[];
      for (final d in fetched) {
        if (_dismissedRequestIds.contains(d.requestId)) continue;
        if (d.title.isNotEmpty && _dismissedTitles.contains(d.title)) continue;

        final lastFraction = _lastFraction[d.requestId] ?? 0.0;
        final lastImporting = _lastImporting[d.requestId] ?? false;
        final progressChanged = d.fraction != lastFraction;
        final importingChanged = d.isImporting != lastImporting;
        if (progressChanged || importingChanged) {
          _lastFraction[d.requestId] = d.fraction;
          _lastImporting[d.requestId] = d.isImporting;
        } else if (d.isImporting &&
            now.difference(_firstSeen[d.requestId]!) >
                _stuckImportTimeout) {
          // Stuck in "importing" for too long — auto-dismiss to keep the
          // bar from sitting on a row the user already gave up on.
          _dismissedRequestIds.add(d.requestId);
          continue;
        }
        visible.add(d);
      }

      // Drop tracking for downloads that no longer exist on the server.
      final liveIds = fetched.map((d) => d.requestId).toSet();
      // A download that left the list has finished (imported) or was removed:
      // refresh the home screen so a new title shows up without a restart.
      // Twice, as Jellyfin may still be adding it at the first look.
      if (_downloads.any((d) => !liveIds.contains(d.requestId))) {
        homeRefreshBus.requestNowOrAfterNavigation();
        Timer(const Duration(seconds: 30), homeRefreshBus.requestNowOrAfterNavigation);
      }
      _firstSeen.removeWhere((id, _) => !liveIds.contains(id));
      _lastFraction.removeWhere((id, _) => !liveIds.contains(id));
      _lastImporting.removeWhere((id, _) => !liveIds.contains(id));
      _dismissedRequestIds.removeWhere((id) => !liveIds.contains(id));

      if (!_listEquals(visible, _downloads)) {
        _downloads = visible;
        notifyListeners();
      }
    } catch (_) {
      // Swallow — a missed poll is not a reason to drop the bar. Next tick
      // will retry.
    } finally {
      _polling = false;
      _scheduleNext();
    }
  }

  Future<List<SeerrActiveDownload>> _fetch() async {
    if (!GetIt.instance.isRegistered<SeerrPreferences>()) return const [];
    final prefs = GetIt.instance<SeerrPreferences>();
    if (!prefs.enabled) return const [];

    final repo = GetIt.instance<SeerrRepository>();
    await LiveDownloadProgress.refresh();
    // Seerr filter values: 'processing' = currently downloading or
    // partially-available, 'pending' = awaiting approval. Both produce a
    // progress bar that the user expects to see.
    final filters = ['processing', 'pending'];
    final results = <SeerrRequest>[];
    for (final filter in filters) {
      try {
        final page = await repo.getRequests(filter: filter, limit: 50);
        results.addAll(page.results);
      } catch (_) {}
    }

    final out = <SeerrActiveDownload>[];
    final claimed = <String>{};
    for (final req in results) {
      final media = req.media;
      if (media == null) continue;
      final type = media.mediaType ?? req.type;
      final tmdbId = type == 'movie' ? media.tmdbId : null;
      final tvdbId = type == 'tv' ? media.tvdbId : null;
      final hd = SeerrDownloadSummary.forMedia(
        status: media.status,
        items: media.downloadStatus,
        tmdbId: req.is4k ? null : tmdbId,
        tvdbId: req.is4k ? null : tvdbId,
      );
      final uhd = SeerrDownloadSummary.forMedia(
        status: media.status4k,
        items: media.downloadStatus4k,
        tmdbId: req.is4k ? tmdbId : null,
        tvdbId: req.is4k ? tvdbId : null,
      );
      if (hd == null && uhd == null) continue;
      claimed.addAll([
        for (final q in LiveDownloadProgress.queue)
          if (LiveDownloadProgress.matches(q, tmdbId: tmdbId, tvdbId: tvdbId)) q.downloadId,
        for (final i in [...?media.downloadStatus, ...?media.downloadStatus4k])
          if (i.downloadId != null) i.downloadId!.toUpperCase(),
      ]);
      out.add(SeerrActiveDownload(
        requestId: req.id,
        title: media.title ?? media.name ?? '',
        mediaType: media.mediaType ?? req.type,
        is4k: req.is4k,
        hdSummary: hd,
        uhdSummary: uhd,
      ));
    }
    out.addAll(_withoutRequest(claimed));
    return out;
  }

  /// Downloads no Seerr request shows yet: a request Seerr has not marked as
  /// processing, or episodes picked with Download Now, which never get one.
  /// One row per movie or series, with a negative id so it never clashes
  /// with a request's.
  static List<SeerrActiveDownload> _withoutRequest(Set<String> claimed) {
    final groups = <String, List<TortugarrQueueItem>>{};
    for (final q in LiveDownloadProgress.queue) {
      if (claimed.contains(q.downloadId) || q.size <= 0) continue;
      final key = q.kind == 'movie' ? 'm${q.tmdbId ?? q.downloadId}' : 't${q.tvdbId ?? q.downloadId}';
      groups.putIfAbsent(key, () => []).add(q);
    }
    return [
      for (final e in groups.entries)
        if (SeerrDownloadSummary.fromItems([
          for (final q in e.value)
            SeerrDownloadingItem(size: q.size, sizeLeft: q.sizeLeft, downloadId: q.downloadId),
        ]) case final summary?)
          SeerrActiveDownload(
            requestId: -(e.key.hashCode & 0x3fffffff) - 1,
            title: e.value.first.name ?? '',
            mediaType: e.value.first.kind == 'movie' ? 'movie' : 'tv',
            is4k: false,
            hdSummary: summary,
          ),
    ];
  }

  bool _listEquals(List<SeerrActiveDownload> a, List<SeerrActiveDownload> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.requestId != y.requestId ||
          x.fraction != y.fraction ||
          x.isImporting != y.isImporting) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
