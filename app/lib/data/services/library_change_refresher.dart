import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:server_core/server_core.dart'
    show LibraryChangedMessage, ServerWebSocketMessage;

import '../../ui/navigation/home_refresh_bus.dart';
import 'socket_handler.dart';

/// Refreshes the home screen when Jellyfin reports titles added or removed,
/// so a finished download (or a deletion) shows up without restarting the
/// app. Scans arrive as bursts of messages, so refreshes are debounced.
class LibraryChangeRefresher {
  static const Duration debounce = Duration(seconds: 8);

  StreamSubscription<ServerWebSocketMessage>? _sub;
  Timer? _timer;

  void start() {
    _sub ??= GetIt.instance<SocketHandler>().events.listen((event) {
      if (event is! LibraryChangedMessage) return;
      // Metadata updates fire constantly during scans; only new or gone
      // titles change what the home rows show.
      if (event.itemsAdded.isEmpty && event.itemsRemoved.isEmpty) return;
      _timer?.cancel();
      _timer = Timer(debounce, homeRefreshBus.requestNowOrAfterNavigation);
    });
  }

  void stop() {
    _timer?.cancel();
    _sub?.cancel();
    _sub = null;
  }
}
