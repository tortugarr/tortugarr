import 'package:flutter/foundation.dart';

import '../../models/aggregated_item.dart';
import 'download_now_service.dart' show DownloadNowConfig;
import 'prowlarr_search_client.dart';
import 'sonarr_client.dart';
import '../tortugarr/download_features.dart';
import '../tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Why an episode Sonarr knows is not playable in the app.
enum MissingEpisodeState {
  /// Aired, no file: can be downloaded.
  missing,

  /// Not aired yet (or no air date known).
  unaired,

  /// In Sonarr's download queue.
  downloading,

  /// Sonarr has the file, Jellyfin has not picked it up yet.
  importing,
}

class MissingEpisode {
  final SonarrEpisode episode;
  final MissingEpisodeState state;

  const MissingEpisode(this.episode, this.state);

  int get season => episode.seasonNumber;
  int get number => episode.episodeNumber;
  String? get title => episode.title;
  DateTime? get airDate => episode.airDateUtc;
  bool get canDownload => state == MissingEpisodeState.missing;

  /// "S03E04".
  String get code =>
      'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';
}

/// One row in a season's episode list: an episode on disk, or a gap.
class SeasonEntry {
  final AggregatedItem? present;
  final MissingEpisode? missing;

  const SeasonEntry.present(AggregatedItem this.present) : missing = null;
  const SeasonEntry.missing(MissingEpisode this.missing) : present = null;

  bool get isMissing => missing != null;
}

/// What Sonarr knows about a series: every episode and what is downloading.
class SeriesEpisodeStatus {
  final int sonarrSeriesId;
  final String title;
  final List<SonarrEpisode> episodes;
  final Set<int> queuedEpisodeIds;

  /// Sonarr's monitoring per season number.
  final Map<int, bool> seasonMonitored;

  /// The series' TVDB id; the public build names the series by it on the
  /// Tortugarr plugin.
  final int? tvdbId;

  const SeriesEpisodeStatus({
    required this.sonarrSeriesId,
    required this.title,
    required this.episodes,
    this.queuedEpisodeIds = const {},
    this.seasonMonitored = const {},
    this.tvdbId,
  });

  SeriesEpisodeStatus withSeasonMonitored(Map<int, bool> monitored) =>
      SeriesEpisodeStatus(
        sonarrSeriesId: sonarrSeriesId,
        title: title,
        episodes: episodes,
        queuedEpisodeIds: queuedEpisodeIds,
        seasonMonitored: monitored,
        tvdbId: tvdbId,
      );
}

/// A release the user may pick. [softReason] is set when Sonarr would not
/// pick it on its own (outside the quality profile, too big); such releases
/// are listed after the recommended ones and dimmed.
class EpisodeReleaseOption {
  final SonarrRelease release;
  final String? softReason;

  const EpisodeReleaseOption(this.release, [this.softReason]);

  bool get recommended => softReason == null;
}

/// Merges Sonarr's episode list with what Jellyfin has, and picks releases.
/// Pure functions, so the rules can be tested without a server.
class MissingEpisodes {
  /// Episodes of [season] that have aired already. When a season is turned on
  /// without fetching what is missing, these stay unmonitored, so Sonarr only
  /// follows new episodes and neither fetches nor upgrades the old ones.
  static List<int> airedEpisodeIds(
    List<SonarrEpisode> episodes,
    int season,
    DateTime now,
  ) =>
      [
        for (final e in episodes)
          if (e.seasonNumber == season &&
              e.airDateUtc != null &&
              !e.airDateUtc!.isAfter(now))
            e.id,
      ];

  /// A season pack is offered from this many downloadable episodes up.
  static const int seasonPackThreshold = 3;

  /// Detail pages that list a series' episodes or seasons and so merge in
  /// Sonarr's missing ones. Episode pages count too: Continue Watching and
  /// Next Up open the episode, and its season list must match the series path.
  static bool appliesTo(String? itemType) =>
      itemType == 'Series' || itemType == 'Season' || itemType == 'Episode';

  /// The season whose episode list a detail page shows: the season itself,
  /// or the season an episode belongs to. Null for series pages.
  static int? seasonShownBy({
    required String? itemType,
    int? indexNumber,
    int? parentIndexNumber,
  }) =>
      switch (itemType) {
        'Season' => indexNumber,
        'Episode' => parentIndexNumber,
        _ => null,
      };

