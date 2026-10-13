import 'dart:async';
import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

/// Opens the plugin's settings stream and hands back its bytes as they arrive.
///
/// Dio's browser adapter only hands a response over once it has finished,
/// which this one never does, so the browser's fetch reads it a chunk at a
/// time instead.
Future<Stream<List<int>>?> openSettingsStream(
  Dio dio,
  String url, {
  required Map<String, String> headers,
  required CancelToken cancelToken,
}) async {
  final abort = web.AbortController();
  unawaited(cancelToken.whenCancel.then((_) => abort.abort()));

  final requestHeaders = web.Headers();
  headers.forEach((name, value) => requestHeaders.append(name, value));
  final response = await web.window
      .fetch(
        url.toJS,
        web.RequestInit(headers: requestHeaders, signal: abort.signal),
      )
      .toDart;
  if (!response.ok) {
    throw StateError('The settings stream answered ${response.status}');
  }
  final body = response.body;
  if (body == null) return null;

  final reader = body.getReader() as web.ReadableStreamDefaultReader;
  final controller = StreamController<List<int>>();
  controller
    ..onListen = () async {
      try {
        while (true) {
          final chunk = await reader.read().toDart;
          if (chunk.done) break;
          final value = chunk.value;
          if (value != null) controller.add((value as JSUint8Array).toDart);
        }
      } catch (error) {
        if (!controller.isClosed) controller.addError(error);
      }
      if (!controller.isClosed) await controller.close();
    }
    ..onCancel = () => abort.abort();
  return controller.stream;
}
