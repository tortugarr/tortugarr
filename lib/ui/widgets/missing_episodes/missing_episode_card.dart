import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/download/missing_episodes.dart';
import '../focus/focusable_wrapper.dart';
import 'package:moonfin/util/app_l10n.dart';

/// A short date in the app's language, with the year when it is not this year.
String norwegianShortDate(DateTime date, {DateTime? now}) =>
    appShortDate(date, now: now);

/// What the badge on a missing episode says.
String missingEpisodeBadge(MissingEpisode m) => switch (m.state) {
      MissingEpisodeState.missing => appL10n().tgMissing,
      MissingEpisodeState.unaired => m.airDate == null
          ? appL10n().tgComing
          : appL10n().tgComingOn(norwegianShortDate(m.airDate!)),
      MissingEpisodeState.downloading => appL10n().tgDownloading,
      MissingEpisodeState.importing => appL10n().tgReadySoon,
    };

Color _badgeColor(MissingEpisodeState state) => switch (state) {
      MissingEpisodeState.missing => const Color(0xFFD32F2F),
      MissingEpisodeState.unaired => Colors.white24,
      MissingEpisodeState.downloading => const Color(0xFF1E88E5),
      MissingEpisodeState.importing => const Color(0xFF2E7D32),
    };

/// A greyed-out row for an episode Sonarr knows but the library does not
/// have. Same footprint as the normal episode card so the list lines up.
class MissingEpisodeCard extends StatelessWidget {
  final MissingEpisode missing;
  final VoidCallback onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final bool autofocus;

  const MissingEpisodeCard({
    super.key,
    required this.missing,
    required this.onSelect,
    this.focusNode,
    this.onNavigateUp,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final m = missing;
    final title = (m.title ?? '').trim();
    final aired = m.airDate;
    final detail = [
      if (aired != null && m.state != MissingEpisodeState.unaired)
        appL10n().tgAiredOn(norwegianShortDate(aired)),
      if (m.canDownload) appL10n().tgTapToFindFiles,
    ].join(' · ');

    return FocusableWrapper(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onSelect,
      onNavigateUp: onNavigateUp,
      autoScroll: true,
      borderRadius: 8,
      disableScale: true,
      semanticLabel: '${m.code} ${missingEpisodeBadge(m)}',
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          height: compact ? 72 : 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: AppRadius.circular(8),
            border: Border.all(
              color: m.canDownload
                  ? const Color(0xFFD32F2F).withValues(alpha: 0.55)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 110 : 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'E${m.number.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Episode ${m.number}' : '${m.number}. $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _badgeColor(m.state),
                        borderRadius: AppRadius.circular(6),
                      ),
                      child: Text(
                        missingEpisodeBadge(m),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (m.canDownload) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.download_for_offline_outlined,
                          color: Colors.white54, size: 22),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Last ned hele sesongen" row above a season's episodes.
class SeasonPackButton extends StatelessWidget {
  final int missingCount;
  final VoidCallback onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final bool autofocus;

  const SeasonPackButton({
    super.key,
    required this.missingCount,
    required this.onSelect,
    this.focusNode,
    this.onNavigateUp,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => _ActionRow(
        icon: Icons.download_for_offline,
        title: appL10n().tgWholeSeason,
        subtitle: appL10n().tgEpisodesMissingFindPack(missingCount),
        onSelect: onSelect,
        focusNode: focusNode,
        onNavigateUp: onNavigateUp,
        autofocus: autofocus,
      );
}

/// Offered when Sonarr does not have the series yet.
class AddToSonarrTile extends StatelessWidget {
  final VoidCallback onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;

  const AddToSonarrTile({
    super.key,
    required this.onSelect,
    this.focusNode,
    this.onNavigateUp,
  });

  @override
  Widget build(BuildContext context) => _ActionRow(
        icon: Icons.playlist_add,
        title: appL10n().tgAddToSonarrTitle,
        subtitle: appL10n().tgAddToSonarrSubtitle,
        onSelect: onSelect,
        focusNode: focusNode,
        onNavigateUp: onNavigateUp,
      );
}

/// Shown instead of silence when the missing episodes cannot be loaded;
/// selecting it tries again.
class MissingEpisodesStatusNote extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;

  const MissingEpisodesStatusNote({
    super.key,
    required this.reason,
    required this.onRetry,
    this.focusNode,
    this.onNavigateUp,
  });

  @override
  Widget build(BuildContext context) => _ActionRow(
        icon: Icons.info_outline,
        title: appL10n().tgMissingEpisodesUnavailable,
        subtitle: appL10n().tgReasonTapRetry(reason),
        onSelect: onRetry,
        focusNode: focusNode,
        onNavigateUp: onNavigateUp,
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final bool autofocus;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelect,
    this.focusNode,
    this.onNavigateUp,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWrapper(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onSelect,
      onNavigateUp: onNavigateUp,
      autoScroll: true,
      borderRadius: 8,
      disableScale: true,
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColorScheme.accent.withValues(alpha: 0.18),
            borderRadius: AppRadius.circular(8),
            border: Border.all(color: AppColorScheme.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
