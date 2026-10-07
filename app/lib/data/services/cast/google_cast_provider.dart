import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:playback_core/playback_core.dart';
import 'package:playback_emby/playback_emby.dart';
import 'package:playback_jellyfin/playback_jellyfin.dart';
import 'package:server_core/server_core.dart';

import '../../../util/platform_detection.dart';
import '../../models/aggregated_item.dart';
import '../media_server_client_factory.dart';
import 'cast_provider.dart';
import 'cast_target.dart';
import 'cast_transport_controls.dart';
import 'native_cast_channel.dart';
import 'receiver_device_profiles.dart';

class GoogleCastProvider implements CastProvider, CastTransportControls {
  final NativeCastChannel _native;
  final MediaServerClientFactory _clientFactory;

  static final Logger _logger = Logger();

  const GoogleCastProvider(this._native, this._clientFactory);

  MediaStreamResolver _resolverForClient(MediaServerClient client) {
    return switch (client.serverType) {
      ServerType.jellyfin => JellyfinPlugin(client).createStreamResolver(),
      ServerType.emby => EmbyPlugin(client).createStreamResolver(),
    };
  }

  Future<StreamResolutionResult> _resolveForItem(
    MediaServerClient client,
    AggregatedItem item, {
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) {
    // An explicit track pick forces a transcode so the server applies it,
    // since the receiver has no track selection of its own.
    final hasExplicitIndices =
        audioStreamIndex != null || subtitleStreamIndex != null;
    return _resolverForClient(client).resolve(
      item,
      deviceProfile: chromecastDeviceProfile(),
      mediaSourceId: mediaSourceId,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      enableDirectPlay: !hasExplicitIndices,
      enableDirectStream: !hasExplicitIndices,
    );
  }

  // The receiver picks its player from the MIME type, since the stream URL
  // carries no file extension to go on.
  String _contentTypeFor(StreamResolutionResult resolution) {
    if (resolution.playMethod == StreamPlayMethod.transcode ||
        resolution.streamUrl.contains('.m3u8')) {
      return 'application/x-mpegURL';
    }
    final container =
        resolution.container?.split(',').first.trim().toLowerCase();
    return container == 'webm' ? 'video/webm' : 'video/mp4';
  }

  String? _posterUrlFor(MediaServerClient client, AggregatedItem item) {
    final tag = item.primaryImageTag;
    if (tag == null || tag.isEmpty) return null;
    return client.imageApi.getPrimaryImageUrl(item.id, maxWidth: 800, tag: tag);
  }

  @override
  Set<CastTargetKind> get supportedKinds => {CastTargetKind.googleCast};

  @override
  Set<CastTargetKind> get controllableKinds => {CastTargetKind.googleCast};

  @override
  Future<List<CastTarget>> discoverTargets(AggregatedItem item) async {
    if (!PlatformDetection.isAndroid && !PlatformDetection.isIOS) {
      return const [];
    }

    try {
      return await _native.discoverGoogleCastTargets();
    } catch (e, st) {
      _logger.w('Google Cast discovery failed', error: e, stackTrace: st);
      return const [];
    }
  }

  @override
  Future<void> playToTarget(
    CastTarget target, {
    required AggregatedItem item,
    List<AggregatedItem>? queueItems,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    final client =
        _clientFactory.getClientIfExists(item.serverId) ?? GetIt.instance<MediaServerClient>();
    final resolution = await _resolveForItem(
      client,
      item,
      mediaSourceId: mediaSourceId,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    );
    final streamUrl = resolution.streamUrl;
    final effectiveQueueItems =
        (queueItems == null || queueItems.isEmpty)
            ? <AggregatedItem>[item]
            : queueItems;
    final queuePayload = <Map<String, dynamic>>[];
    for (final entry in effectiveQueueItems) {
      final entryResolution =
          entry.id == item.id ? resolution : await _resolveForItem(client, entry);
      final posterUrl = _posterUrlFor(client, entry);
      queuePayload.add(
        <String, dynamic>{
          'streamUrl': entryResolution.streamUrl,
          'contentType': _contentTypeFor(entryResolution),
          'title': entry.name,
          if (entry.overview?.isNotEmpty == true) 'subtitle': entry.overview,
          'posterUrl': ?posterUrl,
        },
      );
    }

    await _native.startGoogleCastSession(
      targetId: target.id,
      streamUrl: streamUrl,
      contentType: _contentTypeFor(resolution),
      title: item.name,
      subtitle: item.overview,
      posterUrl: _posterUrlFor(client, item),
      queueItems: queuePayload.length > 1 ? queuePayload : null,
      startPositionTicks: startPositionTicks,
    );
  }

  @override
  Future<void> pause(CastTargetKind kind) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    await _native.pauseGoogleCast();
  }

  @override
  Future<void> play(CastTargetKind kind) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    await _native.playGoogleCast();
  }

  @override
  Future<void> seek(CastTargetKind kind, {required int positionTicks}) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    await _native.seekGoogleCast(positionTicks: positionTicks);
  }

  @override
  Future<void> stop(CastTargetKind kind) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    await _native.stopGoogleCastSession();
  }

  @override
  Future<double?> getVolume(CastTargetKind kind) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    return _native.getGoogleCastVolume();
  }

  @override
  Future<void> setVolume(CastTargetKind kind, {required double volume}) async {
    if (kind != CastTargetKind.googleCast) {
      throw UnsupportedError('Unsupported cast kind for GoogleCastProvider.');
    }
    await _native.setGoogleCastVolume(volume: volume);
  }
}
