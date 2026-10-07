import 'package:flutter/material.dart';

import '../focus/focusable_wrapper.dart';
import 'package:moonfin/util/app_l10n.dart';

/// One season in the switcher: a library season (has [itemId]) or a season
/// only Sonarr knows about ([itemId] null, shown greyed as "Mangler").
class SeasonSwitcherEntry {
  final int? number;
  final String label;
  final String? itemId;
  final String? serverId;

  const SeasonSwitcherEntry({
    required this.number,
    required this.label,
    this.itemId,
    this.serverId,
  });

  bool get missing => itemId == null;

  /// All seasons in order: the library's seasons plus [missingSeasons], with
  /// seasons without a number (rare) kept in their library order at the end.
  static List<SeasonSwitcherEntry> combine({
    required List<({String id, String? serverId, int? number, String name})> library,
    required List<int> missingSeasons,
    required String Function(int number) missingLabel,
  }) {
    final entries = [
      for (final s in library)
        SeasonSwitcherEntry(
          number: s.number,
          label: s.name,
          itemId: s.id,
          serverId: s.serverId,
        ),
      for (final n in missingSeasons)
        if (!library.any((s) => s.number == n))
          SeasonSwitcherEntry(number: n, label: missingLabel(n)),
    ];
    final numbered = entries.where((e) => e.number != null).toList()
      ..sort((a, b) => a.number!.compareTo(b.number!));
    return [...numbered, ...entries.where((e) => e.number == null)];
  }
}

/// A horizontal row of season chips on a Season page, so the user can jump to
/// any other season (including ones the library is missing) without going
/// back to the series first.
class SeasonSwitcher extends StatefulWidget {
  final List<SeasonSwitcherEntry> entries;
  final String? currentItemId;
  final ValueChanged<SeasonSwitcherEntry> onSelect;
  final FocusNode? currentFocusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const SeasonSwitcher({
    super.key,
    required this.entries,
    required this.currentItemId,
    required this.onSelect,
    this.currentFocusNode,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  State<SeasonSwitcher> createState() => _SeasonSwitcherState();
}

class _SeasonSwitcherState extends State<SeasonSwitcher> {
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Bring the current season into view, e.g. season 9 of 10.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = widget.entries[i];
          final current = e.itemId != null && e.itemId == widget.currentItemId;
          return FocusableWrapper(
            key: current ? _currentKey : null,
            focusNode: current ? widget.currentFocusNode : null,
            onSelect: current ? null : () => widget.onSelect(e),
            onNavigateUp: widget.onNavigateUp,
            onNavigateDown: widget.onNavigateDown,
            autoScroll: true,
            borderRadius: 20,
            disableScale: true,
            semanticLabel: e.missing ? appL10n().tgLabelMissing(e.label) : e.label,
            child: GestureDetector(
              onTap: current ? null : () => widget.onSelect(e),
              child: _Chip(entry: e, current: current),
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final SeasonSwitcherEntry entry;
  final bool current;

  const _Chip({required this.entry, required this.current});

  @override
  Widget build(BuildContext context) {
    final missing = entry.missing;
    final bg = current
        ? Colors.white
        : missing
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.14);
    final fg = current
        ? Colors.black
        : missing
            ? Colors.white54
            : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: missing && !current
            ? Border.all(color: const Color(0xFFD32F2F).withValues(alpha: 0.7))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.label,
            style: TextStyle(
              color: fg,
              fontWeight: current ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (missing) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                appL10n().tgMissing,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
