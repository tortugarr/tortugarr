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
      note: unavailableNote(result.unavailableIndexers),
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
      content: Text('Sending "${picked.title}" to the download client…'),
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
        content: Text('Downloading "${picked.title}" (${asPickerRelease(picked).sizeLabel})'),
      ));

    final downloadId = grab.downloadId;
    if (downloadId != null && DownloadFeatures.capabilities.value.videoCheck) {
      unawaited(_watchVideo(plugin, downloadId, title, messenger));
    }
    return true;
  } on TortugarrPluginException catch (e) {
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(explainPluginError(e))));
    return false;
  } catch (e) {
    messenger?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
      if (result.droppedEarly > 0) '${result.droppedEarly} too early',
      for (final e in result.dropped.entries) '${e.value} ${e.key}',
    ].join(', ');
    return appL10n().tgNothingKeptReasons(result.found, reasons);
  }
  return 'No releases found';
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
    );

DownloadQualityTier _tierOf(ProwlarrRelease r) => switch (r.tierLabel) {
      '2160p' => DownloadQualityTier.uhd2160,
      '720p' => DownloadQualityTier.sd720,
      _ => DownloadQualityTier.hd1080,
    };

/// The user-facing text for a plugin error code.
String explainPluginError(TortugarrPluginException e) => switch (e.code) {
      'not_admin' => 'Only administrators can download on this server',
      'feature_off' => 'Downloads are switched off on this server',
      'not_configured' => 'The server is not set up for downloads yet',
      'search_expired' => 'The search is too old, search again',
      'timeout' => 'The search took too long, try again',
      'no_indexers' => 'No search sources are active on the server'
          '${e.message.isEmpty ? '' : ' (${e.message})'}. Check your indexers in Prowlarr. '
          'Does an indexer\'s test fail with a Cloudflare error (1337x and others)? '
          'Type flaresolverr under Tags at the bottom of its settings and test again.',
      'already_in_client' => (e.progress ?? 0) >= 1
          ? 'Already downloaded: the download client has this file already'
          : 'Already downloading (${((e.progress ?? 0) * 100).round()} %)',
      _ => 'Download failed: $e',
    };

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
  final reasons = r.rejections.isEmpty ? 'No reason given' : r.rejections.join('\n');
  final result = await showStyledPlayerDialog<bool>(
    context,
    title: 'Download anyway?',
    subtitle: r.title,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The server would not pick this file by itself:\n$reasons',
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
                  label: 'Download anyway',
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
