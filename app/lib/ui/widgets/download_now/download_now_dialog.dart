import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/seerr/seerr_api_models.dart';
import '../../../l10n/app_localizations.dart';
import '../focus/focusable_wrapper.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// What the user picked in the Download Now dialog.
///
/// - [seasons] is non-empty when the user explicitly opted in to specific
///   seasons (and did NOT pick the "all seasons" toggle).
/// - [episodes] is keyed by season number and lists the episodes the user
///   kept for that season. When a season is fully covered (every episode
///   of that season is in the list) the caller can use the season-level
///   Seerr request, which is cheaper than per-episode Sonarr calls.
class DownloadNowChoice {
  final List<int> seasons;
  final Map<int, List<int>> episodes;

  const DownloadNowChoice({
    this.seasons = const [],
    this.episodes = const {},
  });

  /// True when at least one season has been restricted to a subset of its
  /// episodes — that path needs Sonarr, not just Seerr.
  bool get needsEpisodeLevel =>
      episodes.values.any((eps) => eps.isNotEmpty) &&
      episodes.values.any((eps) => eps.isEmpty);

  /// Per-season selection normalised: a season absent from [episodes] (or
  /// with an empty list) is treated as "all episodes wanted".
  Map<int, List<int>> get episodesBySeason => episodes;
}

/// Dialog for choosing which seasons (and which episodes within each
/// season) to download on a TV series. For movies the dialog short-circuits
/// to a single "Download" action without asking.
Future<DownloadNowChoice?> showDownloadNowDialog(
  BuildContext context, {
  required bool isTv,
  required String title,
  required List<SeerrSeason> seasons,
  required int numberOfSeasons,
}) async {
  if (!isTv || seasons.isEmpty) {
    // Movies and series with no season info go straight to download.
    return const DownloadNowChoice();
  }

  return showStyledPlayerDialog<DownloadNowChoice>(
    context,
    title: title,
    subtitle: appL10n().tgPickSeasonsEpisodes,
    builder: (ctx) => _DownloadNowDialog(
      seasons: seasons,
      numberOfSeasons: numberOfSeasons,
    ),
  );
}

class _DownloadNowDialog extends StatefulWidget {
  final List<SeerrSeason> seasons;
  final int numberOfSeasons;

  const _DownloadNowDialog({
    required this.seasons,
    required this.numberOfSeasons,
  });

  @override
  State<_DownloadNowDialog> createState() => _DownloadNowDialogState();
}

class _DownloadNowDialogState extends State<_DownloadNowDialog> {
  bool _allSeasons = true;
  final Set<int> _selectedSeasons = {};

  /// For each picked season, the episodes the user kept. Default = every
  /// episode; the user can deselect individual ones.
  final Map<int, Set<int>> _episodesBySeason = {};

  /// Fixed episode count per season, captured once from [SeerrSeason.episodeCount]
  /// at init. This must NOT be derived from [_episodesBySeason] (which shrinks
  /// as the user deselects) — otherwise the grid would re-render fewer and
  /// fewer tiles after every toggle, hiding high-numbered episodes that are
  /// still in the selection. That was the "removing ep 2 also removes ep 10"
  /// cascade: the tile count dropped below 10 so E10 stopped rendering even
  /// though it was still selected, and it then downloaded anyway.
  final Map<int, int> _episodeCountBySeason = {};

  late final List<int> _seasonNumbers = _computeSeasonNumbers(
    widget.seasons,
    widget.numberOfSeasons,
  );

