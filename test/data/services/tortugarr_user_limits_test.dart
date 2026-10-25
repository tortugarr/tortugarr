import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';
import 'package:moonfin/data/services/download/sonarr_client.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/ui/widgets/download_now/plugin_download_flow.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Download limits per user (spec 3.16, user 2026-10-25): the daughter may
/// fetch at most 2.5 GB per movie and 950 MB per episode.
void main() {
  setUpAll(() => debugAppLocaleOverride = const Locale('en'));
  tearDownAll(() => debugAppLocaleOverride = null);

  const limitsJson = {
    'maxMovieMb': 2560,
    'maxEpisodeMb': 950,
    'moviesPerWeek': 4,
    'episodesPerWeek': 5,
    'moviesUsed': 1,
    'episodesUsed': 3,
  };

  test('capabilities carry a limited downloader\'s limits', () {
    final caps = TortugarrCapabilities.fromJson({
      'isAdmin': false,
      'features': {'downloadNow': true, 'missingEpisodes': true},
      'limits': limitsJson,
    });
    expect(caps.downloadNow, isTrue);
    expect(caps.limits!.maxMovieMb, 2560);
    expect(caps.limits!.episodesUsed, 3);
    expect(TortugarrCapabilities.fromJson({'isAdmin': true}).limits, isNull);
  });

  test('the limits read like the user wrote them', () {
    final l = TortugarrUserLimits.fromJson(limitsJson);
    expect(
      l.describe(),
      'This week: 1 of 4 movies, 3 of 5 episodes · max 2.5 GB per movie, max 950 MB per episode',
    );
    expect(const TortugarrUserLimits(maxEpisodeMb: 950).describe(), 'max 950 MB per episode');
    expect(TortugarrUserLimits.showMb(2048), '2 GB');
  });

  test('an over-limit release is greyed in the picker with the reason', () {
    final r = TortugarrRelease.fromJson({
      'guid': 'g1',
      'title': 'Dune.2021.2160p.WEB-DL',
      'size': 30 * 1024 * 1024 * 1024,
      'approved': false,
      'recommended': false,
      'overLimit': true,
      'rejections': ['Over your size limit (2.5 GB per movie)', 'Outside the quality profile'],
    });
    expect(r.overLimit, isTrue);
    expect(asPickerRelease(r).blockedReason, 'Over your size limit (max 2.5 GB per movie)');
    expect(asPickerRelease(TortugarrRelease.fromJson({'guid': 'g2'})).blockedReason, isNull);
  });

  test('refused grabs get the user\'s words', () {
    expect(
      explainPluginError(const TortugarrPluginException(403, 'limit_exceeded', 'Over your size limit (950 MB per episode)')),
      'This file is over your size limit (max 950 MB per episode).',
    );
    expect(
      explainPluginError(const TortugarrPluginException(403, 'quota_exceeded', 'You have used 4 of 4 movies this week')),
      "You have used this week's downloads (4 of 4 movies).",
    );
  });

  test('missing episodes: an over-limit file is blocked and goes last', () {
    SonarrRelease rel(String title, {List<String> rejections = const []}) => SonarrRelease(
          guid: title,
          indexerId: 1,
          indexer: 'X',
          title: title,
          size: 2 * 1024 * 1024 * 1024,
          seeders: 50,
          protocol: 'torrent',
          quality: 'WEBDL-1080p',
          approved: rejections.isEmpty,
          rejections: rejections,
        );
    final options = MissingEpisodes.pickable([
      rel('Show.S01E01.2160p.WEB.H265-BIG', rejections: ['Over your size limit (950 MB per episode)']),
      rel('Show.S01E01.1080p.WEB.H264-OK'),
    ]);
    expect([for (final o in options) o.release.title], ['Show.S01E01.1080p.WEB.H264-OK', 'Show.S01E01.2160p.WEB.H265-BIG']);
    expect(options.last.blocked, isTrue);
    expect(options.last.softReason, 'Over your size limit (max 950 MB per episode)');
    expect(options.first.blocked, isFalse);
  });
}
