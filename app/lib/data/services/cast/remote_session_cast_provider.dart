import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart';

import '../../models/aggregated_item.dart';
import '../media_server_client_factory.dart';
import 'cast_provider.dart';
import 'cast_service.dart';
import 'cast_target.dart';
import 'cast_transport_controls.dart';

class RemoteSessionCastProvider implements CastProvider, CastTransportControls {
  final MediaServerClientFactory _clientFactory;

  String? _activeSessionId;
  String? _activeServerId;

  // A Notflix session reports no events back to us, so its progress is read
  // from the server's session list. Two seconds keeps the bar moving without
  // hammering Jellyfin; a few empty polls in a row mean the receiver stopped.
  static const _pollInterval = Duration(seconds: 2);
  static const _missingPollsBeforeEnd = 3;
  Timer? _pollTimer;
  bool _polling = false;
  int _missingPolls = 0;
  double? _lastVolume;

  CastService? get _castService =>
      GetIt.instance.isRegistered<CastService>()
          ? GetIt.instance<CastService>()
          : null;

  void _startPolling() {
    _pollTimer?.cancel();
    _missingPolls = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    // First read right away so the bar does not sit at zero for a poll.
    Future<void>.delayed(const Duration(milliseconds: 700), _poll);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _polling = false;
    _missingPolls = 0;
    _lastVolume = null;
  }

  Future<void> _poll() async {
    final sessionId = _activeSessionId;
    if (sessionId == null || _polling) return;
    _polling = true;
    try {
      final sessions = await _activeClient.sessionApi.getSessions();
      Map<String, dynamic>? session;
      for (final s in sessions) {
        if (s['Id']?.toString() == sessionId) {
          session = s;
          break;
        }
      }
      final nowPlaying = session?['NowPlayingItem'] as Map<String, dynamic>?;
      if (session == null || nowPlaying == null) {
        _missingPolls++;
        if (_missingPolls >= _missingPollsBeforeEnd) {
          _stopPolling();
          _activeSessionId = null;
          _activeServerId = null;
          _castService?.remoteSessionEnded(CastTargetKind.jellyfinSession);
        }
        return;
      }
      _missingPolls = 0;
      final playState = session['PlayState'] as Map<String, dynamic>?;
      final isPaused = playState?['IsPaused'] as bool? ?? false;
      final positionTicks = (playState?['PositionTicks'] as num?)?.toInt();
      final volumeLevel = (playState?['VolumeLevel'] as num?)?.toDouble();
      _lastVolume = volumeLevel == null ? null : volumeLevel / 100.0;
      _castService?.updateRemoteState(
        kind: CastTargetKind.jellyfinSession,
        state: isPaused ? 'paused' : 'playing',
        positionTicks: positionTicks,
        volume: _lastVolume,
      );
    } catch (_) {
      // A failed poll is not a stopped receiver; the next tick retries.
    } finally {
      _polling = false;
    }
  }

