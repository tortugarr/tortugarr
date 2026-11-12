import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../preference/user_preferences.dart';
import '../../../ui/navigation/destinations.dart';

/// SmartTube (ad-free YouTube client for Android TV), opened as its own app:
/// it keeps its own settings, login and updates. Tortugarr never opens the
/// YouTube app; without SmartTube, trailers play in Tortugarr's own player.
class SmartTube {
  SmartTube._();

  static const _channel = MethodChannel('tortugarr/external_apps');

  /// SmartTube's package names, beta first (the owner's TV, 2026-11-12).
  static const packages = [
    'org.smarttube.beta',
    'org.smarttube.stable',
    'com.liskovsoft.smarttubetv.beta',
    'com.liskovsoft.smarttubetv',
  ];

  static String? _package;
  static Future<String?>? _lookup;

  /// The installed SmartTube package, or null. Looked up once per app start.
  static Future<String?> installedPackage() {
    if (!Platform.isAndroid) return Future.value(null);
    return _lookup ??= () async {
      try {
        _package = await _channel.invokeMethod<String>('installedPackage', {'packages': packages});
      } on PlatformException {
        _package = null;
      } on MissingPluginException {
        _package = null;
      }
      return _package;
    }();
  }

  static Future<bool> open() async {
    final pkg = await installedPackage();
    if (pkg == null) return false;
    return await _channel.invokeMethod<bool>('launch', {'package': pkg}) ?? false;
  }

  static Future<bool> _view(String url) async {
    final pkg = await installedPackage();
    if (pkg == null) return false;
    return await _channel.invokeMethod<bool>('view', {'package': pkg, 'url': url}) ?? false;
  }

  /// SmartTube's search results for [query].
  static Future<bool> search(String query) =>
      _view(searchUri(query));

  @visibleForTesting
  static String searchUri(String query) =>
      'youtube://search?query=${Uri.encodeComponent(query.trim())}';

  /// A YouTube link or video id as SmartTube understands it, or null when
  /// [url] is not a YouTube link.
  @visibleForTesting
  static String? watchUri({String? videoId, String? url}) {
    if (videoId != null && videoId.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$videoId';
    }
    if (url == null) return null;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.endsWith('youtube.com') || host == 'youtu.be' ? url : null;
  }

  /// Plays a trailer: in SmartTube when it is installed and the setting is
  /// on and the trailer is on YouTube, otherwise in Tortugarr's own player.
  static Future<void> playTrailer(BuildContext context, {String? videoId, String? url}) async {
    final prefs = GetIt.instance.isRegistered<UserPreferences>()
        ? GetIt.instance<UserPreferences>()
        : null;
    final wanted = prefs?.get(UserPreferences.tgTrailersInSmartTube) ?? true;
    final link = watchUri(videoId: videoId, url: url);
    if (wanted && link != null && await _view(link)) return;
    if (!context.mounted) return;
    await context.push(Destinations.trailer(videoId: videoId, url: url));
  }
}
