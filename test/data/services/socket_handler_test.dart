import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/socket_handler.dart';
import 'package:server_core/server_core.dart';

class _FakeClient implements MediaServerClient {
  _FakeClient({this.baseUrl = 'http://server'});

  @override
  final String baseUrl;

  @override
  ServerType get serverType => ServerType.jellyfin;

  @override
  String? get accessToken => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocket implements ServerWebSocketClient {
  final _messages = StreamController<ServerWebSocketMessage>.broadcast();
  final _connections = StreamController<void>.broadcast();

  int connectCalls = 0;
  int retryCalls = 0;
  bool disposed = false;

  @override
  Stream<ServerWebSocketMessage> get messages => _messages.stream;

  @override
  Stream<void> get connections => _connections.stream;

  @override
  Future<void> connect() async => connectCalls++;

  @override
  Future<void> disconnect() async {}

  @override
  void retryNow() => retryCalls++;

  @override
  void dispose() {
    disposed = true;
    _messages.close();
    _connections.close();
  }

  void announceConnected() => _connections.add(null);
}

void main() {
  late _FakeSocket socket;
  late SocketHandler handler;

  setUp(() {
    socket = _FakeSocket();
    handler = SocketHandler(clientFactory: (_) => socket);
  });

  test('connecting opens the socket', () {
    handler.connectTo(_FakeClient());
    expect(socket.connectCalls, 1);
  });

  test('every open reaches the listeners, not just the first', () async {
    var opens = 0;
    handler.connectTo(_FakeClient());
    handler.connections.listen((_) => opens++);

    socket.announceConnected();
    socket.announceConnected();
    await Future<void>.delayed(Duration.zero);

    expect(opens, 2);
  });

  test('an immediate retry reaches the socket', () {
    handler.connectTo(_FakeClient());
    handler.retryNow();
    expect(socket.retryCalls, 1);
  });

  test('a retry with no socket does nothing rather than throwing', () {
    expect(handler.retryNow, returnsNormally);
  });

  test('disconnecting drops the socket and stops forwarding', () async {
    var opens = 0;
    handler.connectTo(_FakeClient());
    handler.connections.listen((_) => opens++);
    handler.disconnect();

    expect(socket.disposed, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(opens, 0);
  });

  group('a server that accepts and never answers', () {
    late ServerSocket server;
    late List<Socket> accepted;

    setUp(() async {
      accepted = [];
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(accepted.add);
    });

    tearDown(() async {
      for (final socket in accepted) {
        socket.destroy();
      }
      await server.close();
    });

    JellyfinWebSocketClient buildClient() {
      final client = JellyfinWebSocketClient(
        _FakeClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        connectTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(client.dispose);
      return client;
    }

    test('a stalled attempt is given up on and another follows', () async {
      unawaited(buildClient().connect());
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(
        accepted.length,
        greaterThan(1),
        reason:
            'one attempt that never answered used to stop the client for '
            'the life of the process',
      );
    });

    test('an immediate retry lands once a stalled attempt gave up', () async {
      final client = buildClient();
      unawaited(client.connect());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final beforeRetry = accepted.length;

      client.retryNow();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        accepted.length,
        greaterThan(beforeRetry),
        reason: 'a stale channel left behind reads as a live connection',
      );
    });
  });
}
