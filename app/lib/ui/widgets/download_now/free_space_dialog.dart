import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/repositories/user_repository.dart';
import '../../../data/services/download/space_guard_service.dart';
import '../focus/focusable_wrapper.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// Called right before a picked release is sent to the download client.
///
/// Returns true when the download should go ahead: there is room, the user
/// made room, the user chose to download anyway, or the check itself failed
/// (a broken check must never block downloads that worked before). Returns
/// false only when the user cancelled in the dialog.
Future<bool> ensureSpaceForDownload(
  BuildContext context, {
  required int releaseBytes,
  required String releaseTitle,
}) async {
  try {
    final check = await SpaceGuardService().check(releaseBytes: releaseBytes);
    if (check == null || check.shortfallBytes <= 0) return true;
    if (!context.mounted) return true;
    final isAdmin =
        GetIt.instance<UserRepository>().currentUser?.isAdministrator ?? false;
    if (!isAdmin) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(
          appL10n().tgLowSpaceSnack(check.drive, formatBytes(check.freeBytes)),
        ),
      ));
      return true;
    }
    final result = await showFreeSpaceDialog(
      context,
      check: check,
      releaseTitle: releaseTitle,
    );
    return result ?? false;
  } catch (e) {
    debugPrint('[SpaceGuard] ensureSpaceForDownload failed: $e');
    return true;
  }
}

/// Opens the space guard without a pending download, for cleaning up ahead of
/// time. The user picks how much to free.
Future<void> showManualFreeSpaceDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final check = await SpaceGuardService().check();
  if (check == null) {
    messenger?.showSnackBar(SnackBar(
      content: Text(appL10n().tgNoQbitForSpace),
    ));
    return;
  }
  if (!context.mounted) return;
  await showFreeSpaceDialog(context, check: check);
}

/// Returns true when something was deleted (or "download anyway" was chosen)
/// and the pending download should continue; false/null when cancelled.
Future<bool?> showFreeSpaceDialog(
  BuildContext context, {
  required SpaceCheck check,
  String? releaseTitle,
}) {
  final forDownload = releaseTitle != null;
  return showStyledPlayerDialog<bool>(
    context,
    title: forDownload ? appL10n().tgNotEnoughSpace : appL10n().tgFreeUpSpace,
    subtitle: forDownload
        ? releaseTitle
        : appL10n().tgDriveHasFree(check.drive, formatBytes(check.freeBytes)),
    maxWidth: 620,
    barrierDismissible: false,
    builder: (_) => _FreeSpaceBody(check: check, forDownload: forDownload),
  );
}

String formatBytes(int bytes) {
  final gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 100) return '${gb.round()} GB';
  if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

String _ago(DateTime then) {
  final days = DateTime.now().toUtc().difference(then).inDays;
  if (days < 45) return appL10n().tgDaysAgo(days);
  final months = (days / 30.4).round();
  if (months < 12) return appL10n().tgMonthsAgo(months);
  final years = months ~/ 12;
  final rest = months % 12;
  return rest == 0 ? appL10n().tgYearsAgo(years) : appL10n().tgYearsMonthsAgo(years, rest);
}

String _reason(SpaceCandidate c) {
  if (c.kind == SpaceCandidateKind.duplicate) {
    return appL10n().tgCopyInDownloads;
  }
  final played = c.lastPlayed;
  if (played != null) return appL10n().tgLastWatched(_ago(played));
  final added = c.added;
  return added != null ? appL10n().tgNeverWatchedAdded(_ago(added)) : appL10n().tgNeverWatched;
}

const _kindsPrefKey = 'space_guard_kinds_v1';

class _FreeSpaceBody extends StatefulWidget {
  final SpaceCheck check;
  final bool forDownload;

  const _FreeSpaceBody({required this.check, required this.forDownload});

  @override
  State<_FreeSpaceBody> createState() => _FreeSpaceBodyState();
}

class _FreeSpaceBodyState extends State<_FreeSpaceBody> {
  static const _manualTargets = [25, 50, 100, 200];
  static const _extraVisible = 10;

  final _service = SpaceGuardService();

  List<SpaceCandidate>? _all;
  String? _loadError;

