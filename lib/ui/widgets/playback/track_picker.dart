import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:playback_core/playback_core.dart';
import 'package:server_core/server_core.dart';

import '../../../auth/repositories/user_repository.dart';
import '../../../data/models/aggregated_item.dart';
import '../../../data/services/log_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../playback/delay_limits.dart';
import '../../../playback/media3_player_backend.dart';
import '../../../playback/subtitle_style.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/remote_subtitle_labels.dart';
import '../../../util/subtitle_appearance_schedule.dart';
import '../overlay_sheet.dart';
import '../progress_snack_bar.dart';
import '../track_selector_dialog.dart';
import 'delay_footer.dart';
import 'subtitle_appearance_footer.dart';
import 'track_choices.dart';

/// Runs a change to the player, returning false when it was refused.
typedef PlayerMutation = Future<bool> Function(
  String label,
  FutureOr<void> Function() action,
);

/// The audio and subtitle pickers: the track list, a row that opens the delay
/// in its own bar, and downloading subtitles from the server's providers. The
/// full player and the mini player both open it, so both offer the same thing.
abstract final class TrackPicker {
  /// The delays applied to this playback. Held here rather than by a screen,
  /// so the full player and the mini player show the same values while the
  /// video moves between them.
  static double audioDelay = 0;
  static double subtitleDelay = 0;

  static void resetDelays() {
    audioDelay = 0;
    subtitleDelay = 0;
  }

  static bool canDownloadRemoteSubtitles(AggregatedItem item) {
    final user = GetIt.instance<UserRepository>().currentUser;
    final mediaType = item.rawData['MediaType'] as String?;
    final isAudio =
        item.type == 'Audio' ||
        item.type == 'MusicAlbum' ||
        item.type == 'AudioBook' ||
        mediaType == 'Audio';

    return (user?.canManageSubtitles ?? false) &&
        item.mediaSources.isNotEmpty &&
        item.type != 'Photo' &&
        item.type != 'Book' &&
        !isAudio;
  }

