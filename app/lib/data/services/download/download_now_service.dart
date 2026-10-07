import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart' show MediaServerClient;

import '../log_service.dart';
import '../../repositories/seerr_repository.dart';
import '../seerr/seerr_error.dart';
import '../../../ui/navigation/home_refresh_bus.dart';
import 'prowlarr_search_client.dart';
import 'qbittorrent_client.dart';
import 'radarr_client.dart';
import 'sonarr_client.dart';
import 'download_now_secrets.dart';
import 'package:moonfin/util/app_l10n.dart';
import 'package:moonfin/util/build_flavor.dart';

/// Quality tiers for the Download Now cascade.
///
/// The cascade the user specified:
///  - default is [uhd2160]
///  - if no 2160p source exists, fall back to [hd1080]
///  - if that also does not exist, [sd720] is ONLY used after the user
///    explicitly confirms (never silently below 1080p).
enum DownloadQualityTier { uhd2160, hd1080, sd720 }

extension DownloadQualityTierLabel on DownloadQualityTier {
  String get label => switch (this) {
        DownloadQualityTier.uhd2160 => '2160p',
        DownloadQualityTier.hd1080 => '1080p',
        DownloadQualityTier.sd720 => '720p',
      };
}

/// What the availability probe found on the indexers for a title.
class DownloadAvailability {
  final bool has2160p;
  final bool has1080p;
  final bool has720p;

  const DownloadAvailability({
    this.has2160p = false,
    this.has1080p = false,
    this.has720p = false,
  });

  /// The tier the cascade would pick WITHOUT asking the user, or null when
  /// only 720p (or nothing) exists and the user must decide.
  DownloadQualityTier? get bestAutoTier {
    if (has2160p) return DownloadQualityTier.uhd2160;
    if (has1080p) return DownloadQualityTier.hd1080;
    return null;
  }
}

/// Outcome of a Download Now action.
class DownloadNowResult {
  final int requestId;
  final DownloadQualityTier tier;
  final bool autoApproved;

  const DownloadNowResult({
    required this.requestId,
    required this.tier,
    required this.autoApproved,
  });
}

/// Internal carrier for the Sonarr episode path. The Seerr path returns
/// the real request id; the Sonarr-only path uses 0 because there is no
/// Seerr request — Sonarr does the work itself.
class _SonarrEpisodeResult {
  final int requestId;
  const _SonarrEpisodeResult({required this.requestId});
}

/// Connection details for the Prowlarr instance used to probe which
/// qualities actually exist on the indexers before a download is started,
/// the Sonarr instance used to monitor specific episodes when the user
/// opts out of full-season downloads, and the qBittorrent instance used
/// when the user picks a specific release (so we can drop it straight
/// into the download client, where Radarr/Sonarr can auto-import it).
///
/// The actual secret values live in [DownloadNowSecrets] (in
/// `download_now_secrets.dart`, which is gitignored) so this file can be
/// committed without leaking credentials. With empty secrets the feature
/// fails gracefully — every client call returns null/empty rather than
/// crashing.
class DownloadNowConfig {
  /// Download Now and the other direct *arr/qBittorrent features: never in the
  /// public build, and only when this build has the addresses compiled in.
  static bool get isAvailable =>
      !kTortugarrPublic &&
      prowlarrBaseUrl.isNotEmpty &&
      radarrBaseUrl.isNotEmpty &&
      sonarrBaseUrl.isNotEmpty &&
      qbittorrentBaseUrl.isNotEmpty;

