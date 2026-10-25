import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/download/download_now_service.dart';
import '../../../data/services/download/prowlarr_search_client.dart';
import '../../../data/services/tortugarr/download_features.dart';
import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'free_space_dialog.dart';
import 'plugin_search_progress.dart';
import 'release_picker_dialog.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Download Now in the public build: the server's Tortugarr plugin searches
/// Radarr/Sonarr, the user picks the file, the plugin grabs it. The app
/// never talks to the *arr stack itself.
///
/// [search] is the plugin search body (spec 3.2), [grabType] its grab type
/// (`movie`, `episode` or `season`). For a movie, [tmdbId] also gets the
/// Seerr request once the movie is in Radarr's queue (spec 3.3).
///
/// Returns true when a release was sent to the download client, false when
/// the user cancelled, nothing was found or it failed.
Future<bool> runPluginDownload(
  BuildContext context, {
  required String title,
  required Map<String, dynamic> search,
  required String grabType,
  int? tmdbId,
  String? initialTier,
  TortugarrPluginClient? client,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final plugin = client ?? TortugarrPluginClient();
  try {
    final outcome = await showPluginSearchProgress<TortugarrSearchResult>(
      context,
      title: title,
      start: (isCancelled) => plugin.search(search, isCancelled: isCancelled),
    );
    if (outcome.cancelled) return false;
    if (outcome.error != null) throw outcome.error!;
    final result = outcome.value!;
    if (result.releases.isEmpty) {
      messenger?.showSnackBar(SnackBar(
        content: Text(nothingFoundMessage(result)),
        duration: const Duration(seconds: 8),
      ));
      return false;
    }

    final byGuid = {for (final r in result.releases) r.guid: r};
    if (!context.mounted) return false;
    final choice = await showReleaseListDialog(
      context,
      title: title,
      releases: [for (final r in result.releases) asPickerRelease(r)],
      initialTier: initialTier,
      note: [
        DownloadFeatures.capabilities.value.limits?.describe(),
        unavailableNote(result.unavailableIndexers),
      ].nonNulls.where((n) => n.isNotEmpty).join('\n').ifEmptyNull,
    );
    final picked = choice == null ? null : byGuid[choice.release.guid];
    if (picked == null) return false;

    // Radarr/Sonarr would not pick this file themselves: say why and ask.
    var force = false;
    if (!picked.approved) {
      if (!context.mounted) return false;
      force = await _confirmSoftRejected(context, picked);
      if (!force) return false;
    }

    // Make room first when the disk is too full; a failed check lets the
    // download through, as in the private build.
    if (DownloadFeatures.freeSpace &&
        context.mounted &&
        !await ensureSpaceForDownload(context, releaseBytes: picked.size, releaseTitle: picked.title)) {
      return false;
    }

    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgSendingToDownloadClient(picked.title)),
      duration: const Duration(minutes: 2),
    ));
    final grab = await plugin.grab(
      type: grabType,
      arrId: result.arrId,
      release: picked,
      force: force,
    );
    // The Seerr request makes Radarr search; only safe once the grabbed
    // release is in its queue, or Radarr takes a second copy.
    if (grabType == 'movie' && tmdbId != null && grab.queued) {
      try {
        await GetIt.instance<DownloadNowService>()
            .trackMovieInSeerr(tmdbId, _tierOf(asPickerRelease(picked)));
      } catch (e) {
        debugPrint('[DownloadNow] Seerr tracking failed (grab succeeded): $e');
      }
    }
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(appL10n().tgDownloadingTitle(picked.title, asPickerRelease(picked).sizeLabel)),
      ));

    final downloadId = grab.downloadId;
    if (downloadId != null && DownloadFeatures.capabilities.value.videoCheck) {
      unawaited(_watchVideo(plugin, downloadId, title, messenger));
    }
    unawaited(_refreshLimits(plugin));
    return true;
  } on TortugarrPluginException catch (e) {
    if (e.code == 'quota_exceeded' || e.code == 'limit_exceeded') unawaited(_refreshLimits(plugin));
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(explainPluginError(e))));
    return false;
  } catch (e) {
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(appL10n().tgDownloadFailed('$e'))));
    return false;
  }
}

/// "Internet Archive unavailable right now ..." or null when all are up.
String? unavailableNote(List<String> names) =>
    names.isEmpty ? null : appL10n().tgIndexersUnavailable(names.join(', '));

