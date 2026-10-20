import 'package:flutter/foundation.dart';
import 'package:server_core/server_core.dart';

import '../../../util/build_flavor.dart';
import '../download/bazarr_client.dart' show BazarrSubtitleService;
import '../download/download_now_service.dart' show DownloadNowConfig;
import 'tortugarr_plugin_client.dart';

/// Which download features this app may show, whatever the build.
///
/// The private build talks to the *arr stack directly with compiled-in
/// addresses ([DownloadNowConfig]). The public build has none and asks the
/// server's Tortugarr plugin instead: [refresh] after each login, and every
/// feature stays off until the plugin says otherwise.
class DownloadFeatures {
  DownloadFeatures._();

  /// The plugin's last answer (public build only).
  static final ValueNotifier<TortugarrCapabilities> capabilities =
      ValueNotifier(TortugarrCapabilities.none);

  /// True when downloads go through the plugin rather than direct *arr calls.
  static bool get viaPlugin => kTortugarrPublic;

  static bool get _direct => !kTortugarrPublic && DownloadNowConfig.isAvailable;

  static bool get downloadNow => _direct || (viaPlugin && capabilities.value.downloadNow);

  /// "Find subtitles" (Bazarr).
  static bool get subtitles =>
      (!kTortugarrPublic && BazarrSubtitleService.isConfigured) ||
      (viaPlugin && capabilities.value.subtitles);

  /// The missing-episodes view and its season switch (Sonarr).
  static bool get missingEpisodes => _direct || (viaPlugin && capabilities.value.missingEpisodes);

  /// The free-space check before a download and the "free up space" dialog.
  static bool get freeSpace => _direct || (viaPlugin && capabilities.value.freeSpace);

  /// Searching and downloading into the adult library.
  static bool get adultDownloads => _direct || (viaPlugin && capabilities.value.adult);

  /// Deleting a title through Radarr/Sonarr (files, monitoring, Seerr).
  static bool get deleteTitles => _direct || (viaPlugin && capabilities.value.deleteTitles);

  /// Called after a login (public build): ask the plugin what is on. A
  /// server without the plugin leaves everything off.
  static Future<void> refresh(MediaServerClient client) async {
    if (!viaPlugin) return;
    capabilities.value = await TortugarrPluginClient(client: client).capabilities();
  }

  /// Logout or server switch: nothing is allowed until the next answer.
  static void clear() => capabilities.value = TortugarrCapabilities.none;
}