  static MissingEpisodeState stateFor(
    SonarrEpisode e,
    Set<int> queued,
    DateTime now,
  ) {
    if (queued.contains(e.id)) return MissingEpisodeState.downloading;
    if (e.hasFile) return MissingEpisodeState.importing;
    final aired = e.airDateUtc;
    if (aired == null || aired.isAfter(now)) return MissingEpisodeState.unaired;
    return MissingEpisodeState.missing;
  }

  /// Jellyfin's episode for [season]/[number], counting multi-episode files
  /// (IndexNumber 1, IndexNumberEnd 2 covers both).
  static bool _covers(AggregatedItem ep, int season, int number) {
    if (ep.parentIndexNumber != season) return false;
    final start = ep.indexNumber;
    if (start == null) return false;
    final end = _toInt(ep.rawData['IndexNumberEnd']) ?? start;
    return number >= start && number <= end;
  }

  static int? _toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

  /// The episode list for [season]: Jellyfin's episodes plus a placeholder
  /// for every episode Sonarr knows but Jellyfin does not have, in episode
  /// order.
  static List<SeasonEntry> mergeSeason({
    required List<AggregatedItem> present,
    required SeriesEpisodeStatus status,
    required int season,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now().toUtc();
    final inSeason =
        present.where((e) => e.parentIndexNumber == season).toList();
    // (episode number, insertion order, row). Jellyfin's episodes go in
    // first, so on a tie they keep their place before a placeholder.
    final rows = <(num, int, SeasonEntry)>[];
    for (final ep in inSeason) {
      rows.add((ep.indexNumber ?? 1 << 20, rows.length, SeasonEntry.present(ep)));
    }
    for (final e in status.episodes) {
      if (e.seasonNumber != season) continue;
      if (inSeason.any((p) => _covers(p, season, e.episodeNumber))) continue;
      rows.add((
        e.episodeNumber,
        rows.length,
        SeasonEntry.missing(
          MissingEpisode(e, stateFor(e, status.queuedEpisodeIds, at)),
        ),
      ));
    }
    rows.sort((a, b) {
      final byNumber = a.$1.compareTo(b.$1);
      return byNumber != 0 ? byNumber : a.$2.compareTo(b.$2);
    });
    return [for (final r in rows) r.$3];
  }

  /// Seasons Sonarr knows that Jellyfin has no episodes for at all, in
  /// order. Specials (season 0) only count when Jellyfin shows specials.
  static List<int> missingSeasons({
    required Iterable<int> presentSeasons,
    required SeriesEpisodeStatus status,
  }) {
    final have = presentSeasons.toSet();
    return ({
      for (final e in status.episodes)
        if (!have.contains(e.seasonNumber) &&
            (e.seasonNumber != 0 || have.contains(0)))
          e.seasonNumber,
    }.toList())
      ..sort();
  }

  static int downloadableCount(Iterable<SeasonEntry> entries) =>
      entries.where((e) => e.missing?.canDownload == true).length;

  static bool offerSeasonPack(Iterable<SeasonEntry> entries) =>
      downloadableCount(entries) >= seasonPackThreshold;

  /// Rejections that mean the release is useless: dead, blocked by the
  /// CAM/TS release profile, or not this show/episode at all.
  static final _hardRejection = RegExp(
    r'blocklist|not enough seeders|must not contain|terms which are not allowed|'
    r'unknown series|unable to parse|not requested|wasn.t requested|'
    r'does not match|doesn.t match|wrong (series|episode|season)',
    caseSensitive: false,
  );

  /// About episodes already on disk. A single episode with it is one the
  /// user has; for a season pack it only concerns the episodes they have,
  /// and the pack still fills the gaps.
  static final _existingFile = RegExp(
    r'existing file|not an upgrade|does not allow upgrades',
    caseSensitive: false,
  );

  /// Short Norwegian label for why Sonarr would not pick a release itself.
  @visibleForTesting
  static String softReasonLabel(String rejection) {
    final r = rejection.toLowerCase();
    final l = appL10n();
    if (r.contains('not wanted in profile')) return l.tgOutsideQualityProfile;
    if (r.contains('larger than maximum')) return l.tgLargerThanProfile;
    if (r.contains('smaller than minimum')) return l.tgSmallerThanProfile;
    if (r.contains('already')) return l.tgAlreadyExists;
    if (r.contains('disk space')) return l.tgMayNotFitDisk;
    return rejection;
  }

  static ProwlarrRelease _asProwlarr(SonarrRelease r) => ProwlarrRelease(
        guid: r.guid,
        title: r.title,
        size: r.size,
        indexerId: r.indexerId,
        indexer: r.indexer,
        seeders: r.seeders,
        leechers: r.leechers,
        protocol: r.protocol,
        magnetUrl: r.magnetUrl,
        downloadUrl: r.downloadUrl,
        publishDate: r.publishDate,
      );

  static int _tierRank(SonarrRelease r) =>
      switch (_asProwlarr(r).tierLabel) {
        '2160p' => 3,
        '1080p' => 2,
        '720p' => 1,
        _ => 0,
      };

  /// The releases worth showing, best first: season packs first when
  /// [seasonPack]; then recommended ones before those Sonarr would not pick
  /// itself; then by resolution and seeders. Uses the same CAM/TS/screener/exe,
  /// quality and size rules as the Download Now picker.
  static List<EpisodeReleaseOption> pickable(
    List<SonarrRelease> releases, {
    bool seasonPack = false,
  }) {
    final out = <EpisodeReleaseOption>[];
    for (final r in releases) {
      var rejections = r.rejections;
      if (rejections.any(_existingFile.hasMatch)) {
        if (!r.fullSeason) continue;
        rejections = [
          for (final x in rejections)
            if (!_existingFile.hasMatch(x)) x,
        ];
      }
      if (rejections.any(_hardRejection.hasMatch)) continue;
      if (!ProwlarrSearchClient.acceptsRelease(_asProwlarr(r), 'tv',
          needsLink: false)) {
        continue;
      }
      final soft = rejections.isEmpty ? null : softReasonLabel(rejections.first);
      out.add(EpisodeReleaseOption(r, soft));
    }
    out.sort((a, b) {
      if (seasonPack && a.release.fullSeason != b.release.fullSeason) {
        return a.release.fullSeason ? -1 : 1;
      }
      if (a.recommended != b.recommended) return a.recommended ? -1 : 1;
      final byTier = _tierRank(b.release).compareTo(_tierRank(a.release));
      if (byTier != 0) return byTier;
      return b.release.seeders.compareTo(a.release.seeders);
    });
    return out;
  }
}

class MissingEpisodesException implements Exception {
  final String message;
  const MissingEpisodesException(this.message);
  @override
  String toString() => message;
}

/// The text shown when Sonarr could not be asked; names the address the app
/// used so a wrong network (VPN, guest Wi-Fi) is easy to spot.
String unreachableMessage(String? detail) {
  final host = Uri.tryParse(DownloadNowConfig.sonarrBaseUrl)?.authority;
  final base = host == null || host.isEmpty
      ? appL10n().tgSonarrUnreachable
      : appL10n().tgSonarrUnreachableAt(host);
  return detail == null || detail.isEmpty ? base : '$base ($detail)';
}

/// Talks to Sonarr for the missing-episodes view.
class MissingEpisodesService {
  final SonarrClient _sonarr;

