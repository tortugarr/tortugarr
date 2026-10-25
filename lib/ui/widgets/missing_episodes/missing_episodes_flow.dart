import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/download/missing_episodes.dart';
import '../../../data/services/download/release_video_guard.dart';
import '../../../data/services/download/sonarr_client.dart';
import '../../../data/services/tortugarr/download_features.dart';
import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../../../data/viewmodels/item_detail_view_model.dart';
import '../download_now/free_space_dialog.dart';
import '../focus/focusable_wrapper.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'missing_episode_card.dart';
import 'package:moonfin/util/app_l10n.dart';

/// A missing episode was picked: search Sonarr for exactly that episode and
/// let the user choose a file. Episodes that cannot be downloaded (not aired,
/// already downloading) just say why.
Future<void> openMissingEpisode(
  BuildContext context, {
  required ItemDetailViewModel vm,
  required String seriesTitle,
  required MissingEpisode missing,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final why = switch (missing.state) {
    MissingEpisodeState.unaired => missing.airDate == null
        ? appL10n().tgNotAiredYet(missing.code)
        : appL10n().tgNotAiredYetComing(
            missing.code, norwegianShortDate(missing.airDate!)),
    MissingEpisodeState.downloading => appL10n().tgAlreadyDownloading(missing.code),
    MissingEpisodeState.importing => appL10n().tgDownloadedAppearsSoon(missing.code),
    MissingEpisodeState.missing => null,
  };
  if (why != null) {
    messenger?.showSnackBar(SnackBar(content: Text(why)));
    return;
  }
  final title = (missing.title ?? '').trim();
  final choice = await _pickRelease(
    context,
    title: seriesTitle,
    subtitle: title.isEmpty ? missing.code : '${missing.code} · $title',
    searchingLabel: appL10n().tgSearchingFor(missing.code),
    search: () => MissingEpisodesService().searchEpisode(missing.episode.id),
  );
  if (choice == null || !context.mounted) return;
  await _grab(context, vm, choice, '$seriesTitle ${missing.code}');
}

/// "Hele sesongen": search Sonarr for [season] and show packs first.
Future<void> openSeasonPack(
  BuildContext context, {
  required ItemDetailViewModel vm,
  required String seriesTitle,
  required int season,
}) async {
  final status = vm.arrStatus;
  if (status == null) return;
  final label = appL10n().tgSeasonLower(season);
  final choice = await _pickRelease(
    context,
    title: seriesTitle,
    subtitle: appL10n().tgWholeLabel(label),
    searchingLabel: appL10n().tgSearchingFor(label),
    search: () =>
        MissingEpisodesService().searchSeason(status.sonarrSeriesId, season),
    seasonPack: true,
  );
  if (choice == null || !context.mounted) return;
  await _grab(context, vm, choice, '$seriesTitle $label');
}

/// A season the library has no episodes of: list Sonarr's episodes for it.
Future<void> showMissingSeasonDialog(
  BuildContext context, {
  required ItemDetailViewModel vm,
  required String seriesTitle,
  required int season,
  required List<SeasonEntry> entries,
}) async {
  // The dialog closes with what was picked, so the search dialog does not
  // open on top of it.
  final picked = await showStyledPlayerDialog<Object>(
    context,
    title: seriesTitle,
    subtitle: appL10n().tgSeasonNoEpisodes(season),
    maxWidth: 720,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MissingEpisodes.offerSeasonPack(entries))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SeasonPackButton(
                missingCount: MissingEpisodes.downloadableCount(entries),
                autofocus: true,
                onSelect: () => Navigator.of(ctx).pop(season),
              ),
            ),
          for (var i = 0; i < entries.length; i++)
            if (entries[i].missing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MissingEpisodeCard(
                  missing: entries[i].missing!,
                  autofocus: i == 0 && !MissingEpisodes.offerSeasonPack(entries),
                  onSelect: () => Navigator.of(ctx).pop(entries[i].missing),
                ),
              ),
          const SizedBox(height: 12),
          SeerrDialogButton(
            label: appL10n().tgClose,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (picked is MissingEpisode) {
    await openMissingEpisode(
      context,
      vm: vm,
      seriesTitle: seriesTitle,
      missing: picked,
    );
  } else if (picked is int) {
    await openSeasonPack(context, vm: vm, seriesTitle: seriesTitle, season: picked);
  }
}

/// Adds the series to Sonarr unmonitored, then reloads the episode lists.
Future<void> addSeriesToSonarr(
  BuildContext context,
  ItemDetailViewModel vm,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final tvdb = vm.seriesTvdbId;
  if (tvdb == null) {
    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgNoTvdbId),
    ));
    return;
  }
  messenger?.showSnackBar(SnackBar(content: Text(appL10n().tgAddingToSonarr)));
  var ok = false;
  try {
    ok = await MissingEpisodesService().addSeries(tvdb);
  } catch (_) {}
  messenger?.hideCurrentSnackBar();
  if (!ok) {
    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgAddToSonarrFailed),
    ));
    return;
  }
  await vm.loadMissingEpisodes();
}