  /// Movies by default; duplicates are always worth offering first.
  Set<SpaceCandidateKind> _kinds = {
    SpaceCandidateKind.duplicate,
    SpaceCandidateKind.movie,
  };
  final Set<String> _selected = {};

  /// Said no to — never auto-suggested again while the dialog is open.
  final Set<String> _rejected = {};
  int _manualTargetGb = 50;

  bool _deleting = false;
  String? _progress;

  int get _targetBytes => widget.forDownload
      ? widget.check.shortfallBytes
      : _manualTargetGb * 1024 * 1024 * 1024;

  List<SpaceCandidate> get _visibleKinds =>
      (_all ?? const []).where((c) => _kinds.contains(c.kind)).toList();

  int get _selectedBytes => _visibleKinds
      .where((c) => _selected.contains(c.key))
      .fold(0, (sum, c) => sum + c.bytes);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kindsPrefKey);
      if (saved != null) {
        _kinds = {
          for (final k in SpaceCandidateKind.values)
            if (saved.contains(k.name)) k,
        };
      }
    } catch (_) {
      // Preferences are a convenience; the defaults are fine.
    }
    final all = await _service.candidates(drive: widget.check.drive);
    if (!mounted) return;
    setState(() {
      _all = all;
      if (all.isEmpty) {
        _loadError = appL10n().tgNothingSafeToDelete(widget.check.drive);
      }
      _autofill();
    });
  }

  /// Top up the selection with the best remaining suggestions until it covers
  /// the target. Never re-adds something the user said no to.
  void _autofill() {
    var sum = _selectedBytes;
    for (final c in _visibleKinds) {
      if (sum >= _targetBytes) break;
      if (_selected.contains(c.key) || _rejected.contains(c.key)) continue;
      _selected.add(c.key);
      sum += c.bytes;
    }
  }

  void _toggle(SpaceCandidate c) {
    setState(() {
      if (_selected.remove(c.key)) {
        _rejected.add(c.key);
        _autofill();
      } else {
        _rejected.remove(c.key);
        _selected.add(c.key);
      }
    });
  }

  void _toggleKind(SpaceCandidateKind kind) {
    setState(() {
      if (!_kinds.remove(kind)) _kinds.add(kind);
      final visible = _visibleKinds.map((c) => c.key).toSet();
      _selected.removeWhere((k) => !visible.contains(k));
      _autofill();
    });
    SharedPreferences.getInstance()
        .then((p) => p.setStringList(
              _kindsPrefKey,
              [for (final k in _kinds) k.name],
            ))
        .catchError((_) => false);
  }

  void _setManualTarget(int gb) {
    setState(() {
      _manualTargetGb = gb;
      _selected.clear();
      _autofill();
    });
  }

  Future<void> _deleteSelected() async {
    final items =
        _visibleKinds.where((c) => _selected.contains(c.key)).toList();
    if (items.isEmpty) return;
    final total = items.fold(0, (s, c) => s + c.bytes);
    final confirmed = await showStyledPlayerDialog<bool>(
      context,
      title: appL10n().tgDeleteTitlesQuestion(items.length),
      subtitle: appL10n().tgDeletedForGood(formatBytes(total)),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Row(
          children: [
            Expanded(
              child: SeerrDialogButton(
                label: appL10n().tgNo,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SeerrDialogButton(
                label: appL10n().tgYesDelete,
                primary: true,
                primaryColor: const Color(0xFFD32F2F),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await _service.delete(
      items,
      onProgress: (done, n) {
        if (mounted) setState(() => _progress = appL10n().tgDeletingProgress(done, n));
      },
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final after = await _service.check();
    if (!mounted) return;
    final freeText = after != null
        ? appL10n().tgNowHasFree(after.drive, formatBytes(after.freeBytes))
        : '';
    messenger?.showSnackBar(SnackBar(
      content: Text(result.failed.isEmpty
          ? appL10n().tgDeletedTitles(result.deleted, freeText)
          : appL10n().tgDeletedFailed(
              result.deleted, result.failed.join(', '), freeText)),
      duration: const Duration(seconds: 6),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    final all = _all;
    final visible = _visibleKinds;
    final chosen = visible.where((c) => _selected.contains(c.key)).toList();
    final others = visible
        .where((c) =>
            !_selected.contains(c.key) && !_rejected.contains(c.key))
        .take(_extraVisible)
        .toList();
    final selectedBytes = _selectedBytes;
    final covered = selectedBytes >= _targetBytes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white12),
          if (widget.forDownload)
            _Summary(check: check)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final gb in _manualTargets)
                  SeerrChoiceChip(
                    label: appL10n().tgFreeGb(gb),
                    selected: gb == _manualTargetGb,
                    onSelected: _deleting ? null : (_) => _setManualTarget(gb),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (kind, label) in [
                (SpaceCandidateKind.duplicate, appL10n().tgDownloadCopies),
                (SpaceCandidateKind.movie, appL10n().tgMovies),
                (SpaceCandidateKind.series, appL10n().tgSeries),
              ])
                SeerrChoiceChip(
                  label: label,
                  selected: _kinds.contains(kind),
                  onSelected: _deleting || all == null
                      ? null
                      : (_) => _toggleKind(kind),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (all == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      appL10n().tgLookingForUnwatched,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_loadError != null)
            Text(_loadError!,
                style: const TextStyle(color: Colors.white70, fontSize: 13))
          else ...[
            Text(
              covered
                  ? appL10n().tgSuggestionEnough(formatBytes(selectedBytes))
                  : appL10n().tgSuggestionOf(
                      formatBytes(selectedBytes), formatBytes(_targetBytes)),
              style: TextStyle(
                color: covered ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appL10n().tgPickToSayNo,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            for (var i = 0; i < chosen.length; i++)
              _CandidateRow(
                candidate: chosen[i],
                selected: true,
                autofocus: i == 0,
                onSelect: _deleting ? null : () => _toggle(chosen[i]),
              ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                appL10n().tgOtherCandidates,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final c in others)
                _CandidateRow(
                  candidate: c,
                  selected: false,
                  autofocus: chosen.isEmpty && c == others.first,
                  onSelect: _deleting ? null : () => _toggle(c),
                ),
            ],
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgCancel,
                  onPressed: _deleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ),
              if (widget.forDownload) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SeerrDialogButton(
                    label: appL10n().tgDownloadAnyway,
                    onPressed: _deleting
                        ? null
                        : () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgDeleteCountSize(chosen.length, formatBytes(selectedBytes)),
                  primary: true,
                  primaryColor: const Color(0xFFD32F2F),
                  busy: _deleting,
                  busyLabel: _progress,
                  onPressed: _deleting || chosen.isEmpty
                      ? null
                      : _deleteSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final SpaceCheck check;
  const _Summary({required this.check});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white70, fontSize: 13, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appL10n().tgDriveHasFreeDot(check.drive, formatBytes(check.freeBytes)),
          style: style,
        ),
        Text(
          SpaceGuardConfig.importCopyFactor > 1
              ? appL10n().tgFileDoubleSpace(formatBytes(check.releaseBytes),
                  formatBytes(SpaceGuardConfig.bufferBytes))
              : appL10n().tgFileSize(formatBytes(check.releaseBytes),
                  formatBytes(SpaceGuardConfig.bufferBytes)),
          style: style,
        ),
        if (check.pendingBytes > 0)
          Text(
            appL10n().tgPendingNeeds(formatBytes(check.pendingBytes)),
            style: style,
          ),
        const SizedBox(height: 4),
        Text(
          appL10n().tgShortBy(formatBytes(check.shortfallBytes)),
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final SpaceCandidate candidate;
  final bool selected;
  final bool autofocus;
  final VoidCallback? onSelect;

  const _CandidateRow({
    required this.candidate,
    required this.selected,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final icon = switch (c.kind) {
      SpaceCandidateKind.duplicate => Icons.file_copy_outlined,
      SpaceCandidateKind.movie => Icons.movie_outlined,
      SpaceCandidateKind.series => Icons.tv_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FocusableWrapper(
        onSelect: onSelect,
        autofocus: autofocus,
        autoScroll: true,
        borderRadius: 10,
        disableScale: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFD32F2F).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: AppRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFFD32F2F).withValues(alpha: 0.6)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: selected ? const Color(0xFFFF8A80) : Colors.white54,
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.year != null ? '${c.title} (${c.year})' : c.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reason(c),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatBytes(c.bytes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
