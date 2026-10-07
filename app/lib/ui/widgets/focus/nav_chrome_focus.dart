import 'package:flutter/widgets.dart';

/// Focus nodes that belong to navigation chrome (the left sidebar rail and the
/// top toolbar). Initial focus on a freshly pushed route avoids them, so the
/// route lands in its own content instead of an invisible sidebar button.
abstract final class NavChromeFocus {
  static final Set<FocusNode> _nodes = <FocusNode>{};

  static void register(FocusNode node) => _nodes.add(node);

  static void unregister(FocusNode node) => _nodes.remove(node);

  /// Whether [node] is a chrome node or sits inside one.
  static bool contains(FocusNode? node) {
    var current = node;
    while (current != null) {
      if (_nodes.contains(current)) return true;
      current = current.parent;
    }
    return false;
  }

  /// Whether the widget at [context] belongs to the route the user is on.
  /// A tap or key on a route underneath (it can hold focus while a pushed
  /// route loads) must not navigate again.
  static bool isOnCurrentRoute(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent ?? true;
}