  /// [runMutation] wraps each track change (the full player uses it to keep
  /// one change in flight and hold back navigation meanwhile), and
  /// [onSubtitlesChanged] runs after a subtitle change lands.
  /// [onDialogOpenChanged] reports each dialog opening and closing, for an
  /// opener outside the navigator that the dialog's barrier doesn't cover.
  static Future<void> show(
    BuildContext context, {
    required PlaybackManager manager,
    required bool audio,
    required MediaServerClient Function(AggregatedItem item) clientFor,
    bool useRootNavigator = true,
    PlayerMutation? runMutation,
    VoidCallback? onSubtitlesChanged,
    ValueChanged<bool>? onDialogOpenChanged,
  }) async {
    final l10n = AppLocalizations.of(context);
    final prefs = GetIt.instance<UserPreferences>();
    final item = manager.queueService.currentItem;
    final canDownloadRemote =
        !audio &&
        item is AggregatedItem &&
        canDownloadRemoteSubtitles(item);
    final mutate = runMutation ?? _runDirectly;

    final choices = await TrackChoices.load(
      manager,
      l10n,
      audio: audio,
    );
    final streams = choices.streams;
    final options = <TrackOption>[
      ...choices.options,
      if (canDownloadRemote)
        TrackOption(
          label: l10n.downloadSubtitlesLabel,
          subtitle: l10n.searchOpenSubtitlesPlugin,
        ),
    ];
    if (!context.mounted) return;

    final backend = manager.backend;
    final delayLimits = delayLimitsFor(backend, audio: audio);
    final delay = audio
        ? audioDelay
        : backend is Media3PlayerBackend
        ? backend.subtitleDelaySeconds
        : subtitleDelay;
    final delayLabel = audio ? l10n.audioDelay : l10n.subtitleDelay;
    String formatDelay(double seconds) => seconds == 0
        ? l10n.none
        : '${seconds >= 0 ? '+' : ''}${(seconds * 1000).round()} ms';
    if (delayLimits != null) {
      options.add(
        TrackOption(
          label: delayLabel,
          subtitle: formatDelay(delay),
          icon: Icons.av_timer,
        ),
      );
    }
    final footer = audio ? null : _appearanceFooter(manager, prefs);
    final result = await _whileOpen(
      onDialogOpenChanged,
      () => TrackSelectorDialog.show(
        context,
        title: audio ? l10n.audioTrack : l10n.subtitleTrack,
        options: options,
        selectedIndex: choices.selectedIndex,
        useRootNavigator: useRootNavigator,
        footer: footer,
      ),
    );
    if (result == null || !context.mounted) return;
    if (delayLimits != null && result == options.length - 1) {
      await _whileOpen(
        onDialogOpenChanged,
        () => _showDelayBar(
          context,
          useRootNavigator: useRootNavigator,
          bar: DelayFooter(
            initialDelay: delay,
            label: delayLabel,
            minDelay: delayLimits.$1,
            maxDelay: delayLimits.$2,
            onDelayChanged: (d) =>
                _applyDelay(manager, audio: audio, delay: d),
            formatDelay: formatDelay,
          ),
        ),
      );
      return;
    }
    final streamIndex = choices.streamIndexFor(result);
    if (!audio) {
      if (streamIndex == -1) {
        await mutate('subtitles_off', manager.disableSubtitles);
        onSubtitlesChanged?.call();
        return;
      }
      if (canDownloadRemote && result - 1 == streams.length) {
        await _downloadRemoteSubtitles(
          context,
          manager: manager,
          item: item,
          client: clientFor(item),
          subtitleStreams: streams,
          audioStreams: choices.allStreams
              .where((s) => s['Type'] == 'Audio')
              .toList(),
          mutate: mutate,
          onSubtitlesChanged: onSubtitlesChanged,
          onDialogOpenChanged: onDialogOpenChanged,
        );
        return;
      }
      if (streamIndex != null) {
        await mutate(
          'subtitle_$streamIndex',
          () => manager.changeSubtitleTrack(streamIndex),
        );
        onSubtitlesChanged?.call();
      }
    } else if (streamIndex != null) {
      await mutate(
        'audio_$streamIndex',
        () => manager.changeAudioTrack(streamIndex),
      );
    }
  }

