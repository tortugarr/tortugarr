import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Pushes a route unless that same location is already on top or already on
/// its way there.
///
/// One OK press on TV could reach a card's activation twice and stack two
/// identical detail pages, so Back showed the same page again. The guard is
/// not time-based: a push is in flight until the router reports a new
/// location, and a location that is already current is never pushed again.
abstract final class SinglePush {
  static String? _inFlight;
  static bool _listening = false;

  static String _path(String location) => Uri.parse(location).path;

  static String _currentPath() =>
      appRouter.routerDelegate.currentConfiguration.uri.path;

  static void _onRouteChanged() => _inFlight = null;

  /// Whether pushing [location] now would be a duplicate.
  @visibleForTesting
  static bool isDuplicate(String location, {required String currentPath}) {
    final path = _path(location);
    return path == currentPath || path == _inFlight;
  }

  @visibleForTesting
  static void markInFlight(String? location) =>
      _inFlight = location == null ? null : _path(location);

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location, {
    Object? extra,
  }) {
    if (!_listening) {
      _listening = true;
      appRouter.routerDelegate.addListener(_onRouteChanged);
    }
    if (isDuplicate(location, currentPath: _currentPath())) {
      return Future<T?>.value();
    }
    _inFlight = _path(location);
    return context.push<T>(location, extra: extra);
  }
}
