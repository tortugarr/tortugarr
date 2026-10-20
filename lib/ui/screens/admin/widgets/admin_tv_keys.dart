import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad way out of the admin pages' text fields and sliders on TV.
///
/// The admin pages are built for touch. A text field keeps Up/Down for its
/// cursor and a slider for its value, so a remote got stuck on them and the
/// app had to be closed; a mouse was the only way out (2026-10-20). Here Up
/// and Down always move to the field above or below, Left/Right still edit,
/// and Back in a text field leaves the field instead of the page.
///
/// A HardwareKeyboard handler sees the key before the focused widget does,
/// which a Focus or Shortcuts above the page would not.
class AdminTvKeys extends StatefulWidget {
  const AdminTvKeys({super.key, required this.child});

  final Widget child;

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
    if (!inText && !inSlider) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      node.focusInDirection(TraversalDirection.up);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      node.focusInDirection(TraversalDirection.down);
      return true;
    }
    if (inText &&
        (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape)) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      if (!node.focusInDirection(TraversalDirection.down)) {
        node.focusInDirection(TraversalDirection.up);
      }
      return true;
    }
    return false;
  }

  /// Only the admin area: the handler is global while this widget lives.
  bool _insideArea(BuildContext ctx) {
    final area = _area.currentContext;
    if (area == null) return false;
    var inside = false;
    ctx.visitAncestorElements((e) {
      if (e == area) inside = true;
      return !inside;
    });
    return inside;
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _area, child: widget.child);
}