Future<EpisodeReleaseOption?> _pickRelease(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String searchingLabel,
  required Future<List<EpisodeReleaseOption>> Function() search,
  bool seasonPack = false,
}) {
  return showStyledPlayerDialog<EpisodeReleaseOption>(
    context,
    title: title,
    subtitle: subtitle,
    maxWidth: 720,
    builder: (_) => _ReleaseSearchBody(
      search: search,
      searchingLabel: searchingLabel,
      seasonPack: seasonPack,
    ),
  );
}

Future<void> _grab(
  BuildContext context,
  ItemDetailViewModel vm,
  EpisodeReleaseOption choice,
  String label,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final release = choice.release;
  // Make room first when the disk is too full. A failed check lets the
  // download through, as Download Now does.
  if (!await ensureSpaceForDownload(
    context,
    releaseBytes: release.size,
    releaseTitle: release.title,
  )) {
    return;
  }
  messenger?.showSnackBar(SnackBar(
    content: Text(appL10n().tgSendingToDownload(label)),
    duration: const Duration(minutes: 1),
  ));
  String? downloadId;
  try {
    downloadId = await MissingEpisodesService().grab(release);
  } catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(appL10n().tgDownloadDidNotStart('$e'))));
    return;
  }
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(appL10n().tgDownloadingAppearsWhenDone(label, _size(release.size))),
      duration: const Duration(seconds: 6),
    ));

  if (DownloadFeatures.viaPlugin) {
    // The plugin's grab returns once Sonarr has it; reload to show it as
    // downloading, and let the plugin check the files.
    unawaited(vm.loadMissingEpisodes());
    if (downloadId != null && DownloadFeatures.capabilities.value.videoCheck) {
      unawaited(TortugarrPluginClient().watchVideo(downloadId).then((check) {
        if (check.action == TortugarrVideoAction.removed) {
          messenger?.showSnackBar(SnackBar(
            content: Text(appL10n().tgNoVideoRemoved(label, check.fileNames.take(3).join(', '))),
            duration: const Duration(seconds: 12),
          ));
          unawaited(vm.loadMissingEpisodes());
        }
      }).catchError((Object _) {}));
    }
    return;
  }

  // Show "Lastes ned" once Sonarr has the download in its queue.
  final seriesId = vm.arrStatus?.sonarrSeriesId;
  unawaited(() async {
    if (seriesId != null) await SonarrClient().waitUntilQueued(seriesId);
    await vm.loadMissingEpisodes();
  }());

  // Fake releases can look clean by title and carry only an .exe.
  unawaited(
    ReleaseVideoGuard()
        .watch(
      releaseTitle: release.title,
      guid: release.guid,
      magnetUrl: release.magnetUrl,
      isMovie: false,
    )
        .then((result) {
      final files = result.fileNames.take(3).join(', ');
      final text = switch (result.outcome) {
        VideoCheckOutcome.removed =>
          appL10n().tgNoVideoRemoved(label, files),
        VideoCheckOutcome.removeFailed =>
          appL10n().tgNoVideoNotRemoved(label, files),
        _ => null,
      };
      if (text != null) {
        messenger?.showSnackBar(SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 12),
        ));
        unawaited(vm.loadMissingEpisodes());
      }
    }),
  );
}

