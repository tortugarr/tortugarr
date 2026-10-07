library;

enum ServerLogLevel { debug, info, warning, error }

typedef ServerLogCallback =
    void Function(
      String category,
      ServerLogLevel level,
      String message, {
      Object? error,
    });

class ServerLog {
  ServerLog._();

  static ServerLogCallback? sink;

  static void emit(
    String category,
    ServerLogLevel level,
    String message, {
    Object? error,
  }) {
    final target = sink;
    if (target == null) return;
    target(category, level, message, error: error);
  }

  static void network(
    String message, {
    ServerLogLevel level = ServerLogLevel.debug,
    Object? error,
  }) => emit('network', level, message, error: error);
}
