import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/download_now/download_now_button.dart';
import 'package:moonfin/ui/widgets/download_now/download_now_dialog.dart';

void main() {
  test('whole seasons become season searches, picked episodes one search each', () {
    final jobs = pluginTvJobs(
      const DownloadNowChoice(seasons: [1, 2], episodes: {2: [3, 5]}),
      allSeasons: const [1, 2, 3],
    );
    expect([for (final j in jobs) j.search], [
      {'type': 'season', 'season': 1},
      {'type': 'episode', 'season': 2, 'episode': 3},
      {'type': 'episode', 'season': 2, 'episode': 5},
    ]);
    expect([for (final j in jobs) j.label], ['S01', 'S02E03', 'S02E05']);
  });

  test('no seasons picked means every season', () {
    final jobs = pluginTvJobs(const DownloadNowChoice(), allSeasons: const [1, 2]);
    expect([for (final j in jobs) j.search['season']], [1, 2]);
    expect(jobs.every((j) => j.search['type'] == 'season'), isTrue);
  });

  test('all episodes of a season picked is one season search', () {
    final jobs = pluginTvJobs(
      const DownloadNowChoice(seasons: [1], episodes: {1: [1, 2, 3]}),
      allSeasons: const [1],
      episodeCounts: const {1: 3},
    );
    expect([for (final j in jobs) j.search], [
      {'type': 'season', 'season': 1},
    ]);
  });
}
