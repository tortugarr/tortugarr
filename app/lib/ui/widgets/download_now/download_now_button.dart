import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../data/services/download/download_now_service.dart';
import '../../../data/services/seerr/seerr_api_models.dart' show SeerrSeason;
import 'download_now_dialog.dart';
import 'free_space_dialog.dart';
import '../../../data/services/download/release_video_guard.dart';
import 'plugin_download_flow.dart';
import 'release_picker_dialog.dart';
import '../../../data/services/tortugarr/download_features.dart';
import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/util/app_l10n.dart';

/// "Download Now" button. The user picks everything: seasons/episodes for
/// TV, then the exact release (resolution + size) from the Prowlarr picker.
/// No automatic quality cascade.
class DownloadNowButton extends StatefulWidget {
  /// TMDB id of the movie/series.
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final int? year;

  /// TV only: seasons to download (missing episodes are grabbed by Sonarr).
  final List<int>? seasons;

  /// TV only: per-season episode list to restrict to. A season that appears
  /// here with fewer episodes than it has triggers the per-episode Sonarr
  /// path. Seasons not in the map (or with an empty list) are treated as
  /// "all episodes wanted" and go through the Seerr season-level request.
  final Map<int, List<int>>? episodes;

  /// Compact rendering for use on cards/tiles.
  final bool compact;
  final FocusNode? focusNode;
  final VoidCallback? onStarted;

  const DownloadNowButton({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.year,
    this.seasons,
    this.episodes,
    this.compact = false,
    this.focusNode,
    this.onStarted,
  });

