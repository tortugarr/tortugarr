import 'package:dio/dio.dart';

/// Opens the plugin's settings stream and hands back its bytes as they arrive.
Future<Stream<List<int>>?> openSettingsStream(
  Dio dio,
  String url, {
  required Map<String, String> headers,
  required CancelToken cancelToken,
}) async {
  final response = await dio.get<ResponseBody>(
    url,
    options: Options(
      headers: headers,
      responseType: ResponseType.stream,
      // The caller times out a quiet stream itself, allowing for the server's
      // heartbeat, so Dio's own receive timeout stays out of it.
      receiveTimeout: Duration.zero,
    ),
    cancelToken: cancelToken,
  );
  // Dio's stream is typed Uint8List, which utf8.decoder can't take as is.
  return response.data?.stream.cast<List<int>>();
}
