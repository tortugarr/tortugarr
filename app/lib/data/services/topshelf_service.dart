import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../util/platform_detection.dart';
import '../models/aggregated_item.dart';
import '../models/home_row.dart';

/// Bridges the Apple TV Top Shelf extension: writes a cached snapshot of the
/// "Latest" home content into the shared App Group container (consumed by the
/// MoonfinTopShelf extension) and routes the `moonfin://` deep links the shelf
/// emits back into the app.
class TopShelfService {
  static const _channel = MethodChannel('moonfin/appletv_topshelf');
  static const _maxItems = 15;
  static const _debounceDelay = Duration(seconds: 2);

  Timer? _debounce;

  /// Schedules a Top Shelf cache refresh, coalescing the rapid successive
  /// calls a single home load produces into one write.
  void update(List<HomeRow> rows) {
    if (!PlatformDetection.isAppleTV) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(_writeCache(rows)));
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }

  Future<void> _writeCache(List<HomeRow> rows) async {
    try {
      final imageApi = GetIt.instance<MediaServerClient>().imageApi;
      final items = <Map<String, dynamic>>[];
      for (final row in rows.where((r) => r.rowType == HomeRowType.latestMedia)) {
        for (final item in row.items) {
          final payload = _itemPayload(item, imageApi);
          if (payload != null) items.add(payload);
          if (items.length >= _maxItems) break;
        }
        if (items.length >= _maxItems) break;
      }

      if (items.isEmpty) {
        await _channel.invokeMethod('clearCache');
        return;
      }

      await _channel.invokeMethod('writeCache', {
        'sections': [
          {
            'id': 'latest',
            'title': 'Latest',
            'items': items,
            'landscape': true,
          },
        ],
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _itemPayload(AggregatedItem item, ImageApi imageApi) {
    final id = item.id;
    if (id.isEmpty) return null;
    final serverId = item.serverId;
    final query = serverId.isEmpty
        ? 'id=$id'
        : 'id=$id&serverId=${Uri.encodeQueryComponent(serverId)}';

    String? image;
    final thumbTag = item.thumbImageTag;
    final primaryTag = item.primaryImageTag;
    if (thumbTag != null && thumbTag.isNotEmpty) {
      image = imageApi.getThumbImageUrl(id, maxWidth: 960, tag: thumbTag);
    } else if (primaryTag != null && primaryTag.isNotEmpty) {
      image = imageApi.getPrimaryImageUrl(id, maxHeight: 480, tag: primaryTag);
    }

    return {
      'id': id,
      'title': item.name,
      'imageURL': ?image,
      'contentImageURL': ?image,
      'displayURL': 'moonfin://item?$query',
      'playURL': 'moonfin://play?$query',
    };
  }

  /// Starts listening for Top Shelf deep links (and drains any link the app
  /// was cold-launched with), forwarding resolved route paths to [onRoute].
  void startDeepLinkListener(void Function(String route) onRoute) {
    if (!PlatformDetection.isAppleTV) return;

    void dispatch(String? url) {
      if (url == null) return;
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final route = routeForDeepLink(uri);
      if (route != null) onRoute(route);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        dispatch(call.arguments as String?);
      }
      return null;
    });

    () async {
      try {
        dispatch(await _channel.invokeMethod<String>('getInitialDeepLink'));
      } catch (_) {}
    }();
  }

  /// Resolves a `moonfin://` deep link into an in-app route path, or null if
  /// the link is not a recognized Top Shelf action.
  static String? routeForDeepLink(Uri uri) {
    if (uri.scheme != 'moonfin') return null;
    final id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    final serverId = uri.queryParameters['serverId'];
    final params = <String, String>{
      if (serverId != null && serverId.isNotEmpty) 'serverId': serverId,
      if (uri.host == 'play') 'autoPlay': 'true',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return query.isEmpty ? '/item/$id' : '/item/$id?$query';
  }
}
