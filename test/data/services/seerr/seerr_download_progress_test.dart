import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/seerr/seerr_download_progress.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';

void main() {
  const gb = 1000 * 1000 * 1000;

  // Sonarr's queue has one entry per episode, each with the whole pack's
  // size. A 9 episode pack at 75% read as 9 times its size.
  test('a season pack counts once, not once per episode', () {
    final items = [
      for (var i = 0; i < 9; i++)
        const SeerrDownloadingItem(
          size: 10 * gb,
          sizeLeft: 2 * gb,
          downloadId: 'S03',
        ),
      for (var i = 0; i < 10; i++)
        const SeerrDownloadingItem(
          size: 14 * gb,
          sizeLeft: 14 * gb,
          downloadId: 'S04',
        ),
    ];

    final summary = SeerrDownloadSummary.fromItems(items)!;
    expect(summary.totalBytes, 24 * gb);
    expect(summary.downloadedBytes, 8 * gb);
    expect(summary.percent, 33);
  });

  // A release held back by a delay profile is listed once per episode with
  // the whole release's size and no download id. It read as a 107 GB total
  // at 0% next to a pack that was really downloading.
  test('held back releases are left out', () {
    final summary = SeerrDownloadSummary.fromItems([
      for (var i = 0; i < 10; i++)
        const SeerrDownloadingItem(size: 23 * gb, sizeLeft: 23 * gb),
      const SeerrDownloadingItem(
        size: 19 * gb,
        sizeLeft: 5 * gb,
        downloadId: 'S06',
      ),
    ])!;
    expect(summary.totalBytes, 19 * gb);
    expect(summary.downloadedBytes, 14 * gb);
  });

  test('only held back releases draw no bar', () {
    final summary = SeerrDownloadSummary.fromItems(const [
      SeerrDownloadingItem(size: 23 * gb, sizeLeft: 23 * gb),
    ]);
    expect(summary, isNull);
  });

  test('the id is read from the Seerr payload', () {
    final item = SeerrDownloadingItem.fromJson(const {
      'size': 100,
      'sizeLeft': 40,
      'downloadId': 'SABnzbd_nzo_abc',
    });
    expect(item.downloadId, 'SABnzbd_nzo_abc');
  });

  test('live qBittorrent figures win over the minute-old Seerr ones', () {
    LiveDownloadProgress.setForTest({'ABC': 0});
    final s = SeerrDownloadSummary.fromItems(const [
      SeerrDownloadingItem(size: 1000, sizeLeft: 830, downloadId: 'abc'),
    ])!;
    expect(s.percent, 100);
    LiveDownloadProgress.setForTest(null);
    final old = SeerrDownloadSummary.fromItems(const [
      SeerrDownloadingItem(size: 1000, sizeLeft: 830, downloadId: 'abc'),
    ])!;
    expect(old.percent, 17);
  });

  test('a download Radarr has finished importing draws no bar', () {
    LiveDownloadProgress.setForTest({'OTHER': 10});
    expect(
      SeerrDownloadSummary.fromItems(const [
        SeerrDownloadingItem(size: 1000, sizeLeft: 0, downloadId: 'abc'),
      ]),
      isNull,
    );
    LiveDownloadProgress.setForTest(null);
  });

  // 2026-10-20 on the TV: a new download first showed at 30-60 %, once Seerr
  // had synced it from Radarr. Radarr's queue has it within seconds.
  test('a download Seerr has not synced yet shows from the queue', () {
    LiveDownloadProgress.setQueueForTest(const [
      TortugarrQueueItem(downloadId: 'NEW', kind: 'movie', tmdbId: 7, size: 1000, sizeLeft: 900),
      TortugarrQueueItem(downloadId: 'EP', kind: 'episode', tvdbId: 7, size: 500, sizeLeft: 0),
    ]);
    final movie = SeerrDownloadSummary.forMedia(status: 3, items: const [], tmdbId: 7)!;
    expect(movie.percent, 10);
    expect(movie.totalBytes, 1000);
    // TMDB numbers movies and series apart: the series with tvdb 7 is not it.
    expect(SeerrDownloadSummary.forMedia(status: 3, items: null, tmdbId: 8), isNull);
    // Available in Seerr, but Radarr is fetching for it: the queue shows it.
    expect(SeerrDownloadSummary.forMedia(status: 5, items: null, tmdbId: 7)!.percent, 10);
    // Seerr's own leftovers for an available title do not.
    expect(
      SeerrDownloadSummary.forMedia(
        status: 5,
        items: const [SeerrDownloadingItem(size: 1000, sizeLeft: 500, downloadId: 'OLD')],
        tmdbId: 8,
      ),
      isNull,
    );
    LiveDownloadProgress.setForTest(null);
  });

  test('a download Seerr already lists is counted once', () {
    LiveDownloadProgress.setQueueForTest(const [
      TortugarrQueueItem(downloadId: 'ABC', kind: 'movie', tmdbId: 7, size: 1000, sizeLeft: 500),
    ]);
    final s = SeerrDownloadSummary.forMedia(
      status: 3,
      items: const [SeerrDownloadingItem(size: 1000, sizeLeft: 900, downloadId: 'abc')],
      tmdbId: 7,
    )!;
    expect(s.totalBytes, 1000);
    expect(s.percent, 50);
    LiveDownloadProgress.setForTest(null);
  });

  test('an older plugin without size: worked out from the progress', () {
    final q = TortugarrQueueItem.fromJson(const {
      'downloadId': 'abc', 'kind': 'movie', 'title': 'Some.Movie.2024.1080p', 'progress': 0.75, 'sizeLeft': 250,
    });
    expect(q.downloadId, 'ABC');
    expect(q.size, 1000);
    expect(q.name, 'Some.Movie.2024.1080p');
  });
}
