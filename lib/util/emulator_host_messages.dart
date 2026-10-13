import 'emulator_host_messages_io.dart'
    if (dart.library.js_interop) 'emulator_host_messages_web.dart'
    as impl;

/// Delivers messages the EmulatorJS player shell posts to `window.parent`.
///
/// On Android/iOS/desktop these arrive through the `flutter_inappwebview`
/// JavaScript handler registered in `game_emulator_screen.dart`, so this is a
/// no-op there. On Flutter web, `flutter_inappwebview_web` never implements
/// that handler inside an iframe, so nothing reaches Dart unless something
/// listens for the `postMessage` the player shell falls back to -- this does.
abstract class EmulatorHostMessages {
  /// Subscribes to messages posted to `window.parent`. Returns a dispose
  /// callback that cancels the subscription (or does nothing off the web).
  static void Function() subscribe({
    required String allowedOrigin,
    required void Function(Object? message) onMessage,
  }) => impl.subscribe(allowedOrigin: allowedOrigin, onMessage: onMessage);

  /// Whether player functions can be invoked directly, bypassing
  /// InAppWebViewController. True only on web.
  static bool get supportsDirectCalls => impl.supportsDirectCalls;

  /// Invokes `window.<function>(...args)` on the player page. Returns the
  /// dartified result, or null if the page or function is unavailable.
  static Object? callPlayer({
    required String playerUrl,
    required String function,
    List<Object?> args = const [],
  }) => impl.callPlayer(playerUrl: playerUrl, function: function, args: args);

  /// Reads `window.<name>` from the player page, for the version gates that
  /// guard a call rather than being one. Null off the web or if unavailable.
  static Object? readPlayer({
    required String playerUrl,
    required String name,
  }) => impl.readPlayer(playerUrl: playerUrl, name: name);
}