  /// Size, height and colour of the subtitles. They are written to the same
  /// preferences as the subtitle settings (the HDR ones while HDR plays and
  /// those are kept apart), and the player restyles on every write.
  static Widget _appearanceFooter(
    PlaybackManager manager,
    UserPreferences prefs,
  ) {
    final resolution = manager.currentResolution;
    final hdr =
        prefs.get(UserPreferences.subtitlesHdrSeparate) &&
        isHdrSubtitleOutput(
          videoRangeType: resolution?.videoRangeType,
          isTranscoding: resolution?.playMethod == StreamPlayMethod.transcode,
        );
    final size = hdr
        ? UserPreferences.subtitlesHdrTextSize
        : UserPreferences.subtitlesTextSize;
    final offset = hdr
        ? UserPreferences.subtitlesHdrOffsetPosition
        : UserPreferences.subtitlesOffsetPosition;
    final color = hdr
        ? UserPreferences.subtitlesHdrTextColor
        : UserPreferences.subtitlesTextColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        SubtitleAppearanceFooter(
          initialFontSize: prefs.get(size),
          initialOffset: prefs.get(offset),
          initialTextColor: prefs.get(color),
          defaultTextColor: color.defaultValue,
          onChanged: (fontSize, verticalOffset, textColor) {
            unawaited(prefs.set(size, fontSize));
            unawaited(prefs.set(offset, verticalOffset));
            unawaited(prefs.set(color, textColor ?? color.defaultValue));
          },
        ),
      ],
    );
  }

  static Future<bool> _runDirectly(
    String label,
    FutureOr<void> Function() action,
  ) async {
    await action();
    return true;
  }

  static Future<T?> _whileOpen<T>(
    ValueChanged<bool>? onOpenChanged,
    Future<T?> Function() open,
  ) async {
    onOpenChanged?.call(true);
    try {
      return await open();
    } finally {
      onOpenChanged?.call(false);
    }
  }

  /// The delay on its own, in a slim bar at the bottom with nothing dimming
  /// the picture, so the effect of each step can be seen while it's made.
  static Future<void> _showDelayBar(
    BuildContext context, {
    required Widget bar,
    required bool useRootNavigator,
  }) => showFocusRestoringDialog<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: Colors.transparent,
    builder: (_) => Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      backgroundColor: Colors.transparent,
      child: playerDialogPanel(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: bar,
      ),
    ),
  );

  static void _applyDelay(
    PlaybackManager manager, {
    required bool audio,
    required double delay,
  }) {
    if (audio) {
      audioDelay = delay;
      manager.backend?.setAudioDelay(delay);
    } else {
      subtitleDelay = delay;
      manager.backend?.setSubtitleDelay(delay);
    }
  }

  static Future<void> _downloadRemoteSubtitles(
    BuildContext context, {
    required PlaybackManager manager,
    required AggregatedItem item,
    required MediaServerClient client,
    required List<Map<String, dynamic>> subtitleStreams,
    required List<Map<String, dynamic>> audioStreams,
    required PlayerMutation mutate,
    VoidCallback? onSubtitlesChanged,
    ValueChanged<bool>? onDialogOpenChanged,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final languages = remoteSubtitleLanguages(subtitleStreams, audioStreams);

    List<Map<String, dynamic>> results;
    try {
      results = await withProgressSnackBar(
        messenger,
        l10n.searchingSubtitles,
        () => searchRemoteSubtitlesIn(client.itemsApi, item.id, languages),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            remoteSubtitleErrorMessage(error, l10n, action: l10n.search),
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    if (results.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.noRemoteSubtitlesFound(languages.join(', '))),
        ),
      );
      return;
    }

    final result = await _whileOpen(
      onDialogOpenChanged,
      () => TrackSelectorDialog.show(
        context,
        title: l10n.downloadSubtitles,
        options: results.map((subtitle) {
          final label =
              subtitle['Name'] as String? ??
              subtitle['Author'] as String? ??
              l10n.subtitles;
          final subtitleText = remoteSubtitleDetails(subtitle, l10n);
          return TrackOption(
            label: label,
            subtitle: subtitleText.isNotEmpty ? subtitleText : null,
            subtitleMaxLines: 2,
            badges: remoteSubtitleFlags(subtitle, l10n),
          );
        }).toList(),
      ),
    );

    if (!context.mounted || result == null || result >= results.length) {
      return;
    }

    final subtitleId = results[result]['Id']?.toString();
    if (subtitleId == null || subtitleId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.selectedSubtitleInvalid)),
      );
      return;
    }

    final existingIndexes = subtitleStreams
        .map((stream) => stream['Index'] as int?)
        .whereType<int>()
        .toSet();

    try {
      final newStream = await withProgressSnackBar(
        messenger,
        l10n.downloadingSubtitle,
        () async {
          await client.itemsApi.downloadRemoteSubtitle(item.id, subtitleId);
          return awaitNewSubtitleStream(
            client: client,
            item: item,
            existingIndexes: existingIndexes,
            keepGoing: () => context.mounted,
          );
        },
      );
      if (!context.mounted) return;

      if (newStream != null) {
        final streamIndex = newStream['Index'] as int?;
        if (streamIndex != null) {
          unawaited(
            mutate(
              'downloaded_subtitle_$streamIndex',
              () => manager.changeSubtitleTrack(
                streamIndex,
                refreshStreams: true,
              ),
            ).then((_) {
              if (context.mounted) onSubtitlesChanged?.call();
            }),
          );
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.subtitleDownloadedSelected(
                newStream['DisplayTitle'] as String? ??
                    newStream['Title'] as String? ??
                    newStream['Language'] as String? ??
                    l10n.unknown,
              ),
            ),
          ),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.subtitleDownloadedPending)),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            remoteSubtitleErrorMessage(error, l10n, action: l10n.download),
          ),
        ),
      );
    }
  }
}
