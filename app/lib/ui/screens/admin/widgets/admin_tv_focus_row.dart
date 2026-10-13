import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_drawer.dart';

/// TV layout for the admin shell: the menu on the left, the page on the
/// right, with d-pad moves between them that the touch layout never needed.
///
/// The page and the menu are separate traversal groups, so "left" from the
/// page dead-ends and "right" from the menu does nothing. This routes those
/// presses explicitly and starts focus on the current menu entry.
///
/// When a page opens from the menu, the page cannot take focus until the
/// menu entry has it: otherwise a search field grabs focus and the OK press
/// that opened the page pops up the keyboard.
///
/// Text fields behave like the app's own TV search fields: arrows move past
/// them with the keyboard closed, and OK opens the keyboard.
class AdminTvFocusRow extends StatefulWidget {
  final Widget drawer;
  final Widget content;
  final AdminDrawerFocusController drawerFocus;

  /// The page shown; a change to a menu page re-homes focus in the menu.
  final String currentPath;
  final bool isMenuPage;

  const AdminTvFocusRow({
    super.key,
    required this.drawer,
    required this.content,
    required this.drawerFocus,
    required this.currentPath,
    required this.isMenuPage,
  });

  @override
  State<AdminTvFocusRow> createState() => _AdminTvFocusRowState();
}

class _AdminTvFocusRowState extends State<AdminTvFocusRow> {
  final _contentArea = FocusNode(
    debugLabel: 'AdminContentArea',
    skipTraversal: true,
    canRequestFocus: false,
  );
  Timer? _homeFocus;
  bool _contentFocusable = false;
  bool _keyboardRequested = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    _focusMenuThenUnlock();
  }

  bool _inContent(FocusNode node) => node.ancestors.contains(_contentArea);

  static bool _isTextField(FocusNode? node) =>
      node?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  /// Focus reached a text field by d-pad: keep the keyboard down until OK.
  void _onFocusChanged() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || !_inContent(node) || !_isTextField(node)) return;
    if (_keyboardRequested) {
      _keyboardRequested = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  @override
  void didUpdateWidget(AdminTvFocusRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPath != oldWidget.currentPath && widget.isMenuPage) {
      _contentFocusable = false;
      _focusMenuThenUnlock();
    }
  }

  void _focusMenuThenUnlock() {
    _homeFocus?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.drawerFocus.focusSelected();
    });
    // Long enough for the key-up of the OK press and the page's first build.
    _homeFocus = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.drawerFocus.focusSelected();
      setState(() => _contentFocusable = true);
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _homeFocus?.cancel();
    _contentArea.dispose();
    super.dispose();
  }

  KeyEventResult _onContentKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final onText = _isTextField(focused);

    if (onText &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _keyboardRequested = true;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return KeyEventResult.handled;
    }

    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    // Elsewhere only "left" needs help; in a text field every arrow moves
    // focus, since the keyboard (when open) takes the d-pad itself.
    if (!onText && direction != TraversalDirection.left) {
      return KeyEventResult.ignored;
    }
    if (focused.focusInDirection(direction)) return KeyEventResult.handled;
    if (direction == TraversalDirection.left) {
      widget.drawerFocus.focusSelected();
      return KeyEventResult.handled;
    }
    return onText ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  KeyEventResult _onDrawerKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    _focusContent();
    return KeyEventResult.handled;
  }

  void _focusContent() {
    if (_contentFocusable) {
      _focusFirstInContent();
      return;
    }
    _homeFocus?.cancel();
    setState(() => _contentFocusable = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFirstInContent();
    });
  }

  /// The top-left focusable thing that is actually on screen.
  void _focusFirstInContent() {
    final area = _contentArea.rect;
    // Leaves only: a focusable page or card around the controls is not a
    // useful place to land.
    final candidates = _contentArea.traversalDescendants
        .where((n) =>
            n.canRequestFocus &&
            n.context != null &&
            !n.traversalDescendants.any((d) => d.canRequestFocus))
        .toList();
    if (candidates.isEmpty) return;
    final visible =
        candidates.where((n) => n.rect.overlaps(area)).toList();
    final pool = visible.isNotEmpty ? visible : candidates;
    pool.sort((a, b) {
      final byTop = a.rect.top.compareTo(b.rect.top);
      return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
    });
    pool.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Focus(
          skipTraversal: true,
          canRequestFocus: false,
          onKeyEvent: _onDrawerKey,
          child: widget.drawer,
        ),
        Expanded(
          child: Focus(
            focusNode: _contentArea,
            descendantsAreFocusable: _contentFocusable,
            onKeyEvent: _onContentKey,
            child: widget.content,
          ),
        ),
      ],
    );
  }
}
