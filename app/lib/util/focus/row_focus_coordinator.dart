import 'package:flutter/widgets.dart';

import '../../ui/widgets/focus/locked_focus_row.dart';

/// One vertically-ordered focus stop on a row-based screen: either a plain
/// [FocusNode] (hero CTA, filter pill) or a [LockedFocusRow] shelf, which
/// restores its remembered horizontal position when focused.
class RowFocusEntry {
  final FocusNode? node;
  final GlobalKey<LockedFocusRowState>? rowKey;

  /// Context anchor scrolled into view when this entry takes focus.
  final GlobalKey? containerKey;

  const RowFocusEntry.node(FocusNode this.node, {this.containerKey})
    : rowKey = null;

  const RowFocusEntry.row(
    GlobalKey<LockedFocusRowState> this.rowKey, {
    this.containerKey,
  }) : node = null;

  bool focus() {
    final node = this.node;
    if (node != null) {
      if (!node.canRequestFocus) return false;
      node.requestFocus();
      return true;
    }
    final state = rowKey!.currentState;
    if (state == null || state.widget.items.isEmpty) return false;
    state.requestFocusFromMemory();
    return true;
  }
}

/// Extraction of the home screen's inter-row D-pad glue: an ordered list of
/// focus stops with vertical movement that skips empty/unfocusable entries
/// and scrolls the target into view. Rebuild [entries] on every build so the
/// order tracks row composition (scope filters, hidden rows).
class RowFocusCoordinator {
  List<RowFocusEntry> entries = const [];

  /// Moves focus up/down from [fromIndex]. Returns false when there is no
  /// focusable entry in that direction (caller hands focus to the navbar or
  /// lets the event bubble).
  bool moveVertical({required int fromIndex, required bool isUp}) {
    final step = isUp ? -1 : 1;
    for (var i = fromIndex + step; i >= 0 && i < entries.length; i += step) {
      if (_focusEntry(entries[i])) return true;
    }
    return false;
  }

  /// Focuses the first focusable entry (initial TV focus).
  bool focusFirst() {
    for (final entry in entries) {
      if (_focusEntry(entry)) return true;
    }
    return false;
  }

  bool _focusEntry(RowFocusEntry entry) {
    if (!entry.focus()) return false;
    final ctx = entry.containerKey?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
    return true;
  }
}