  static const String prowlarrBaseUrl = kTortugarrPublic ? '' : DownloadNowSecrets.prowlarrBaseUrl;
  static const String prowlarrApiKey = kTortugarrPublic ? '' : DownloadNowSecrets.prowlarrApiKey;
  static const String sonarrBaseUrl = kTortugarrPublic ? '' : DownloadNowSecrets.sonarrBaseUrl;
  static const String sonarrApiKey = kTortugarrPublic ? '' : DownloadNowSecrets.sonarrApiKey;
  static const String qbittorrentBaseUrl = kTortugarrPublic ? '' : DownloadNowSecrets.qbittorrentBaseUrl;
  static const String qbittorrentUsername = kTortugarrPublic ? '' : DownloadNowSecrets.qbittorrentUsername;
  static const String qbittorrentPassword = kTortugarrPublic ? '' : DownloadNowSecrets.qbittorrentPassword;
  // Must match Radarr → Settings → Download Clients → qBittorrent →
  // Category. qBittorrent saves the torrent under
  // H:\Downloads\<category>\<release>, and that's the only path shape
  // the Radarr remote path mapping knows how to translate back to a
  // nix path on the Radarr host.
  static const String qbittorrentMovieCategory = 'radarr';
  // Same idea for series: must match Sonarr → Settings → Download Clients →
  // qBittorrent → Category so the Sonarr remote path mapping can translate
  // the download path back to a nix path on the Sonarr host.
  static const String qbittorrentTvCategory = 'sonarr';
  static const String radarrBaseUrl = kTortugarrPublic ? '' : DownloadNowSecrets.radarrBaseUrl;
  static const String radarrApiKey = kTortugarrPublic ? '' : DownloadNowSecrets.radarrApiKey;
  static const String bazarrBaseUrl = kTortugarrPublic ? '' : DownloadNowSecrets.bazarrBaseUrl;
  static const String bazarrApiKey = kTortugarrPublic ? '' : DownloadNowSecrets.bazarrApiKey;
}

/// One-tap downloads.
///
/// "Download Now" is deliberately NOT a "request": the service creates the
/// request through the Seerr proxy and immediately approves it, so the user
/// never sees the request/approve/download panel dance. Quality is chosen by
/// probing the indexers (Prowlarr) so "if no 2160p exists" is a real
/// detection, not a guess.
class DownloadNowService {
  SeerrRepository? _seerrOverride;
  final Dio _dio;

  static LogService? get _log => GetIt.instance.isRegistered<LogService>()
      ? GetIt.instance<LogService>()
      : null;

