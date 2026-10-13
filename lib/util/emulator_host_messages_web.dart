import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

void Function() subscribe({
  required String allowedOrigin,
  required void Function(Object? message) onMessage,
}) {
  final StreamSubscription<web.MessageEvent> sub = web.window.onMessage.listen((
    event,
  ) {
    // moonfin-bridge.js posts with target origin '*' (there is no other option
    // from inside a cross-origin iframe), so this listener -- unlike the
    // handler it complements on other platforms -- is reachable by any window
    // and MUST filter by origin itself, or any page could drive menu
    // navigation and gamepad input through _onPlayerMessage.
    if (event.origin != allowedOrigin) return;
    onMessage(event.data.dartify());
  });
  return () => unawaited(sub.cancel());
}

bool get supportsDirectCalls => true;

/// Finds the player frame by looking for the bridge function itself rather
/// than by matching URLs: flutter_inappwebview rewrites the iframe's src in
/// several ways (data: URLs for non-GET loads, normalisation relative to the
/// requested URL), and a mismatch there would silently disable every call.
/// Only the player shell defines these globals, and a cross-origin frame
/// throws on access and is skipped.
web.Window? _playerWindow(String function) {
  final iframes = web.document.querySelectorAll('iframe');
  for (var i = 0; i < iframes.length; i++) {
    final node = iframes.item(i);
    if (node == null || !node.isA<web.HTMLIFrameElement>()) continue;
    try {
      final win = (node as web.HTMLIFrameElement).contentWindow;
      if (win == null) continue;
      if (win.getProperty(function.toJS) != null) return win;
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// Calls `window.<function>(...args)` on the player page. The
/// InAppWebViewController route is unusable here -- flutter_inappwebview_web
/// never implements callAsyncJavaScript, and evaluateJavascript silently
/// no-ops through a null platform channel -- but the page is same-origin, so
/// a direct call works.
Object? callPlayer({
  required String playerUrl,
  required String function,
  List<Object?> args = const [],
}) {
  try {
    final win = _playerWindow(function);
    if (win == null) {
      web.console.warn('[moonfin] no EmulatorJS frame exposes $function'.toJS);
      return null;
    }
    final jsArgs = args.map((a) => a.jsify()).toList();
    JSAny? argAt(int index) => index < jsArgs.length ? jsArgs[index] : null;
    // callMethod rather than getProperty + callAsFunction: it is the supported
    // shape for invoking on another window and avoids marshalling the receiver
    // ourselves, which differs between dart2js and dart2wasm.
    final result = win.callMethod<JSAny?>(
      function.toJS,
      argAt(0),
      argAt(1),
      argAt(2),
      argAt(3),
    );
    return result?.dartify();
  } catch (e) {
    // Silence here is what made this invisible for a whole debugging session.
    web.console.warn('[moonfin] $function failed: $e'.toJS);
    return null;
  }
}

Object? readPlayer({required String playerUrl, required String name}) {
  try {
    return _playerWindow(name)?.getProperty(name.toJS)?.dartify();
  } catch (_) {
    return null;
  }
}
