/// Non-web platforms deliver player messages through the
/// `flutter_inappwebview` JavaScript handler, so there is nothing to
/// subscribe to here.
void Function() subscribe({
  required String allowedOrigin,
  required void Function(Object? message) onMessage,
}) => () {};

/// Non-web platforms route player calls through InAppWebViewController, which
/// works fine there -- only web needs the direct path.
bool get supportsDirectCalls => false;

Object? callPlayer({
  required String playerUrl,
  required String function,
  List<Object?> args = const [],
}) => null;

Object? readPlayer({required String playerUrl, required String name}) => null;