  MissingEpisodesService({SonarrClient? sonarr})
      : _sonarr = sonarr ?? SonarrClient();

  static bool get isConfigured =>
      DownloadFeatures.viaPlugin
          ? DownloadFeatures.missingEpisodes
          : DownloadNowConfig.sonarrBaseUrl.isNotEmpty &&
              DownloadNowConfig.sonarrApiKey.isNotEmpty;

  // Public build: the Tortugarr plugin names episodes by TVDB id, season and
  // number, and a grab needs the search's type and Sonarr id. Kept here
  // between the calls the views make (a new service object each time).
  static final _pluginEpisodes = <int, ({int tvdb, int season, int episode})>{};
  static final _pluginSeriesTvdb = <int, int>{};
  static final _pluginGrabs = <String, ({String type, int arrId})>{};

  TortugarrPluginClient get _plugin => TortugarrPluginClient();

  Future<T> _viaPlugin<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on TortugarrPluginException catch (e) {
      throw MissingEpisodesException(e.toString());
    }
  }

  /// Sonarr's view of the series with TVDB id [tvdbId]; null when Sonarr
  /// does not have it. Throws when Sonarr cannot be reached.
  Future<SeriesEpisodeStatus?> load(int tvdbId) => loadFor(tvdbId: tvdbId);

