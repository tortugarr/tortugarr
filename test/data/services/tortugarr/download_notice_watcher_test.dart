import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/services/tortugarr/download_notice_watcher.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-11-07: the admin gets a popup when the plugin gives up a download.
void main() {
  late PreferenceStore store;
  late List<ActivityLogEntry> log;
  late List<DateTime> asked;
  var now = DateTime.utc(2026, 11, 7, 20);

  ActivityLogEntry entry(String type, DateTime at, [String name = 'Download given up: dengus']) =>
      ActivityLogEntry(id: '${at.millisecondsSinceEpoch}', name: name, type: type, date: at);

  DownloadNoticeWatcher watcher() => DownloadNoticeWatcher(
    store,
    now: () => now,
    fetch: (since) async {
      asked.add(since);
      return log;
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PreferenceStore();
    await store.init();
    log = [];
    asked = [];
    now = DateTime.utc(2026, 11, 7, 20);
  });

  test('the first look only marks the start: no flood of old entries', () async {
    log = [entry(DownloadNoticeWatcher.stallType, DateTime.utc(2026, 11, 1))];
    final w = watcher();
    final got = <List<ActivityLogEntry>>[];
    w.notices.listen(got.add);
    await w.check();
    await Future<void>.delayed(Duration.zero);
    expect(got, isEmpty);
    expect(asked, isEmpty);
  });

  test('a new give-up shows once, other log entries never', () async {
    final w = watcher();
    final got = <List<ActivityLogEntry>>[];
    w.notices.listen(got.add);
    await w.check(); // marks 20:00

    log = [
      entry('TortugarrQbit', DateTime.utc(2026, 11, 7, 20, 5), 'Download repaired'),
      entry(DownloadNoticeWatcher.stallType, DateTime.utc(2026, 11, 7, 20, 10)),
    ];
    await w.check();
    await w.check();
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    expect(got.single.single.name, 'Download given up: dengus');
    expect(asked.last, DateTime.utc(2026, 11, 7, 20, 10));
  });

  test('during playback it waits and shows the entry afterwards', () async {
    final w = watcher();
    final got = <List<ActivityLogEntry>>[];
    w.notices.listen(got.add);
    await w.check();
    log = [entry(DownloadNoticeWatcher.stallType, DateTime.utc(2026, 11, 7, 21))];

    w.canShow = () => false;
    await w.check();
    await Future<void>.delayed(Duration.zero);
    expect(got, isEmpty);

    w.canShow = () => true;
    await w.check();
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
  });

  test('an error leaves the entry for the next check', () async {
    var fail = true;
    final w = DownloadNoticeWatcher(
      store,
      now: () => now,
      fetch: (since) async {
        if (fail) throw Exception('offline');
        return [entry(DownloadNoticeWatcher.stallType, DateTime.utc(2026, 11, 7, 22))];
      },
    );
    final got = <List<ActivityLogEntry>>[];
    w.notices.listen(got.add);
    await w.check();
    await w.check();
    fail = false;
    await w.check();
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
  });
}