  DownloadNowService({SeerrRepository? seerrRepository, Dio? dio})
      : _seerrOverride = seerrRepository,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ));

  /// Resolved lazily: SeerrRepository is registered as an async singleton,
  /// so grabbing it in the constructor could run before it is ready. By the
  /// time the user taps Download Now it always is.
  SeerrRepository get _seerr =>
      _seerrOverride ??= GetIt.instance<SeerrRepository>();

  static final RegExp _re2160 =
      RegExp(r'2160p|4k|uhd|ultra[.\s_-]?hd', caseSensitive: false);
  static final RegExp _re1080 = RegExp(r'1080p|1080i', caseSensitive: false);
  static final RegExp _re720 = RegExp(r'720p', caseSensitive: false);

  /// Probe the indexers for which qualities exist for [title] right now.
  ///
  /// [year] narrows the free-text search. On ANY probe failure we return an
  /// "everything available" availability so the cascade simply picks the
  /// 2160p default — the download services themselves still enforce what can
  /// actually be grabbed, and the user is never pushed below 1080p silently
  /// because of a network hiccup.
  Future<DownloadAvailability> probeAvailability({
    required String title,
    required String mediaType,
    int? year,
  }) async {
    try {
      final query = year != null ? '$title $year' : title;
      final response = await _dio.get(
        '${DownloadNowConfig.prowlarrBaseUrl}/api/v1/search',
        queryParameters: {
          'query': query,
          'type': 'search',
          'limit': 100,
          // Prowlarr newznab categories: 2000 = movies, 5000 = TV.
          'categories': mediaType == 'movie' ? [2000] : [5000],
        },
        options: Options(headers: {
          'X-Api-Key': DownloadNowConfig.prowlarrApiKey,
        }),
      );
      if (response.statusCode != 200 || response.data is! List) {
        _log?.network(
          'DownloadNow probe HTTP ${response.statusCode} — assuming all tiers',
        );
        return const DownloadAvailability(
            has2160p: true, has1080p: true, has720p: true);
      }
      var has2160 = false, has1080 = false, has720 = false;
      for (final raw in response.data as List) {
        final t = (raw is Map ? raw['title'] : null)?.toString() ?? '';
        if (t.isEmpty) continue;
        if (_re2160.hasMatch(t)) {
          has2160 = true;
        } else if (_re1080.hasMatch(t)) {
          has1080 = true;
        } else if (_re720.hasMatch(t)) {
          has720 = true;
        }
      }
      // A title with no quality tag at all tells us nothing; if we saw no
      // tags whatsoever, fall back to "everything available".
      if (!has2160 && !has1080 && !has720 && (response.data as List).isEmpty) {
        return const DownloadAvailability(
            has2160p: true, has1080p: true, has720p: true);
      }
      return DownloadAvailability(
          has2160p: has2160, has1080p: has1080, has720p: has720);
    } catch (e) {
      _log?.network('DownloadNow probe failed: $e — assuming all tiers');
      return const DownloadAvailability(
          has2160p: true, has1080p: true, has720p: true);
    }
  }

  /// Execute a Download Now for a movie at [tier].
  Future<DownloadNowResult> downloadMovie({
    required int tmdbId,
    required DownloadQualityTier tier,
  }) =>
      _download(mediaId: tmdbId, mediaType: 'movie', tier: tier);

  /// Earliest digital or physical release of a movie according to Radarr.
  /// `known` is false when Radarr could not be asked; callers then carry on
  /// as before rather than warn about something they cannot check.
  Future<({bool known, DateTime? home})> movieHomeRelease(int tmdbId) async {
    final lookup = await RadarrClient().lookupByTmdb(tmdbId);
    if (lookup == null) return (known: false, home: null);
    DateTime? earliest;
    for (final key in ['digitalRelease', 'physicalRelease']) {
      final d = DateTime.tryParse(lookup[key] as String? ?? '');
      if (d != null && (earliest == null || d.isBefore(earliest))) earliest = d;
    }
    return (known: true, home: earliest);
  }

  /// Resolve a series title to its TMDB id through Seerr search. Used by the
  /// missing-episode flow, where Jellyfin only hands us the series NAME.
  Future<int?> resolveTvTmdbId(String seriesTitle) async {
    try {
      final page = await _seerr.search(seriesTitle, mediaType: 'tv');
      for (final item in page.results) {
        if (item.mediaType == 'tv' && item.id != 0) return item.id;
      }
    } catch (e) {
      debugPrint('[DownloadNow] resolveTvTmdbId failed: $e');
    }
    return null;
  }

  /// Execute a Download Now for one or more TV seasons at [tier].
  ///
  /// [seasons] is the set of seasons the user picked in the dialog. When
  /// [episodes] is empty for a season, Seerr handles it at the season level
  /// and Sonarr grabs whatever is missing. When [episodes] is non-empty for
  /// a season, we have to talk to Sonarr directly so we can monitor only
  /// the picked episodes.
  Future<DownloadNowResult> downloadTv({
    required int tmdbId,
    required List<int> seasons,
    required Map<int, List<int>> episodes,
    required DownloadQualityTier tier,
  }) async {
    final fullSeasons = <int>[];
    final partialSeasons = <int>[];
    for (final s in seasons) {
      final eps = episodes[s];
      if (eps == null || eps.isEmpty) {
        fullSeasons.add(s);
      } else {
        partialSeasons.add(s);
      }
    }

    // If all seasons are full (no partial), simple season-level request.
    if (partialSeasons.isEmpty) {
      return _download(
        mediaId: tmdbId,
        mediaType: 'tv',
        seasons: fullSeasons,
        tier: tier,
      );
    }

    // There are partial seasons. Only the FULL seasons go to Seerr: a Seerr
    // request monitors and searches whole seasons, so including a season the
    // user picked single episodes from would fetch all of it. The picked
    // episodes go straight to Sonarr.
    DownloadNowResult? seerrPart;
    if (fullSeasons.isNotEmpty) {
      seerrPart = await _download(
        mediaId: tmdbId,
        mediaType: 'tv',
        seasons: fullSeasons,
        tier: tier,
      );
    }

    // For partial seasons, monitor only the picked episodes and search for them.
    final sonarrPart = await _downloadEpisodes(
      tmdbId: tmdbId,
      episodesBySeason: {
        for (final s in partialSeasons) s: episodes[s]!,
      },
    );
    return DownloadNowResult(
      requestId: seerrPart?.requestId ?? sonarrPart.requestId,
      tier: tier,
      autoApproved: seerrPart?.autoApproved ?? true,
    );
  }

  Future<_SonarrEpisodeResult> _downloadEpisodes({
    required int tmdbId,
    required Map<int, List<int>> episodesBySeason,
  }) async {
    final client = SonarrClient();
    final series = await client.ensureSeriesByTmdb(tmdbId);
    if (series == null) {
      // We can't reach Sonarr or the series isn't in it. Per-episode
      // downloads need Sonarr — refuse rather than silently grabbing the
      // whole season (the "all episodes downloaded anyway" bug).
      throw Exception(appL10n().tgSonarrRequiredPerEpisode);
    }
    // Build the set of episode ids the user actually wants, then unmonitor
    // every other episode in those seasons so Sonarr doesn't go grab them.
    final wantedIds = <int>[];
    final unwantedIds = <int>[];
    for (final ep in series.episodes) {
      final wanted = episodesBySeason[ep.seasonNumber];
      if (wanted == null) continue;
      if (wanted.contains(ep.episodeNumber)) {
        wantedIds.add(ep.id);
      } else {
        unwantedIds.add(ep.id);
      }
    }
    if (wantedIds.isEmpty) {
      // The picked episode numbers did not match any in Sonarr. Refuse
      // rather than silently downloading the whole season — that was the
      // "all episodes downloaded anyway" bug. With [SonarrClient.getEpisodes]
      // wired in this should never trigger, but if it does, fail loudly.
      throw Exception(
        appL10n().tgEpisodesNotFound(series.title, series.episodes.length),
      );
    }
    if (unwantedIds.isNotEmpty) {
      await client.setEpisodesMonitored(unwantedIds, false);
    }
    await client.setEpisodesMonitored(wantedIds, true);
    await client.searchEpisodes(wantedIds);
    // Sonarr doesn't issue a Seerr request id, so reuse 0. The status
    // bar still shows the title, which is what the user actually sees.
    return _SonarrEpisodeResult(requestId: 0);
  }

  /// Creates and approves the Seerr request for a movie that is already in
  /// Radarr's queue, so it shows as requested (public build, after the
  /// plugin's grab answered `queued: true`).
  Future<DownloadNowResult> trackMovieInSeerr(int tmdbId, DownloadQualityTier tier) =>
      _download(mediaId: tmdbId, mediaType: 'movie', tier: tier);

  Future<DownloadNowResult> _download({
    required int mediaId,
    required String mediaType,
    List<int>? seasons,
    required DownloadQualityTier tier,
  }) async {
    final request = await _seerr.createRequest(
      mediaId: mediaId,
      mediaType: mediaType,
      seasons: seasons,
      allSeasons: mediaType == 'tv' && (seasons == null || seasons.isEmpty),
      is4k: tier == DownloadQualityTier.uhd2160,
      // Sonarr/Radarr quality profile 3 = HD-720p; only ever set when the
      // user explicitly accepted a 720p download.
      profileId: tier == DownloadQualityTier.sd720 ? 3 : null,
    );

    var approved = false;
    try {
      await _seerr.approveRequest(request.id);
      approved = true;
    } on SeerrRequestException catch (e) {
      // Admin requests usually auto-approve; an already-approved request
      // refusing a second approve is fine.
      debugPrint('[DownloadNow] approve skipped: ${e.serverMessage ?? e.kind.name}');
    } catch (e) {
      debugPrint('[DownloadNow] approve failed (request still created): $e');
    }

    return DownloadNowResult(
      requestId: request.id,
      tier: tier,
      autoApproved: approved,
    );
  }

  /// Send a user-picked [release] to the local *arr stack so it ends up
  /// in the movie library.
  ///
  /// 1. Ensure the movie exists in Radarr. A brand-new movie would
  ///    otherwise fail the grab with 400, leaving the torrent orphaned
  ///    in qBittorrent and never imported. We look the title up on TMDB
  ///    and add the movie with the right quality profile + root folder.
  /// 2. Try Radarr's release-grab endpoint. Radarr resolves the guid
  ///    through its indexer, pushes the torrent to qBittorrent, and
  ///    auto-imports the finished file into the movie library.
  /// 3. If Radarr still can't accept the guid (some indexers don't
  ///    expose the API the same way to Radarr), fall back to the magnet
  ///    URL and send it straight to qBittorrent. The file lands in the
  ///    watch folder Radarr monitors, so it still gets imported.
  Future<DownloadNowResult> downloadPickedRelease(
    ProwlarrRelease release, {
    required DownloadQualityTier tier,
    bool isMovie = true,
    int? tmdbId,
    List<int>? seasons,
  }) async {
    final effectiveTmdbId = (tmdbId != null && tmdbId > 0)
        ? tmdbId
        : (release.tmdbId != null && release.tmdbId! > 0
            ? release.tmdbId
            : null);
    // Try to grab via Radarr/Sonarr API so they push to qBittorrent themselves.
    // This avoids the direct qBittorrent cookie/auth issues entirely.
    if (isMovie) {
      final radarr = RadarrClient();
      if (effectiveTmdbId != null) {
        try {
          await _ensureMovieInRadarr(radarr, effectiveTmdbId, tier);
        } catch (e) {
          debugPrint('[DownloadNow] ensureMovieInRadarr failed: $e');
          rethrow;
        }
      } else {
        debugPrint(
          '[DownloadNow] release has no tmdbId, skipping Radarr pre-add: '
          '${release.title}',
        );
      }
      // Try Radarr grabRelease with Prowlarr's guid + indexerId.
      // Radarr resolves the guid through the indexer and pushes to qBittorrent.
      final grab = await radarr.grabRelease(
        guid: release.guid,
        indexerId: release.indexerId,
      );
      var tracked = grab.ok;
      if (!grab.ok) {
        debugPrint(
          '[DownloadNow] Radarr grabRelease failed (status ${grab.status}): '
          '${grab.body}; pushing the release instead',
        );
        tracked = await _push(release, radarr.pushRelease);
      }
      if (!tracked) {
        debugPrint('[DownloadNow] Radarr could not take it; qBittorrent direct');
      } else {
        debugPrint('[DownloadNow] Radarr is downloading the picked release');
        _schedulePostDownloadRefresh();
        // The Seerr request below makes Radarr search; it must already see
        // this download in its queue or it grabs a second copy.
        final movie = effectiveTmdbId != null
            ? await radarr.movieByTmdb(effectiveTmdbId)
            : null;
        if (movie != null) await radarr.waitUntilQueued(movie['id'] as int);
        if (effectiveTmdbId != null) {
          try {
            final seerrResult = await _download(
              mediaId: effectiveTmdbId,
              mediaType: 'movie',
              seasons: null,
              tier: tier,
            );
            return seerrResult;
          } catch (e) {
            debugPrint('[DownloadNow] Seerr tracking failed (grab succeeded): $e');
          }
        }
        return DownloadNowResult(
          requestId: 0,
          tier: tier,
          autoApproved: true,
        );
      }
    } else {
      // TV: the series must exist in Sonarr for the grab to have a target.
      if (effectiveTmdbId != null) {
        final sonarr = SonarrClient();
        final series = await sonarr.ensureSeriesByTmdb(effectiveTmdbId);
        if (series == null) {
          throw Exception(
            'Could not add the series to Sonarr — cannot grab '
            '"${release.title}".',
          );
        }
        final grab = await sonarr.grabRelease(
          guid: release.guid,
          indexerId: release.indexerId,
        );
        var tracked = grab.ok;
        if (!grab.ok) {
          debugPrint(
            '[DownloadNow] Sonarr grabRelease failed (status ${grab.status}): '
            '${grab.body}; pushing the release instead',
          );
          tracked = await _push(release, sonarr.pushRelease);
        }
        if (!tracked) {
          debugPrint('[DownloadNow] Sonarr could not take it; qBittorrent direct');
        } else {
          debugPrint('[DownloadNow] Sonarr is downloading the picked release');
          _schedulePostDownloadRefresh();
          // No Seerr request here. Seerr requests whole seasons (or, with no
          // seasons, the whole series), turns on monitoring and searches, so
          // one picked episode became a download of every season. Sonarr
          // already has exactly the release the user chose.
          return DownloadNowResult(
            requestId: 0,
            tier: tier,
            autoApproved: true,
          );
        }
      }
    }
    // Fallback: direct qBittorrent (only if Radarr/Sonarr grab failed).
    final category = isMovie
        ? DownloadNowConfig.qbittorrentMovieCategory
        : DownloadNowConfig.qbittorrentTvCategory;
    final prowlarr = ProwlarrSearchClient();
    final payload = await prowlarr.fetchPayload(release);
    debugPrint('[DownloadNow] Payload for "${release.title}": magnet=${payload.magnet != null}, torrentBytes=${payload.torrentBytes != null}, fileName=${payload.fileName}');

    if (payload.magnet == null && payload.torrentBytes == null) {
      throw Exception(
        'Could not get magnet link or torrent file for "${release.title}". '
        'The indexer may not provide a download URL. guid="${release.guid}", '
        'magnetUrl="${release.magnetUrl}", downloadUrl="${release.downloadUrl}"',
      );
    }
    final qb = QbittorrentClient();
    String? added;
    if (payload.magnet != null && payload.magnet!.isNotEmpty) {
      added = await qb.addMagnet(payload.magnet!, category: category);
    } else if (payload.torrentBytes != null) {
      added = await qb.addTorrentFile(
        payload.torrentBytes!,
        filename: payload.fileName,
        category: category,
      );
    }
    if (added == null) {
      throw Exception(
        'qBittorrent rejected the torrent for "${release.title}"',
      );
    }
    debugPrint(
      '[DownloadNow] qBittorrent fallback grabbed: ${release.title} '
      '(${release.sizeLabel})',
    );
    _schedulePostDownloadRefresh();
    // No Seerr request here: approving it makes Radarr/Sonarr search, and
    // they cannot see a torrent added straight to qBittorrent, so they would
    // download a second copy.
    return DownloadNowResult(
      requestId: 0,
      tier: tier,
      autoApproved: true,
    );
  }

  /// Push [release] to Radarr/Sonarr with whatever link Prowlarr gave us.
  Future<bool> _push(
    ProwlarrRelease release,
    Future<({bool ok, String? reason})> Function({
      required String title,
      required String downloadUrl,
      DateTime? publishDate,
      int? size,
      String? indexer,
    }) push,
  ) async {
    String? url;
    for (final candidate in [release.guid, release.magnetUrl]) {
      if (candidate != null && candidate.startsWith('magnet:')) {
        url = candidate;
        break;
      }
    }
    url ??= release.downloadUrl;
    if (url == null || url.isEmpty) return false;
    final result = await push(
      title: release.title,
      downloadUrl: url,
      publishDate: release.publishDate,
      size: release.size,
      indexer: release.indexer,
    );
    return result.ok;
  }

  /// Make sure [tmdbId] is in Radarr's library so a subsequent grab has
  /// a target. If the movie is already there, this is a no-op. If not,
  /// we look up its TMDB metadata and add it with the right quality
  /// profile and root folder for [tier].
  Future<void> _ensureMovieInRadarr(
    RadarrClient radarr,
    int tmdbId,
    DownloadQualityTier tier,
  ) async {
    final existing = await radarr.movieByTmdb(tmdbId);
    if (existing != null) return;

    final lookup = await radarr.lookupByTmdb(tmdbId);
    if (lookup == null) {
      throw Exception('Could not look up TMDB $tmdbId in Radarr');
    }

    final profiles = await radarr.qualityProfiles();
    final folders = await radarr.rootFolders();
    if (profiles.isEmpty || folders.isEmpty) {
      throw Exception('Radarr has no quality profiles or root folders');
    }
    final qualityId = _pickQualityProfileId(profiles, tier);
    folders.sort((a, b) =>
      (b['freeSpace'] as int? ?? 0).compareTo(a['freeSpace'] as int? ?? 0)
    );
    final rootFolder = folders.first['path'] as String? ?? '';
    if (rootFolder.isEmpty) {
      throw Exception('Radarr root folder has no path');
    }
    final ok = await radarr.addMovie(
      lookup: lookup,
      qualityProfileId: qualityId,
      rootFolderPath: rootFolder,
    );
    if (!ok) throw Exception('Failed to add movie to Radarr');
  }

  /// Map a [DownloadQualityTier] to a Radarr quality-profile id. We
  /// pick the profile whose name best matches the tier. Falls back to
  /// the first profile when nothing matches.
  int _pickQualityProfileId(
    List<Map<String, dynamic>> profiles,
    DownloadQualityTier tier,
  ) {
    final names = switch (tier) {
      DownloadQualityTier.uhd2160 => ['Ultra-HD', 'Ultra HD', '4K', '2160p'],
      DownloadQualityTier.hd1080 => [
          'HD-1080p',
          'HD 1080p',
          'HD - 1080p',
          '1080p',
        ],
      DownloadQualityTier.sd720 => ['HD-720p', 'HD 720p', 'HD - 720p', '720p'],
    };
    for (final target in names) {
      for (final p in profiles) {
        final name = (p['name'] as String? ?? '').trim();
        if (name.toLowerCase() == target.toLowerCase()) {
          return p['id'] as int? ?? 0;
        }
      }
    }
    return profiles.first['id'] as int? ?? 0;
  }

  /// After a Download Now succeeds, schedule a Jellyfin library scan and
  /// a Moonfin home refresh so the new file shows up in the app without
  /// the user having to dig into the admin menu.
  ///
  /// Radarr/Sonarr take a minute or two to import the file. Jellyfin's
  /// library scan then needs to run. We give it 90 seconds before the
  /// first scan and a second refresh 30 seconds later to cover the slow
  /// case where Radarr is still moving the file when Jellyfin first
  /// looks.
  void _schedulePostDownloadRefresh() {
    Timer(const Duration(seconds: 90), () async {
      try {
        if (GetIt.instance.isRegistered<MediaServerClient>()) {
          await GetIt.instance<MediaServerClient>().adminLibraryApi.refreshLibrary();
        }
      } catch (e) {
        debugPrint('[DownloadNow] library scan failed: $e');
      }
      homeRefreshBus.requestAfterNavigation();
    });
    Timer(const Duration(seconds: 120), () {
      homeRefreshBus.requestAfterNavigation();
    });
  }
}

/// Helper kept for json payloads returned by Prowlarr that are Maps.
// ignore: unused_element
Map<String, dynamic> _asMap(dynamic raw) =>
    raw is Map<String, dynamic> ? raw : jsonDecode(jsonEncode(raw));
