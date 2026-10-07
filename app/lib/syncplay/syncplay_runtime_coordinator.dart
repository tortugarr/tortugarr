import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_core/server_core.dart';

import '../data/services/socket_handler.dart';
import 'syncplay_manager.dart';

class SyncPlayRuntimeCoordinator {
  final SyncPlayManager _manager;
  final SocketHandler _socketHandler;

  StreamSubscription<ServerWebSocketMessage>? _wsSub;
  ProviderSubscription<MediaServerClient?>? _serverSub;

  SyncPlayRuntimeCoordinator(this._manager, this._socketHandler);

  void start(Ref ref, ProviderListenable<MediaServerClient?> serverProvider) {
    _wsSub = _socketHandler.events.listen(_route);
    _serverSub = ref.listen<MediaServerClient?>(
      serverProvider,
      (prev, next) => _onServerChanged(next),
      fireImmediately: true,
    );
  }

  void stop() {
    _wsSub?.cancel();
    _wsSub = null;
    _serverSub?.close();
    _serverSub = null;
  }

  void appDidEnterBackground() => _manager.appDidEnterBackground();
  void appDidBecomeActive() => _manager.appDidBecomeActive();

  void _onServerChanged(MediaServerClient? client) {
    _manager.setActiveClient(client);
    if (client != null && _manager.state.enabled) {
      _manager.handleRealtimeConnected();
    }
  }

  void _route(ServerWebSocketMessage message) {
    switch (message) {
      case SyncPlayCommandMessage(:final command):
        _manager.handlePlaybackCommand(command);
      case SyncPlayGroupUpdateMessage(:final update):
        _manager.handleGroupUpdate(update);
      case ServerRestartingMessage():
        _manager.handleRealtimeSessionInterrupted('Server is restarting');
      case ServerShuttingDownMessage():
        _manager.handleRealtimeSessionInterrupted('Server is shutting down');
      default:
        break;
    }
  }
}