String _size(int bytes) {
  if (bytes <= 0) return '?';
  const gb = 1024 * 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

String _age(DateTime published) {
  final days = DateTime.now().toUtc().difference(published.toUtc()).inDays;
  if (days <= 0) return appL10n().tgToday;
  if (days == 1) return appL10n().tgYesterday;
  if (days < 60) return appL10n().tgDaysAgo(days);
  final months = (days / 30.4).round();
  if (months < 24) return appL10n().tgMonthsAgo(months);
  return appL10n().tgYearsAgo(months ~/ 12);
}

class _ReleaseSearchBody extends StatefulWidget {
  final Future<List<EpisodeReleaseOption>> Function() search;
  final String searchingLabel;
  final bool seasonPack;

  const _ReleaseSearchBody({
    required this.search,
    required this.searchingLabel,
    required this.seasonPack,
  });

  @override
  State<_ReleaseSearchBody> createState() => _ReleaseSearchBodyState();
}

class _ReleaseSearchBodyState extends State<_ReleaseSearchBody> {
  static const _tiers = ['2160p', '1080p', '720p', 'other'];

  List<EpisodeReleaseOption>? _options;
  String? _error;

  /// The quality shown, as in the movie picker: the best one with files, or
  /// "all".
  String _tier = 'all';

  // "Avbryt" holds focus while searching; the first result takes it over.
  final _firstRow = FocusNode(debugLabel: 'firstRelease');

  // A search through every indexer can take minutes; show how long.
  final _watch = Stopwatch()..start();
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _firstRow.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _options == null && _error == null) setState(() {});
    });
    _run();
  }

  Future<void> _run() async {
    try {
      final found = await widget.search();
      if (!mounted) return;
      setState(() {
        _options = found;
        _tier = _tiers.firstWhere(
          (t) => found.any((o) => MissingEpisodes.tierOf(o.release) == t),
          orElse: () => 'all',
        );
      });
      if (found.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _firstRow.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is MissingEpisodesException
            ? e.message
            : appL10n().tgSonarrUnreachableRetry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final children = <Widget>[const Divider(color: Colors.white12)];
    if (_error != null) {
      children.add(_text(_error!));
    } else if (options == null) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                  '${widget.searchingLabel} '
                  '${_watch.elapsed.inSeconds ~/ 60}:${(_watch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(appL10n().tgCanTakeAMinute,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ));
    } else if (options.isEmpty) {
      children.add(_text(appL10n().tgNoUsableFiles));
    } else {
      final recommended = options.where((o) => o.recommended).length;
      children.add(_text(recommended == options.length
          ? appL10n().tgFilesCount(options.length)
          : appL10n().tgFilesRecommended(options.length, recommended)));
      children.add(const SizedBox(height: 8));
      int count(String t) => t == 'all'
          ? options.length
          : options.where((o) => MissingEpisodes.tierOf(o.release) == t).length;
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in [..._tiers, 'all'])
            if (t == 'all' || count(t) > 0)
              SeerrChoiceChip(
                label: '$t · ${count(t)}',
                selected: t == _tier,
                onSelected: (_) => setState(() => _tier = t),
              ),
        ],
      ));
      children.add(const SizedBox(height: 4));
      // pickable() already put them best first; a tier keeps that order.
      final visible = _tier == 'all'
          ? options
          : options.where((o) => MissingEpisodes.tierOf(o.release) == _tier).toList();
      for (var i = 0; i < visible.length; i++) {
        children.add(_ReleaseRow(
          option: visible[i],
          focusNode: i == 0 ? _firstRow : null,
          showPackBadge: widget.seasonPack,
        ));
      }
    }
    children.addAll([
      const SizedBox(height: 20),
      SeerrDialogButton(
        label: options == null && _error == null ? appL10n().tgCancel : appL10n().tgClose,
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ]);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _text(String s) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(s,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
      );
}

class _ReleaseRow extends StatelessWidget {
  final EpisodeReleaseOption option;
  final FocusNode? focusNode;
  final bool showPackBadge;

  const _ReleaseRow({
    required this.option,
    required this.showPackBadge,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final r = option.release;
    final meta = [
      if (r.quality.isNotEmpty) r.quality,
      r.indexer.replaceAll(' (Prowlarr)', ''),
      '${r.seeders} seeders',
      if (r.publishDate != null) _age(r.publishDate!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FocusableWrapper(
        // A file over the user's size limit stays focusable but is never taken.
        onSelect: option.blocked ? () {} : () => Navigator.of(context).pop(option),
        focusNode: focusNode,
        autoScroll: true,
        borderRadius: 10,
        disableScale: true,
        child: Opacity(
          opacity: option.blocked ? 0.4 : (option.recommended ? 1 : 0.6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: AppRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      if (option.softReason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.softReason!,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (showPackBadge && r.fullSeason) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: AppRadius.circular(8),
                    ),
                    child: Text(
                      appL10n().tgSeasonPackBadge,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColorScheme.accent.withValues(alpha: 0.85),
                    borderRadius: AppRadius.circular(8),
                  ),
                  child: Text(
                    _size(r.size),
                    style: TextStyle(
                      color: AppColorScheme.onAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