  /// Like [load], but falls back to the TMDB id when Jellyfin has no TVDB id
  /// for the series. Throws [MissingEpisodesException] with the reason when
  /// Sonarr cannot be reached.
  Future<SeriesEpisodeStatus?> loadFor({int? tvdbId, int? tmdbId}) async {
    if (DownloadFeatures.viaPlugin) {
      if (tvdbId == null) return null;
      return _viaPlugin(() => _loadFromPlugin(tvdbId));
    }
    final found = tvdbId != null
        ? await _sonarr.seriesByTvdb(tvdbId)
        : tmdbId != null
            ? await _sonarr.seriesByTmdb(tmdbId)
            : (ok: true, series: null);
    if (!found.ok) {
      throw MissingEpisodesException(unreachableMessage(_sonarr.lastError));
    }
    final series = found.series;
    if (series == null) return null;
    final results = await Future.wait([
      _sonarr.getEpisodes(series.id),
      _sonarr.queuedEpisodeIds(series.id),
    ]);
    return SeriesEpisodeStatus(
      sonarrSeriesId: series.id,
      title: series.title,
      episodes: results[0] as List<SonarrEpisode>,
      queuedEpisodeIds: results[1] as Set<int>,
      seasonMonitored: series.seasonMonitored,
    );
  }

  Future<SeriesEpisodeStatus?> _loadFromPlugin(int tvdbId) async {
    final data = await _plugin.seriesStatus(tvdbId);
    if (data == null) return null;
    final seriesId = (data['arrId'] as num?)?.toInt() ?? 0;
    _pluginSeriesTvdb[seriesId] = tvdbId;
    final episodes = <SonarrEpisode>[];
    for (final s in (data['seasons'] as List? ?? const []).whereType<Map>()) {
      for (final e in (s['episodes'] as List? ?? const []).whereType<Map>()) {
        final ep = SonarrEpisode(
          id: (e['episodeId'] as num?)?.toInt() ?? 0,
          seasonNumber: (e['seasonNumber'] as num?)?.toInt() ?? 0,
          episodeNumber: (e['episodeNumber'] as num?)?.toInt() ?? 0,
          monitored: e['monitored'] == true,
          title: e['title'] as String?,
          hasFile: e['hasFile'] == true,
          airDateUtc: DateTime.tryParse(e['airDateUtc'] as String? ?? ''),
        );
        _pluginEpisodes[ep.id] = (tvdb: tvdbId, season: ep.seasonNumber, episode: ep.episodeNumber);
        episodes.add(ep);
      }
    }
    return SeriesEpisodeStatus(
      sonarrSeriesId: seriesId,
      title: data['title'] as String? ?? '',
      episodes: episodes,
      queuedEpisodeIds: {
        for (final id in (data['queuedEpisodeIds'] as List? ?? const []))
          if (id is num) id.toInt(),
      },
      seasonMonitored: TortugarrPluginClient.seasonMonitoringOf(data['seasonMonitoring']),
      tvdbId: tvdbId,
    );
  }

  /// Plugin releases in the shape the release list shows; remembers how to
  /// grab each one.
  List<EpisodeReleaseOption> _pluginPickable(
    TortugarrSearchResult result,
    String type, {
    bool seasonPack = false,
  }) {
    final releases = <SonarrRelease>[];
    for (final r in result.releases) {
      _pluginGrabs[r.guid] = (type: type, arrId: result.arrId);
      releases.add(SonarrRelease(
        guid: r.guid,
        indexerId: r.indexerId,
        indexer: r.indexer,
        title: r.title,
        size: r.size,
        seeders: r.seeders,
        leechers: r.leechers,
        protocol: r.protocol,
        quality: r.quality ?? '',
        approved: r.approved,
        publishDate: r.publishDate,
        fullSeason: r.seasonPack,
        // The list shows the first reason under a release: say it is SD.
        rejections: [if (r.sd) 'SD (low quality)', ...r.rejections],
      ));
    }
    return MissingEpisodes.pickable(releases, seasonPack: seasonPack);
  }

