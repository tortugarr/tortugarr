import 'package:flutter/widgets.dart';

mixin GridFocusNodeMixin<T extends StatefulWidget> on State<T> {
  final Map<int, FocusNode> gridItemFocusNodes = {};
  final Map<int, VoidCallback> _gridItemListeners = {};
  int? lastFocusedGridIndex;
  int gridContentVersion = 0;
  int lastFocusedGridContentVersion = 0;

  FocusNode getGridItemFocusNode(int index, {String prefix = 'grid_item'}) {
    final existing = gridItemFocusNodes[index];
    if (existing != null) return existing;
    final node = FocusNode(debugLabel: '$prefix:$index');
    void listener() => trackGridItemFocus(index, node.hasFocus);
    node.addListener(listener);
    gridItemFocusNodes[index] = node;
    _gridItemListeners[index] = listener;
    return node;
  }

  void trackGridItemFocus(int index, bool hasFocus) {
    if (!hasFocus) return;
    lastFocusedGridIndex = index;
    lastFocusedGridContentVersion = gridContentVersion;
  }

  void cleanupGridFocusNodes(int currentCount) {
    final toRemove = gridItemFocusNodes.keys
        .where((i) => i >= currentCount)
        .toList(growable: false);
    for (final i in toRemove) {
      final node = gridItemFocusNodes.remove(i);
      final listener = _gridItemListeners.remove(i);
      if (node != null) {
        if (listener != null) node.removeListener(listener);
        node.dispose();
      }
    }
  }

  void disposeGridFocusNodes() {
    for (final entry in gridItemFocusNodes.entries) {
      final listener = _gridItemListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
      entry.value.dispose();
    }
    gridItemFocusNodes.clear();
    _gridItemListeners.clear();
  }

  void restoreGridFocusIfNeeded() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (lastFocusedGridContentVersion == gridContentVersion) return;
    final idx = lastFocusedGridIndex;
    if (idx == null) return;
    // The grid may have shrunk, so fall back to the last available row when the
    // remembered index no longer exists.
    var node = gridItemFocusNodes[idx];
    if (node == null && gridItemFocusNodes.isNotEmpty) {
      final maxIndex = gridItemFocusNodes.keys.reduce((a, b) => a > b ? a : b);
      node = gridItemFocusNodes[maxIndex];
    }
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
    }
    lastFocusedGridContentVersion = gridContentVersion;
  }
}
