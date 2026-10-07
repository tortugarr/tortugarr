import 'package:dio/dio.dart';

import '../../data/services/emby_connect_service.dart';
import '../models/user.dart';
import '../store/authentication_store.dart';
import 'server_repository.dart';
import 'session_repository.dart';

enum EmbyConnectFailureReason {
  invalidCredentials,
  network,
  invalidAuthResponse,
  noLinkedServers,
  noReachableAddress,
  exchangeUnsupported,
  invalidExchangeResponse,
  unableToConnectServer,
  unknown,
}

class EmbyConnectFailure {
  final EmbyConnectFailureReason reason;
  final int? statusCode;
  final String? detail;

  const EmbyConnectFailure({
    required this.reason,
    this.statusCode,
    this.detail,
  });
}

class EmbyConnectAuthSession {
  final String connectUserId;
  final List<EmbyConnectServer> servers;

  const EmbyConnectAuthSession({
    required this.connectUserId,
    required this.servers,
  });
}

class EmbyConnectAuthResult {
  final EmbyConnectAuthSession? session;
  final EmbyConnectFailure? failure;

  const EmbyConnectAuthResult._({this.session, this.failure});

  const EmbyConnectAuthResult.success(EmbyConnectAuthSession session)
    : this._(session: session);

  const EmbyConnectAuthResult.failure(EmbyConnectFailure failure)
    : this._(failure: failure);

  bool get isSuccess => session != null;
}

class EmbyConnectConnectionSuccess {
  final String serverId;
  final bool switched;

  const EmbyConnectConnectionSuccess({
    required this.serverId,
    required this.switched,
  });
}

class EmbyConnectConnectionResult {
  final EmbyConnectConnectionSuccess? success;
  final EmbyConnectFailure? failure;

  const EmbyConnectConnectionResult._({this.success, this.failure});

  const EmbyConnectConnectionResult.success(EmbyConnectConnectionSuccess success)
    : this._(success: success);

  const EmbyConnectConnectionResult.failure(EmbyConnectFailure failure)
    : this._(failure: failure);

  bool get isSuccess => success != null;
}

class EmbyConnectRepository {
  final EmbyConnectService _connectService;
  final ServerRepository _serverRepository;
  final AuthenticationStore _authStore;
  final SessionRepository _sessionRepository;

  EmbyConnectRepository(
    this._connectService,
    this._serverRepository,
    this._authStore,
    this._sessionRepository,
  );

  Future<EmbyConnectAuthResult> authenticateAndLoadServers({
    required String username,
    required String password,
  }) async {
    try {
      final auth = await _connectService.authenticate(
        username: username,
        password: password,
      );

      if (auth.accessToken.isEmpty || auth.user.id.isEmpty) {
        return const EmbyConnectAuthResult.failure(
          EmbyConnectFailure(reason: EmbyConnectFailureReason.invalidAuthResponse),
        );
      }

      final servers = await _connectService.getServers(
        connectUserId: auth.user.id,
        connectAccessToken: auth.accessToken,
      );

      if (servers.isEmpty) {
        return const EmbyConnectAuthResult.failure(
          EmbyConnectFailure(reason: EmbyConnectFailureReason.noLinkedServers),
        );
      }

      return EmbyConnectAuthResult.success(
        EmbyConnectAuthSession(connectUserId: auth.user.id, servers: servers),
      );
    } on DioException catch (e) {
      return EmbyConnectAuthResult.failure(_mapAuthDioError(e));
    } catch (e) {
      return EmbyConnectAuthResult.failure(
        EmbyConnectFailure(
          reason: EmbyConnectFailureReason.unknown,
          detail: e.toString(),
        ),
      );
    }
  }

  Future<EmbyConnectConnectionResult> connectToServer({
    required EmbyConnectAuthSession session,
    required EmbyConnectServer server,
    required String fallbackUsername,
  }) async {
    final addresses = server.candidateAddresses;
    if (addresses.isEmpty) {
      return const EmbyConnectConnectionResult.failure(
        EmbyConnectFailure(reason: EmbyConnectFailureReason.noReachableAddress),
      );
    }

    EmbyConnectFailure? lastFailure;

    for (final address in addresses) {
      try {
        final exchange = await _connectService.exchange(
          serverAddress: address,
          connectUserId: session.connectUserId,
          accessKey: server.accessKey,
        );

        if (exchange.localUserId.isEmpty || exchange.accessToken.isEmpty) {
          lastFailure = const EmbyConnectFailure(
            reason: EmbyConnectFailureReason.invalidExchangeResponse,
          );
          continue;
        }

        final connectedServer = await _serverRepository.addServer(
          exchange.resolvedBaseUrl,
        );
        if (connectedServer == null) {
          lastFailure = EmbyConnectFailure(
            reason: EmbyConnectFailureReason.unableToConnectServer,
            detail: exchange.resolvedBaseUrl,
          );
          continue;
        }

        await _authStore.putUser(
          PrivateUser(
            id: exchange.localUserId,
            name: fallbackUsername,
            serverId: connectedServer.id,
            accessToken: exchange.accessToken,
            lastUsed: DateTime.now(),
          ),
        );

        final switched = await _sessionRepository.switchCurrentSession(
          serverId: connectedServer.id,
          userId: exchange.localUserId,
          username: fallbackUsername,
        );

        return EmbyConnectConnectionResult.success(
          EmbyConnectConnectionSuccess(
            serverId: connectedServer.id,
            switched: switched,
          ),
        );
      } on DioException catch (e) {
        lastFailure = _mapExchangeDioError(e);
      } catch (e) {
        lastFailure = EmbyConnectFailure(
          reason: EmbyConnectFailureReason.unknown,
          detail: e.toString(),
        );
      }
    }

    return EmbyConnectConnectionResult.failure(
      lastFailure ??
          const EmbyConnectFailure(reason: EmbyConnectFailureReason.unknown),
    );
  }

  EmbyConnectFailure _mapAuthDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 400 || statusCode == 401) {
      return EmbyConnectFailure(
        reason: EmbyConnectFailureReason.invalidCredentials,
        statusCode: statusCode,
      );
    }

    return EmbyConnectFailure(
      reason: EmbyConnectFailureReason.network,
      statusCode: statusCode,
      detail: e.message,
    );
  }

  EmbyConnectFailure _mapExchangeDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 404) {
      return EmbyConnectFailure(
        reason: EmbyConnectFailureReason.exchangeUnsupported,
        statusCode: statusCode,
      );
    }

    return EmbyConnectFailure(
      reason: EmbyConnectFailureReason.network,
      statusCode: statusCode,
      detail: e.message,
    );
  }
}