  /// Turns Sonarr's monitoring of [season] on or off. On with [searchNow]
  /// also searches for the season's missing episodes; on without it follows
  /// only episodes that have not aired yet. Returns the monitoring per season
  /// afterwards. Throws [MissingEpisodesException] when Sonarr refuses.
  Future<Map<int, bool>> setSeasonMonitoring(
    SeriesEpisodeStatus status,
    int season, {
    required bool on,
    bool searchNow = false,
    DateTime? now,
  }) async {
    final tvdb = status.tvdbId;
    if (DownloadFeatures.viaPlugin && tvdb != null) {
      final r = await _viaPlugin(() =>
          _plugin.setSeasonMonitoring(tvdb, season, monitored: on, search: on && searchNow));
      if (on && searchNow && !r.searchQueued) {
        throw MissingEpisodesException(appL10n().tgSeasonMonitoredNoSearch);
      }
      return r.seasons;
    }
    final result = await _sonarr.setSeasonMonitored(status.sonarrSeriesId, season, on);
    if (result == null) {
      throw MissingEpisodesException(appL10n().tgSonarrRejectedChange);
    }
    if (on && !searchNow) {
      final aired = MissingEpisodes.airedEpisodeIds(
        status.episodes,
        season,
        now ?? DateTime.now().toUtc(),
      );
      await _sonarr.setEpisodesMonitored(aired, false);
    }
    if (on && searchNow) {
      final ok = await _sonarr.searchSeason(status.sonarrSeriesId, season);
      if (!ok) {
        throw MissingEpisodesException(appL10n().tgSeasonMonitoredNoSearch);
      }
    }
    return result;
  }

  Future<List<EpisodeReleaseOption>> searchEpisode(int episodeId) async {
    final ep = _pluginEpisodes[episodeId];
    if (DownloadFeatures.viaPlugin && ep != null) {
      final result = await _viaPlugin(() => _plugin.search({
            'type': 'episode',
            'tvdbId': ep.tvdb,
            'season': ep.season,
            'episode': ep.episode,
          }));
      return _pluginPickable(result, 'episode');
    }
    final found = await _sonarr.interactiveSearch(episodeId: episodeId);
    if (found == null) {
      throw MissingEpisodesException(appL10n().tgSonarrCantSearch);
    }
    return MissingEpisodes.pickable(found);
  }

  Future<List<EpisodeReleaseOption>> searchSeason(
    int seriesId,
    int season,
  ) async {
    final tvdb = _pluginSeriesTvdb[seriesId];
    if (DownloadFeatures.viaPlugin && tvdb != null) {
      final result = await _viaPlugin(
          () => _plugin.search({'type': 'season', 'tvdbId': tvdb, 'season': season}));
      return _pluginPickable(result, 'season', seasonPack: true);
    }
    final found = await _sonarr.interactiveSearch(
      seriesId: seriesId,
      seasonNumber: season,
    );
    if (found == null) {
      throw MissingEpisodesException(appL10n().tgSonarrCantSearch);
    }
    return MissingEpisodes.pickable(found, seasonPack: true);
  }

  /// Sonarr downloads, imports and renames the release itself. Returns the
  /// download id when the Tortugarr plugin took it (public build).
  Future<String?> grab(SonarrRelease release) async {
    final how = _pluginGrabs[release.guid];
    if (DownloadFeatures.viaPlugin && how != null) {
      final grab = await _viaPlugin(() => _plugin.grab(
            type: how.type,
            arrId: how.arrId,
            release: TortugarrRelease(
              guid: release.guid,
              indexerId: release.indexerId,
              indexer: release.indexer,
              title: release.title,
              size: release.size,
              seeders: release.seeders,
              leechers: release.leechers ?? 0,
            ),
            // A release Sonarr would not pick itself was shown with its reason
            // and picked anyway: the plugin's force.
            force: !release.approved,
          ));
      return grab.downloadId;
    }
    final res = await _sonarr.grabRelease(
      guid: release.guid,
      indexerId: release.indexerId,
    );
    if (!res.ok) {
      throw MissingEpisodesException(res.status == 404
          ? appL10n().tgSearchExpired
          : appL10n().tgSonarrRejectedDownload('${res.status ?? '?'}'));
    }
    return null;
  }

  /// Adds the series unmonitored and without searching.
  Future<bool> addSeries(int tvdbId) async {
    if (DownloadFeatures.viaPlugin) {
      // The plugin adds a missing series unmonitored when a season is set;
      // season 1 off changes nothing else.
      try {
        await _plugin.setSeasonMonitoring(tvdbId, 1, monitored: false);
        return true;
      } catch (_) {
        return false;
      }
    }
    return await _sonarr.addSeriesUnmonitoredByTvdb(tvdbId) != null;
  }
}