  /// Runs the full flow without rendering a button — for callers that
  /// already have their own tile/row and just want the behavior.
  ///
  /// Flow: (TV with season info) pick seasons/episodes → ALWAYS pick the
  /// exact release from Prowlarr (resolution + size is the user's choice,
  /// never an automatic cascade) → grab via Radarr/Sonarr → track in Seerr.
  static Future<void> run(
    BuildContext context, {
    required int tmdbId,
    required String mediaType,
    required String title,
    int? year,
    List<int>? seasons,
    Map<int, List<int>>? episodes,
    List<SeerrSeason>? tvSeasons,
    int? numberOfSeasons,
    String? initialTier,
    int? tvdbId,
    String? seriesItemId,
  }) async {
    if (DownloadFeatures.viaPlugin && mediaType == 'tv') {
      return _runPluginTv(
        context,
        title: title,
        tvdbId: tvdbId,
        seriesItemId: seriesItemId,
        seasons: seasons,
        episodes: episodes,
        tvSeasons: tvSeasons,
        numberOfSeasons: numberOfSeasons,
        initialTier: initialTier,
      );
    }
    if (DownloadFeatures.viaPlugin && mediaType == 'movie') {
      // Public build: the server's Tortugarr plugin does the work.
      await runPluginDownload(
        context,
        title: title,
        search: {'type': 'movie', 'tmdbId': tmdbId},
        grabType: 'movie',
        tmdbId: tmdbId,
        initialTier: initialTier,
      );
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final service = GetIt.instance<DownloadNowService>();
    try {
      var resolvedTmdbId = tmdbId;
      if (resolvedTmdbId == 0 && mediaType == 'tv') {
        resolvedTmdbId = await service.resolveTvTmdbId(title) ?? 0;
      }
      if (resolvedTmdbId == 0) {
        messenger?.showSnackBar(SnackBar(
          content: Text('Could not find "$title" on the download service'),
        ));
        return;
      }

      // TV with season info: pick seasons (and episodes) first.
      var pickedSeasons = seasons;
      var pickedEpisodes = episodes;
      if (mediaType == 'tv' && seasons == null && tvSeasons != null) {
        if (!context.mounted) return;
        final choice = await showDownloadNowDialog(
          context,
          isTv: true,
          title: title,
          seasons: tvSeasons,
          numberOfSeasons: numberOfSeasons ?? 0,
        );
        if (choice == null) return;
        pickedSeasons = choice.seasons; // empty = all seasons
        pickedEpisodes = choice.episodes;
      }

      // A movie not yet out on digital/disc only exists as CAM copies or
      // same-named mockbusters (The Odyssey, 2026). Warn first, and hide
      // releases published before the home release.
      DateTime? notPublishedBefore;
      if (mediaType == 'movie') {
        final home = await service.movieHomeRelease(resolvedTmdbId);
        final today = DateTime.now();
        if (home.known && (home.home == null || home.home!.isAfter(today))) {
          if (!context.mounted) return;
          final showAnyway = await confirmNotReleasedYet(
            context,
            title: title,
            homeRelease: home.home,
          );
          if (!showAnyway) return;
        } else if (home.home != null) {
          notPublishedBefore = home.home;
        }
      }

      // Always let the user pick the exact file themselves.
      if (!context.mounted) return;
      messenger?.showSnackBar(const SnackBar(
        content: Text('Searching releases…'),
        duration: Duration(seconds: 2),
      ));
      var query = title;
      if (mediaType == 'tv' &&
          pickedSeasons != null &&
          pickedSeasons.length == 1) {
        final s = pickedSeasons.first;
        final eps = pickedEpisodes?[s] ?? const <int>[];
        if (eps.length == 1) {
          query =
              '$title S${s.toString().padLeft(2, '0')}E${eps.first.toString().padLeft(2, '0')}';
        } else {
          query = '$title S${s.toString().padLeft(2, '0')}';
        }
      }
      if (!context.mounted) return;
      final choice = await showReleasePickerDialog(
        context,
        title: title,
        mediaType: mediaType,
        query: query,
        year: year,
        initialTier: initialTier,
        notPublishedBefore: notPublishedBefore,
      );
      if (choice == null) return;
      final release = choice.release;
      // Make room first when the disk is too full for this release. A failed
      // check lets the download through, exactly as before.
      if (context.mounted &&
          !await ensureSpaceForDownload(
            context,
            releaseBytes: release.size,
            releaseTitle: release.title,
          )) {
        return;
      }
      // The grab can take a while (Radarr/Sonarr may need to add the title
      // first) — show persistent feedback so it never looks dead.
      messenger?.showSnackBar(SnackBar(
        content: Text('Sending "${release.title}" to the download client…'),
        duration: const Duration(minutes: 2),
      ));
      final tier = switch (release.tierLabel) {
        '2160p' => DownloadQualityTier.uhd2160,
        '720p' => DownloadQualityTier.sd720,
        _ => DownloadQualityTier.hd1080,
      };
      // Only whole-season selections become a Seerr tracking request — a
      // per-episode selection would make Seerr ask Sonarr for the whole
      // season on top of the release we just grabbed.
      final fullSeasons = <int>[
        for (final s in pickedSeasons ?? const <int>[])
          if ((pickedEpisodes?[s] ?? const <int>[]).isEmpty) s,
      ];
      await service.downloadPickedRelease(
        release,
        tier: tier,
        isMovie: mediaType == 'movie',
        tmdbId: resolvedTmdbId,
        seasons: mediaType == 'tv' ? fullSeasons : null,
      );
      messenger?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Sent "${release.title}" (${release.sizeLabel}) to qBittorrent',
          ),
        ));
      // Fake releases can look clean by title and carry only an .exe.
      unawaited(
        ReleaseVideoGuard()
            .watch(
          releaseTitle: release.title,
          guid: release.guid,
          magnetUrl: release.magnetUrl,
          isMovie: mediaType == 'movie',
        )
            .then((result) {
          final files = result.fileNames.take(3).join(', ');
          final text = switch (result.outcome) {
            VideoCheckOutcome.removed =>
              appL10n().tgNoVideoRemoved(title, files),
            VideoCheckOutcome.removeFailed =>
              appL10n().tgNoVideoNotRemoved(title, files),
            _ => null,
          };
          if (text != null) {
            messenger?.showSnackBar(SnackBar(
              content: Text(text),
              duration: const Duration(seconds: 12),
            ));
          }
        }),
      );
    } catch (e) {
      messenger?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  /// Public build, series: the user picks seasons/episodes, then one plugin
  /// search per whole season or per episode, each with its own file picker.
  static Future<void> _runPluginTv(
    BuildContext context, {
    required String title,
    int? tvdbId,
    String? seriesItemId,
    List<int>? seasons,
    Map<int, List<int>>? episodes,
    List<SeerrSeason>? tvSeasons,
    int? numberOfSeasons,
    String? initialTier,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // From a Jellyfin page (missing episode): the series' TVDB id is in
    // Jellyfin's provider ids.
    if ((tvdbId == null || tvdbId <= 0) && seriesItemId != null) {
      final ids = await TortugarrPluginClient().jellyfinProviderIds(seriesItemId);
      tvdbId = int.tryParse(ids['Tvdb'] ?? '');
      if (!context.mounted) return;
    }
    if (tvdbId == null || tvdbId <= 0) {
      messenger?.showSnackBar(SnackBar(
        content: Text('"$title" has no TVDB id, so it cannot be downloaded here'),
      ));
      return;
    }
    // Seasons already chosen by the caller skip the picker.
    final choice = seasons != null
        ? DownloadNowChoice(seasons: seasons, episodes: episodes ?? const {})
        : await showDownloadNowDialog(
            context,
            isTv: true,
            title: title,
            seasons: tvSeasons ?? const [],
            numberOfSeasons: numberOfSeasons ?? 0,
          );
    if (choice == null || !context.mounted) return;
    final jobs = pluginTvJobs(
      choice,
      allSeasons: [
        for (final s in tvSeasons ?? const <SeerrSeason>[])
          if (s.seasonNumber > 0) s.seasonNumber,
      ],
      episodeCounts: {
        for (final s in tvSeasons ?? const <SeerrSeason>[])
          if (s.episodeCount != null) s.seasonNumber: s.episodeCount!,
      },
    );
    for (final job in jobs) {
      if (!context.mounted) return;
      final done = await runPluginDownload(
        context,
        title: '$title ${job.label}',
        search: {'tvdbId': tvdbId, ...job.search},
        grabType: job.search['type'] as String,
        initialTier: initialTier,
      );
      // Cancelled, nothing picked or failed: do not go on with the rest.
      if (!done) return;
    }
  }

  @override
  State<DownloadNowButton> createState() => _DownloadNowButtonState();
}

class _DownloadNowButtonState extends State<DownloadNowButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DownloadNowButton.run(
        context,
        tmdbId: widget.tmdbId,
        mediaType: widget.mediaType,
        title: widget.title,
        year: widget.year,
        seasons: widget.seasons,
        episodes: widget.episodes,
      );
      widget.onStarted?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        focusNode: widget.focusNode,
        tooltip: 'Download Now',
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download_for_offline_outlined),
      );
    }
    return FilledButton.icon(
      focusNode: widget.focusNode,
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download_for_offline_outlined),
      label: Text(_busy ? 'Working…' : 'Download Now'),
    );
  }
}

/// One plugin search for a series: a whole season or a single episode.
class PluginTvJob {
  final Map<String, dynamic> search;
  final String label;
  const PluginTvJob(this.search, this.label);
}

/// Turns the season/episode picker's [choice] into plugin searches: a season
/// without picked episodes, or with all of them picked ([episodeCounts]), is
/// searched as a whole season; picked episodes one by one. No seasons picked
/// means every season in [allSeasons].
@visibleForTesting
List<PluginTvJob> pluginTvJobs(
  DownloadNowChoice choice, {
  required List<int> allSeasons,
  Map<int, int> episodeCounts = const {},
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final seasons = choice.seasons.isEmpty ? allSeasons : choice.seasons;
  bool whole(int s) {
    final picked = choice.episodes[s] ?? const <int>[];
    final count = episodeCounts[s];
    return picked.isEmpty || (count != null && picked.toSet().length >= count);
  }
  return [
    for (final s in seasons)
      if (whole(s))
        PluginTvJob({'type': 'season', 'season': s}, 'S${two(s)}')
      else
        for (final e in choice.episodes[s]!)
          PluginTvJob({'type': 'episode', 'season': s, 'episode': e}, 'S${two(s)}E${two(e)}'),
  ];
}
