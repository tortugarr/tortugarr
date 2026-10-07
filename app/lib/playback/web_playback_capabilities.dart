import 'web_playback_capabilities_impl_stub.dart'
    if (dart.library.js_interop) 'web_playback_capabilities_impl_web.dart'
    as impl;
import 'web_playback_capabilities_model.dart';

export 'web_playback_capabilities_model.dart';

WebPlaybackCapabilities detectWebPlaybackCapabilities() {
  return impl.detectWebPlaybackCapabilities();
}
