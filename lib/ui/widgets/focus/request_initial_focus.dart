import 'dart:async';

import 'package:flutter/widgets.dart';

import '../left_sidebar.dart';
import '../top_toolbar.dart';
import 'can_claim_initial_focus.dart';
import 'nav_chrome_focus.dart';

/// Wraps a screen subtree and grants focus to the first focusable descendant
/// after the first frame so dpad navigation works on a freshly pushed route.
/// Retries briefly if focusable widgets are not yet registered (e.g. while
/// the screen is loading async data).
///
/// If [targetNode] is provided, focus is granted to that specific node once it
/// attaches to the tree. This is useful when async-loaded content provides the
/// preferred initial focus target.
class RequestInitialFocus extends StatefulWidget {
  final Widget child;
  final FocusNode? targetNode;

  const RequestInitialFocus({super.key, required this.child, this.targetNode});

  @override
  State<RequestInitialFocus> createState() => _RequestInitialFocusState();
}

class _RequestInitialFocusState extends State<RequestInitialFocus> {
  static const _maxAttemptsScope = 60;
  static const _maxAttemptsTarget = 60;
  static const _retryDelay = Duration(milliseconds: 50);
  Timer? _retryTimer;
  bool _settled = false;
  bool _frameCheckQueued = false;

  @override
  void initState() {
    super.initState();
    _scheduleFrameFocusCheck(0);
  }

  @override
  void didUpdateWidget(RequestInitialFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.targetNode, widget.targetNode) &&
        widget.targetNode != null) {
      // A target arriving late, usually once async content loads, is the
      // screen's preferred landing spot. By then the generic route focus
      // grab may have parked focus in the sidebar or toolbar, so the target
      // still wins over chrome, just never over focused content.
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      final primary = FocusManager.instance.primaryFocus;
      final scope = FocusScope.of(context);
      final chromeHasFocus = LeftSidebar.isFocusedNotifier.value ||
          TopToolbar.isFocusedNotifier.value ||
          NavChromeFocus.contains(primary);
      // Focus parked on the bare scope means nothing concrete was chosen yet.
      final onlyScope = identical(primary, scope);
      if (isCurrent && (!scope.hasFocus || chromeHasFocus || onlyScope)) {
        _retryTimer?.cancel();
        _settled = false;
        _scheduleFrameFocusCheck(0);
      }
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _tryFocus(int attempt) {
    if (!mounted || _settled) return;
    // didUpdateWidget checks this too, but build re-arms the retry as well,
    // so a rebuild behind an open panel would otherwise walk off with focus.
    if (!canClaimInitialFocus(context)) return;
    final target = widget.targetNode;
    final scope = FocusScope.of(context);

    if (target != null) {
      final attached = target.context != null;
      final canReq = target.canRequestFocus;
      if (target.hasFocus) {
        _settled = true;
        return;
      }
      if (attached && canReq) {
        scope.requestFocus(target);
        if (target.hasFocus) {
          _settled = true;
          return;
        }
      }
      if (attempt + 1 >= _maxAttemptsTarget) {
        return;
      }
      _retryTimer = Timer(_retryDelay, () {
        _retryTimer = null;
        _tryFocus(attempt + 1);
      });
      return;
    }

    if (_scopeHasContentFocus(scope)) {
      _settled = true;
      return;
    }
    // Prefer the route's own content. Chrome (sidebar rail, toolbar) is only
    // used once retries run out, so a screen still loading its data does not
    // land on an invisible sidebar button.
    if (_requestFirstDescendantFocus(scope, allowChrome: false)) {
      _settled = true;
      return;
    }
    if (attempt + 1 >= _maxAttemptsScope) {
      // No content took focus in time: fall back to chrome, as before.
      if (!_requestFirstDescendantFocus(scope, allowChrome: true) &&
          !_scopeHasFocus(scope)) {
        scope.requestFocus();
      }
      _settled = true;
      return;
    }
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      _tryFocus(attempt + 1);
    });
  }

  void _scheduleFrameFocusCheck(int attempt) {
    if (!mounted || _settled || _frameCheckQueued) return;
    _frameCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCheckQueued = false;
      _tryFocus(attempt);
    });
  }

  bool _requestFirstDescendantFocus(
    FocusScopeNode scope, {
    required bool allowChrome,
  }) {
    for (final node in scope.traversalDescendants) {
      if (identical(node, scope)) continue;
      if (node.context == null) continue;
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (node is FocusScopeNode) continue;
      if (!allowChrome && NavChromeFocus.contains(node)) continue;
      scope.requestFocus(node);
      if (node.hasFocus) return true;
    }
    return false;
  }

  /// Focus is inside [scope] on something other than chrome or the scope.
  bool _scopeHasContentFocus(FocusScopeNode scope) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || identical(primary, scope)) return false;
    if (NavChromeFocus.contains(primary)) return false;
    return _scopeHasFocus(scope);
  }

  bool _scopeHasFocus(FocusScopeNode scope) {
    if (scope.focusedChild != null) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    FocusNode? node = primary;
    while (node != null) {
      if (identical(node, scope)) return true;
      node = node.parent;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_settled && _retryTimer == null) {
      _scheduleFrameFocusCheck(0);
    }
    return widget.child;
  }
}
