import '../models/server_type.dart';

class FeatureDetector {
  final ServerType serverType;
  final String serverVersion;

  const FeatureDetector({
    required this.serverType,
    required this.serverVersion,
  });

  bool get supportsSyncPlay => serverType == ServerType.jellyfin;
  bool get supportsTrickplay => serverType == ServerType.jellyfin;
  bool get supportsLyrics => serverType == ServerType.jellyfin;
  bool get supportsMediaSegments => serverType == ServerType.jellyfin;

  /// Both servers can surface intro and credits segments for skip overlays,
  /// Jellyfin through the MediaSegments API and Emby through chapter markers.
  bool get supportsSkipSegments =>
      serverType == ServerType.jellyfin || serverType == ServerType.emby;

  bool get supportsQuickConnect => serverType == ServerType.jellyfin;
  bool get supportsClientLog => serverType == ServerType.jellyfin;

  bool get supportsBifTrickplay => serverType == ServerType.emby;
  bool get supportsJellyseerr => true;
}
