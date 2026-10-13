import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class JellyfinClientLogApi implements ClientLogApi {
  final Dio _dio;

  JellyfinClientLogApi(this._dio);

  @override
  Future<String?> uploadDocument(String content) async {
    final response = await _dio.post(
      '/ClientLog/Document',
      data: content,
      options: Options(
        contentType: 'text/plain',
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is Map && data['FileName'] != null) {
      return data['FileName'].toString();
    }
    return null;
  }
}