  @override
  void initState() {
    super.initState();
    for (final s in widget.seasons) {
      final n = s.seasonNumber;
      if (n < 0) continue;
      final count = s.episodeCount ?? 0;
      _episodeCountBySeason[n] = count;
      if (count > 0) {
        _episodesBySeason[n] = {for (var i = 1; i <= count; i++) i};
      } else {
        _episodesBySeason[n] = <int>{};
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seasonNumbers = _seasonNumbers;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white12),
          SeerrToggleRow(
            title: l10n.allSeasons,
            value: _allSeasons,
            checkbox: true,
            autofocus: true,
            onChanged: (v) => setState(() {
              _allSeasons = v;
              if (_allSeasons) _selectedSeasons.clear();
            }),
          ),
          if (!_allSeasons && seasonNumbers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: seasonNumbers.map((seasonNumber) {
                  final selected = _selectedSeasons.contains(seasonNumber);
                  final seasonInfo = widget.seasons
                      .where((s) => s.seasonNumber == seasonNumber)
                      .firstOrNull;
                  final episodeCount = seasonInfo?.episodeCount;
                  final label = episodeCount != null && episodeCount > 0
                      ? 'S${seasonNumber.toString().padLeft(2, '0')} · $episodeCount ep'
                      : l10n.seasonChip(seasonNumber);
                  return SeerrChoiceChip(
                    label: label,
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedSeasons.add(seasonNumber);
                      } else {
                        _selectedSeasons.remove(seasonNumber);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            for (final s in _selectedSeasons) _SeasonEpisodeGrid(
              seasonNumber: s,
              totalEpisodes: _episodeCountBySeason[s] ??
                  _episodesBySeason[s]?.length ??
                  0,
              selected: _episodesBySeason[s] ?? <int>{},
              onChanged: (next) => setState(() {
                _episodesBySeason[s] = next;
              }),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SeerrDialogButton(
                  label: 'Download',
                  primary: true,
                  primaryColor: const Color(0xFF6366F1),
                  onPressed: _canSubmit()
                      ? () => Navigator.of(context).pop(_buildChoice())
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    if (_allSeasons) return true;
    if (_selectedSeasons.isEmpty) return false;
    // Make sure at least one episode is kept in every selected season.
    for (final s in _selectedSeasons) {
      final eps = _episodesBySeason[s];
      if (eps == null || eps.isEmpty) return false;
    }
    return true;
  }

  DownloadNowChoice _buildChoice() {
    if (_allSeasons) return const DownloadNowChoice();
    final sortedSeasons = _selectedSeasons.toList()..sort();
    final episodes = <int, List<int>>{};
    for (final s in sortedSeasons) {
      final eps = _episodesBySeason[s];
      if (eps == null) continue;
      episodes[s] = eps.toList()..sort();
    }
    return DownloadNowChoice(
      seasons: sortedSeasons,
      episodes: episodes,
    );
  }

  static List<int> _computeSeasonNumbers(
    List<SeerrSeason> seasons,
    int numberOfSeasons,
  ) {
    if (seasons.isEmpty) {
      return [for (var i = 1; i <= numberOfSeasons; i++) i];
    }
    final nums = seasons
        .map((s) => s.seasonNumber)
        .where((n) => n >= 0)
        .toSet()
        .toList()
      ..sort();
    return nums;
  }
}

/// Grid of episode checkboxes for a single season. Used inline beneath the
/// season chips. Designed for d-pad: each tile is focusable.
class _SeasonEpisodeGrid extends StatelessWidget {
  final int seasonNumber;
  final int totalEpisodes;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _SeasonEpisodeGrid({
    required this.seasonNumber,
    required this.totalEpisodes,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalEpisodes == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
        child: Text(
          appL10n().tgNoEpisodeInfo('S${seasonNumber.toString().padLeft(2, '0')}'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }
    final allOn = selected.length == totalEpisodes;
    final allOff = selected.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'S${seasonNumber.toString().padLeft(2, '0')} · ${selected.length}/$totalEpisodes',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _MiniButton(
                label: appL10n().tgAll,
                onPressed: allOn
                    ? null
                    : () => onChanged({
                          for (var i = 1; i <= totalEpisodes; i++) i,
                        }),
              ),
              const SizedBox(width: 6),
              _MiniButton(
                label: appL10n().tgNone,
                onPressed: allOff
                    ? null
                    : () => onChanged(<int>{}),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= totalEpisodes; i++)
                _EpisodeToggle(
                  label: 'E${i.toString().padLeft(2, '0')}',
                  selected: selected.contains(i),
                  onChanged: (v) {
                    final next = {...selected};
                    if (v) {
                      next.add(i);
                    } else {
                      next.remove(i);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EpisodeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const _EpisodeToggle({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWrapper(
      onSelect: () => onChanged(!selected),
      borderRadius: 8,
      disableScale: true,
      child: Container(
        width: 56,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColorScheme.accent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: AppRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColorScheme.onAccent.withValues(alpha: 0.6)
                : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? AppColorScheme.onAccent
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _MiniButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return FocusableWrapper(
      onSelect: onPressed,
      borderRadius: 6,
      disableScale: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.04),
          borderRadius: AppRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}
