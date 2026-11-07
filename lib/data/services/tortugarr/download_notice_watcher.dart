import 'dart:async';

import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:server_core/server_core.dart';

/// Popups for the administrator when the plugin gives up a download.
///
/// 2026-11-07: a torrent can stall for hours when no seed will send the rest.
/// After three hours the plugin swaps it for another release (Radarr/Sonarr)
/// or deletes it (XXX) and writes an activity log entry of type
/// [stallType]. The log is admin only, so other users never see these; this
/// watcher reads it every minute while an administrator is signed in and
/// hands new entries to the app, which shows them as a popup.
class DownloadNoticeWatcher {
  static const stallType = 'TortugarrStall';
  static const _seenKey = 'tortugarr_stall_notice_seen';

  final PreferenceStore _store;
  final Future<List<ActivityLogEntry>> Function(DateTime since) fetch;
  final DateTime Function() _now;
  final Duration every;

  /// False while the popup must wait (e.g. during playback). Entries stay
  /// unseen and come again on the next check.
  bool Function() canShow = () => true;

  final _notices = StreamController<List<ActivityLogEntry>>.broadcast();
  Timer? _timer;
  bool _checking = false;

  DownloadNoticeWatcher(
    this._store, {
    required this.fetch,
    DateTime Function()? now,
    this.every = const Duration(minutes: 1),
  }) : _now = now ?? DateTime.now;

  Stream<List<ActivityLogEntry>> get notices => _notices.stream;

  bool get active => _timer != null;

  /// On for an administrator, off for everyone else and after sign-out.
  void setActive(bool on) {
    if (on == active) return;
    _timer?.cancel();
    _timer = null;
    if (!on) return;
    _timer = Timer.periodic(every, (_) => unawaited(check()));
    unawaited(check());
  }

  /// One look at the log. The first ever look only marks the start, so an
  /// old history never floods the screen.
  Future<void> check() async {
    if (_checking || !canShow()) return;
    _checking = true;
    try {
      final seenText = _store.getString(_seenKey);
      final seen = seenText == null ? null : DateTime.tryParse(seenText);
      if (seen == null) {
        await _store.setString(_seenKey, _now().toUtc().toIso8601String());
        return;
      }

      final fresh =
          (await fetch(seen))
              .where((e) => e.type == stallType && e.date.toUtc().isAfter(seen))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (fresh.isEmpty) return;
      await _store.setString(_seenKey, fresh.last.date.toUtc().toIso8601String());
      _notices.add(fresh);
    } catch (_) {
      // Offline or not allowed: try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _notices.close();
  }
}
