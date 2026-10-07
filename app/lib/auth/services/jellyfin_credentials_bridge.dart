import 'jellyfin_credentials_bridge_model.dart';
import 'jellyfin_credentials_bridge_stub.dart'
    if (dart.library.js_interop) 'jellyfin_credentials_bridge_web.dart' as impl;

export 'jellyfin_credentials_bridge_model.dart';

Future<JellyfinBootstrapCredentials?> loadJellyfinBootstrapCredentials({
  String? preferredServerAddress,
}) {
  return impl.loadJellyfinBootstrapCredentials(
    preferredServerAddress: preferredServerAddress,
  );
}
