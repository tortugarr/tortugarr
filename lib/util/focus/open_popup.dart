import 'package:flutter/widgets.dart';

/// A popup that is open right now, with the navigator it sits on.
typedef OpenPopup = ({NavigatorState navigator, Route<dynamic> route});

/// The popup on top of the navigator nearest [focus], or failing that on top
/// of [root]. Dialogs, menus and sheets are PopupRoutes and screens are
/// PageRoutes, so the split holds on the root navigator and inside a nested
/// one like the settings panel's.
OpenPopup? openPopupFor({
  required FocusNode? focus,
  required NavigatorState? root,
}) {
  final focusContext = focus?.context;
  final nearest = focusContext == null ? null : Navigator.maybeOf(focusContext);
  for (final navigator in [nearest, root]) {
    if (navigator == null) continue;
    final top = _topRouteOf(navigator);
    if (top is PopupRoute) return (navigator: navigator, route: top);
  }
  return null;
}

Route<dynamic>? _topRouteOf(NavigatorState navigator) {
  Route<dynamic>? top;
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  return top;
}

/// Whether [focus] sits somewhere inside [route] rather than on a screen
/// underneath or beside it.
bool focusIsInside(FocusNode? focus, Route<dynamic> route) {
  final context = focus?.context;
  return context != null && ModalRoute.of(context) == route;
}
