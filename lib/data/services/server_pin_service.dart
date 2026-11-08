import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:server_core/server_core.dart';

/// Where to reach a user's PIN on the server: the address and the token of the
/// account, which is not always the one signed in, since the PIN is asked for
/// before a saved account is switched to.
class ServerPinAccount {
  const ServerPinAccount({required this.baseUrl, required this.accessToken});

  final String baseUrl;
  final String accessToken;
}

/// Whether the server holds a PIN for the account.
enum ServerPinAvailability {
  /// The plugin keeps a PIN for this account.
  enabled,

  /// The plugin is there and keeps none.
  disabled,

  /// Not asked or not answered: no plugin, an older plugin, a token the server
  /// no longer accepts, or a server that could not be reached.
  unavailable,
}

/// What the server made of a PIN it was asked to check.
sealed class ServerPinVerdict {
  const ServerPinVerdict();
}

class ServerPinValid extends ServerPinVerdict {
  const ServerPinValid();
}

class ServerPinWrong extends ServerPinVerdict {
  const ServerPinWrong();
}

/// Too many wrong guesses. Nothing was checked.
class ServerPinLocked extends ServerPinVerdict {
  const ServerPinLocked(this.retryAfter);

  final Duration retryAfter;
}

/// The server has no PIN for the account.
class ServerPinNone extends ServerPinVerdict {
  const ServerPinNone();
}

/// The server could not say, so the PIN stored on the device decides.
class ServerPinUnavailable extends ServerPinVerdict {
  const ServerPinUnavailable();
}

/// The PIN a server keeps for an account, through the Moonfin plugin. The
/// plugin holds a salted slow hash and counts wrong guesses itself, so a PIN
/// set on one device holds on every other and clearing app data does not hand
/// back free guesses. Nothing here ever gets the hash back.
class ServerPinService {
  ServerPinService({required this.deviceInfo, @visibleForTesting Dio? dio})
    : _dio = dio ?? _newDio();

  final DeviceInfo deviceInfo;
  final Dio _dio;

  static Dio _newDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        // The answers are read by status, not thrown.
        validateStatus: (_) => true,
      ),
    );
    configureServerDio(dio);
    dio.interceptors.add(redirectInterceptor(dio));
    return dio;
  }

  Options _options(ServerPinAccount account) => Options(
    headers: {
      'Authorization': buildServerAuthorizationHeader(
        scheme: 'MediaBrowser',
        deviceInfo: deviceInfo,
        accessToken: account.accessToken,
      ),
    },
  );

  String _url(ServerPinAccount account, String path) =>
      '${account.baseUrl}/Moonfin/$path';

  /// Whether the server keeps a PIN for the account.
  Future<ServerPinAvailability> status(ServerPinAccount account) async {
    try {
      final response = await _dio.get<dynamic>(
        _url(account, 'Pin'),
        options: _options(account),
      );
      final data = response.data;
      if (response.statusCode == 200 &&
          data is Map &&
          data['enabled'] is bool) {
        return data['enabled'] as bool
            ? ServerPinAvailability.enabled
            : ServerPinAvailability.disabled;
      }
    } on DioException {
      // Fall through to unavailable.
    }
    return ServerPinAvailability.unavailable;
  }

  /// Asks the server whether [pin] is the account's PIN.
  Future<ServerPinVerdict> verify(ServerPinAccount account, String pin) async {
    try {
      final response = await _dio.post<dynamic>(
        _url(account, 'Pin/Verify'),
        data: {'pin': pin},
        options: _options(account),
      );
      return _verdict(response);
    } on DioException {
      return const ServerPinUnavailable();
    }
  }

  /// Sets the account's PIN. A PIN that already exists has to be named in
  /// [currentPin], and a wrong one counts as a guess.
  Future<ServerPinVerdict> setPin(
    ServerPinAccount account,
    String pin, {
    String? currentPin,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        _url(account, 'Pin'),
        data: {'pin': pin, 'currentPin': ?currentPin},
        options: _options(account),
      );
      return _writeVerdict(response);
    } on DioException {
      return const ServerPinUnavailable();
    }
  }

  /// Removes the account's PIN, which takes the current one.
  Future<ServerPinVerdict> removePin(
    ServerPinAccount account, {
    String? currentPin,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        _url(account, 'Pin'),
        data: {'currentPin': ?currentPin},
        options: _options(account),
      );
      return _writeVerdict(response);
    } on DioException {
      return const ServerPinUnavailable();
    }
  }

  /// Removes another user's PIN, or the account's own, without the current one.
  /// The server allows it to administrators only.
  Future<ServerPinVerdict> removePinFor(
    ServerPinAccount account,
    String userId,
  ) async {
    try {
      final response = await _dio.delete<dynamic>(
        _url(account, 'Users/$userId/Pin'),
        options: _options(account),
      );
      return response.statusCode == 200
          ? const ServerPinValid()
          : const ServerPinUnavailable();
    } on DioException {
      return const ServerPinUnavailable();
    }
  }

  ServerPinVerdict _verdict(Response<dynamic> response) {
    final data = response.data;
    switch (response.statusCode) {
      case 200:
        if (data is Map && data['valid'] is bool) {
          return data['valid'] as bool
              ? const ServerPinValid()
              : const ServerPinWrong();
        }
        return const ServerPinUnavailable();
      case 404:
        // Only the plugin says this. A server without it, or a proxy, answers
        // 404 with something else.
        return _errorIs(data, 'No PIN is set')
            ? const ServerPinNone()
            : const ServerPinUnavailable();
      case 429:
        return _locked(response);
      default:
        return const ServerPinUnavailable();
    }
  }

  ServerPinVerdict _writeVerdict(Response<dynamic> response) {
    switch (response.statusCode) {
      case 200:
        return const ServerPinValid();
      case 403:
        return _errorIs(response.data, 'The current PIN is wrong')
            ? const ServerPinWrong()
            : const ServerPinUnavailable();
      case 429:
        return _locked(response);
      default:
        return const ServerPinUnavailable();
    }
  }

  ServerPinVerdict _locked(Response<dynamic> response) {
    final data = response.data;
    final seconds = data is Map && data['retryAfterSeconds'] is int
        ? data['retryAfterSeconds'] as int
        : int.tryParse(response.headers.value('retry-after') ?? '') ?? 30;
    return ServerPinLocked(Duration(seconds: seconds));
  }

  static bool _errorIs(dynamic data, String message) =>
      data is Map && data['error'] == message;
}