/// Why a search shows no files: early releases, only SD (with the setting
/// that brings them back), or what the filters left out; plus which
/// indexers were switched off.
String nothingFoundMessage(TortugarrSearchResult result) {
  final why = _nothingFoundReason(result);
  final note = unavailableNote(result.unavailableIndexers);
  if (note == null) return why;
  return why.endsWith('.') ? '$why $note' : '$why. $note';
}

String _nothingFoundReason(TortugarrSearchResult result) {
  if (result.droppedEarly > 0 && result.dropped.isEmpty) {
    return appL10n().tgOnlyEarlyFiles(result.droppedEarly);
  }
  if (result.onlySdDropped) return appL10n().tgOnlySdFound(result.found);
  if (result.found > 0) {
    final reasons = [
      if (result.droppedEarly > 0) appL10n().tgCountTooEarly(result.droppedEarly),
      for (final e in result.dropped.entries) '${e.value} ${e.key}',
    ].join(', ');
    return appL10n().tgNothingKeptReasons(result.found, reasons);
  }
  return appL10n().tgNoReleasesFound;
}

/// The picker shows [ProwlarrRelease]s; the plugin's fields map one to one.
ProwlarrRelease asPickerRelease(TortugarrRelease r) => ProwlarrRelease(
      guid: r.guid,
      title: r.title,
      size: r.size,
      indexerId: r.indexerId,
      indexer: r.indexer,
      seeders: r.seeders,
      leechers: r.leechers,
      protocol: r.protocol,
      publishDate: r.publishDate,
      lowQuality: r.sd,
      blockedReason: r.overLimit
          ? (r.rejections.map(overLimitLabel).nonNulls.firstOrNull ?? appL10n().tgOverSizeLimitUnknown)
          : null,
    );

DownloadQualityTier _tierOf(ProwlarrRelease r) => switch (r.tierLabel) {
      '2160p' => DownloadQualityTier.uhd2160,
      '720p' => DownloadQualityTier.sd720,
      _ => DownloadQualityTier.hd1080,
    };

/// The user-facing text for a plugin error code.
String explainPluginError(TortugarrPluginException e) => switch (e.code) {
      'not_admin' => appL10n().tgPluginNotAdmin,
      'feature_off' => appL10n().tgPluginFeatureOff,
      'not_configured' => appL10n().tgPluginNotConfigured,
      'search_expired' => appL10n().tgPluginSearchExpired,
      'timeout' => appL10n().tgPluginTimeout,
      'no_indexers' => appL10n().tgPluginNoIndexers(
          e.message.isEmpty ? '' : ' (${e.message})',
        ),
      'forbidden' || 'limit_exceeded' || 'quota_exceeded' => limitErrorText(e)!,
      'already_in_client' => (e.progress ?? 0) >= 1
          ? appL10n().tgAlreadyDownloaded
          : appL10n().tgAlreadyDownloadingPercent(((e.progress ?? 0) * 100).round()),
      _ => appL10n().tgDownloadFailed('$e'),
    };

/// A limited downloader's counts this week changed: ask the plugin again.
Future<void> _refreshLimits(TortugarrPluginClient plugin) async {
  if (DownloadFeatures.capabilities.value.limits == null) return;
  final fresh = await plugin.capabilities();
  if (fresh.downloadNow) DownloadFeatures.capabilities.value = fresh;
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

Future<void> _watchVideo(
  TortugarrPluginClient plugin,
  String downloadId,
  String title,
  ScaffoldMessengerState? messenger,
) async {
  try {
    final check = await plugin.watchVideo(downloadId);
    if (check.action == TortugarrVideoAction.removed) {
      messenger?.showSnackBar(SnackBar(
        content: Text(appL10n().tgNoVideoRemoved(title, check.fileNames.take(3).join(', '))),
        duration: const Duration(seconds: 12),
      ));
    }
  } catch (e) {
    debugPrint('[DownloadNow] video check failed: $e');
  }
}

Future<bool> _confirmSoftRejected(BuildContext context, TortugarrRelease r) async {
  final reasons = r.rejections.isEmpty ? appL10n().tgNoReasonGiven : r.rejections.join('\n');
  final result = await showStyledPlayerDialog<bool>(
    context,
    title: appL10n().tgDownloadAnywayQuestion,
    subtitle: r.title,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appL10n().tgServerWouldNotPick(reasons),
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgCancel,
                  primary: true,
                  primaryColor: AppColorScheme.accent,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgDownloadAnyway,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
