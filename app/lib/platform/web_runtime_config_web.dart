import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'web_runtime_config_model.dart';

WebRuntimeConfig webRuntimeConfig = WebRuntimeConfig.defaults;

Future<void> loadWebRuntimeConfig() async {
  try {
    final configUrl = _resolveConfigUrl();
    final response = await web.window.fetch(configUrl.toJS).toDart;
    if (!response.ok) return;

    final body = (await response.text().toDart).toDart;
    if (body.trim().isEmpty) return;

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      webRuntimeConfig = WebRuntimeConfig.fromJson(decoded);
      return;
    }
    if (decoded is Map) {
      webRuntimeConfig = WebRuntimeConfig.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  } catch (_) {}
}

String _resolveConfigUrl() {
  final baseUri = web.document.baseURI;
  if (baseUri.trim().isNotEmpty) {
    try {
      return Uri.parse(baseUri).resolve('config.json').toString();
    } catch (_) {}
  }

  return Uri.base.resolve('config.json').toString();
}
