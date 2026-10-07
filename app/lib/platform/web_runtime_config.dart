import 'web_runtime_config_model.dart';
import 'web_runtime_config_stub.dart'
    if (dart.library.js_interop) 'web_runtime_config_web.dart' as impl;

export 'web_runtime_config_model.dart';

Future<void> loadWebRuntimeConfig() => impl.loadWebRuntimeConfig();

WebRuntimeConfig get webRuntimeConfig => impl.webRuntimeConfig;