  /// Switches tracks on the receiver in place. The TV app handles
  /// SetAudioStreamIndex / SetSubtitleStreamIndex itself, so playback keeps
  /// its position instead of restarting from a stale one.
  Future<void> selectTrack({
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final api = _activeClient.sessionApi;
    if (audioStreamIndex != null) {
      await api.sendGeneralCommand(
        sessionId,
        'SetAudioStreamIndex',
        arguments: {'Index': '$audioStreamIndex'},
      );
    }
    if (subtitleStreamIndex != null) {
      await api.sendGeneralCommand(
        sessionId,
        'SetSubtitleStreamIndex',
        arguments: {'Index': '$subtitleStreamIndex'},
      );
    }
  }

  RemoteSessionCastProvider(this._clientFactory);

  @override
  Set<CastTargetKind> get supportedKinds => {CastTargetKind.jellyfinSession};

  @override
  Set<CastTargetKind> get controllableKinds => {CastTargetKind.jellyfinSession};

  MediaServerClient _clientFor(AggregatedItem item) {
    return _clientFactory.getClientIfExists(item.serverId) ??
        GetIt.instance<MediaServerClient>();
  }

  MediaServerClient get _activeClient =>
      (_activeServerId != null
          ? _clientFactory.getClientIfExists(_activeServerId!)
          : null) ??
      GetIt.instance<MediaServerClient>();

  @override
  Future<List<CastTarget>> discoverTargets(AggregatedItem item) async {
    final client = _clientFor(item);
    final sessions = await client.sessionApi.getSessions();
    final selfDeviceId = client.deviceInfo.id;

    final targets = <CastTarget>[];
    for (final session in sessions) {
      final sessionId = session['Id']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        continue;
      }
      final supports = session['SupportsMediaControl'];
      if (supports is bool && !supports) {
        continue;
      }
      final deviceId = session['DeviceId']?.toString();
      if (deviceId != null && deviceId == selfDeviceId) {
        continue;
      }

      final user = session['UserName'] as String?;
      final clientName = session['Client'] as String?;
      final deviceName = session['DeviceName'] as String?;
      final nowPlaying = session['NowPlayingItem'] as Map<String, dynamic>?;
      final subtitle = nowPlaying != null
          ? (nowPlaying['Name'] as String? ?? 'Now playing')
          : [
              if (clientName != null && clientName.isNotEmpty) clientName,
              if (deviceName != null && deviceName.isNotEmpty) deviceName,
            ].join(' • ');
      final title = user != null && user.isNotEmpty
          ? user
          : (deviceName?.isNotEmpty ?? false)
          ? deviceName!
          : 'Unknown device';

      targets.add(
        CastTarget(
          id: sessionId,
          kind: CastTargetKind.jellyfinSession,
          title: title,
          subtitle: subtitle,
        ),
      );
    }

    return targets;
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
    _activeSessionId = target.id;
    _activeServerId = item.serverId;
    final client = _clientFor(item);
    final itemIds = (queueItems == null || queueItems.isEmpty)
        ? <String>[item.id]
        : queueItems.map((entry) => entry.id).toList(growable: false);
    await client.sessionApi.sendPlayCommand(
      target.id,
      playCommand: 'PlayNow',
      itemIds: itemIds,
      startPositionTicks: startPositionTicks,
      mediaSourceId: mediaSourceId,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    );
    _startPolling();
  }

  // The TV reports its state to Jellyfin on its own schedule, so a poll can
  // lag a tap by several seconds. Show the expected state at once and poll
  // soon after to confirm; a refused command is corrected by that poll.
  void _assume({String? state, int? positionTicks}) {
    _castService?.updateRemoteState(
      kind: CastTargetKind.jellyfinSession,
      state: state,
      positionTicks: positionTicks,
    );
    Future<void>.delayed(const Duration(milliseconds: 900), _poll);
  }

  @override
  Future<void> play(CastTargetKind kind) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    await _activeClient.sessionApi.sendPlayStateCommand(sessionId, 'Unpause');
    _assume(state: 'playing');
  }

  @override
  Future<void> pause(CastTargetKind kind) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    await _activeClient.sessionApi.sendPlayStateCommand(sessionId, 'Pause');
    _assume(state: 'paused');
  }

  @override
  Future<void> seek(CastTargetKind kind, {required int positionTicks}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    await _activeClient.sessionApi.sendPlayStateCommand(
      sessionId,
      'Seek',
      seekPositionTicks: positionTicks,
    );
    _assume(positionTicks: positionTicks);
  }

  @override
  Future<void> stop(CastTargetKind kind) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    _stopPolling();
    await _activeClient.sessionApi.sendPlayStateCommand(sessionId, 'Stop');
    _activeSessionId = null;
    _activeServerId = null;
  }

  @override
  Future<double?> getVolume(CastTargetKind kind) async => _lastVolume;

  @override
  Future<void> setVolume(CastTargetKind kind, {required double volume}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final level = (volume.clamp(0.0, 1.0) * 100).round();
    _lastVolume = level / 100.0;
    await _activeClient.sessionApi.sendGeneralCommand(
      sessionId,
      'SetVolume',
      arguments: {'Volume': '$level'},
    );
  }
}
