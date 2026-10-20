import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad navigation for the admin area on TV.
///
/// The admin pages are built for touch. A text field keeps Up/Down for its
/// cursor and a slider for its value, so a remote got stuck on them and the
/// app had to be closed; a mouse was the only way out (2026-10-20). Here Up
/// and Down always move to the field above or below, Left/Right still edit,
/// and Back in a text field leaves the field instead of the page.
///
/// Each page also sits in the shell's own navigator, whose focus scope kept
/// the remote from reaching the rail, the page list and the search box, and a
/// page whose top has nothing focusable (the dashboard's tiles) never scrolled
/// back up. When the usual move finds nothing, Up first scrolls the page to
/// its top, and then the nearest control in that direction anywhere in the
/// admin area takes focus.
///
/// Back goes one step at a time: a screen opened inside the area closes, the
/// page hands focus to the page list, the page list to the rail, and only the
/// rail leaves the area. It went straight to the home screen before.
///
/// A HardwareKeyboard handler sees the key before the focused widget does,
/// which a Focus or Shortcuts above the page would not.
class AdminTvKeys extends StatefulWidget {
  const AdminTvKeys({super.key, required this.child, this.pages});

  final Widget child;

  /// The navigator the admin pages live in.
  final GlobalKey<NavigatorState>? pages;

  @override
  State<AdminTvKeys> createState() => _AdminTvKeysState();
}

class _AdminTvKeysState extends State<AdminTvKeys> {
  final _area = GlobalKey();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final node = FocusManager.instance.primaryFocus;
    final ctx = node?.context;
    if (node == null || ctx == null || !mounted) return false;
    if (!_insideArea(ctx)) return false;

    final inText = ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    final inSlider = ctx.findAncestorWidgetOfExactType<Slider>() != null ||
        ctx.findAncestorWidgetOfExactType<RangeSlider>() != null;

    final key = event.logicalKey;
    final direction = _directions[key];
    if (direction != null) {
      // Left/Right edit a text field or a slider.
      final horizontal = direction == TraversalDirection.left ||
          direction == TraversalDirection.right;
      if (horizontal && (inText || inSlider)) return false;
      _move(node, ctx, direction);
      return true;
    }
    final back = key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape;
    if (back && inText) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      if (!node.focusInDirection(TraversalDirection.down)) {
        node.focusInDirection(TraversalDirection.up);
      }
      return true;
    }
    if (back) return _back(node, ctx);
    return false;
  }

  bool _back(FocusNode node, BuildContext ctx) {
    final pages = widget.pages?.currentContext;
    // A screen opened inside the area closes the usual way.
    if (widget.pages?.currentState?.canPop() ?? false) return false;
    // Page -> page list -> rail; from the rail Back leaves the area.
    final target = _nearestInArea(
      node,
      TraversalDirection.left,
      where: (c) => pages == null || !_isInside(c, pages),
    );
    if (target == null) return false;
    target.requestFocus();
    return true;
  }

  static final _directions = <LogicalKeyboardKey, TraversalDirection>{
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
  };

  void _move(FocusNode node, BuildContext ctx, TraversalDirection direction) {
    if (node.focusInDirection(direction)) return;
    if (direction == TraversalDirection.up) {
      final position = Scrollable.maybeOf(ctx)?.position;
      if (position != null && position.pixels > position.minScrollExtent + 1) {
        position.animateTo(position.minScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        return;
      }
    }
    _nearestInArea(node, direction)?.requestFocus();
  }

  /// The closest focusable control in [direction] across the whole admin
  /// area, past the page navigator's focus scope.
  FocusNode? _nearestInArea(
    FocusNode from,
    TraversalDirection direction, {
    bool Function(BuildContext)? where,
  }) {
    final r = from.rect;
    FocusNode? best;
    var bestScore = double.infinity;
    for (final n in FocusManager.instance.rootScope.traversalDescendants) {
      if (n == from || n is FocusScopeNode || !n.canRequestFocus) continue;
      final c = n.context;
      if (c == null || !_insideArea(c)) continue;
      if (where != null && !where(c)) continue;
      final o = n.rect;
      if (o.isEmpty) continue;
      final double gap;
      final double cross;
      switch (direction) {
        case TraversalDirection.up:
          gap = r.top - o.bottom;
          cross = _rangeGap(r.left, r.right, o.left, o.right);
        case TraversalDirection.down:
          gap = o.top - r.bottom;
          cross = _rangeGap(r.left, r.right, o.left, o.right);
        case TraversalDirection.left:
          gap = r.left - o.right;
          cross = _rangeGap(r.top, r.bottom, o.top, o.bottom);
        case TraversalDirection.right:
          gap = o.left - r.right;
          cross = _rangeGap(r.top, r.bottom, o.top, o.bottom);
      }
      if (gap < -1) continue;
      final score = gap + cross * 2;
      if (score < bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return best;
  }

  static double _rangeGap(double a1, double a2, double b1, double b2) =>
      b2 < a1 ? a1 - b2 : (b1 > a2 ? b1 - a2 : 0);

  /// Only the admin area: the handler is global while this widget lives.
  bool _insideArea(BuildContext ctx) {
    final area = _area.currentContext;
    return area != null && _isInside(ctx, area);
  }

  static bool _isInside(BuildContext ctx, BuildContext ancestor) {
    var inside = false;
    ctx.visitAncestorElements((e) {
      if (e == ancestor) inside = true;
      return !inside;
    });
    return inside;
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _area, child: widget.child);
}
