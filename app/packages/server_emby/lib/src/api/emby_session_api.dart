import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class EmbySessionApi implements SessionApi {
  final Dio _dio;

  EmbySessionApi(this._dio);

  @override
  Future<void> reportCapabilities(Map<String, dynamic> capabilities) async {
    await _dio.post('/Sessions/Capabilities/Full', data: capabilities);
  }

  @override
  Future<List<Map<String, dynamic>>> getSessions({String? controllableByUserId}) async {
    final response = await _dio.get('/Sessions', queryParameters: {
      'ControllableByUserId': ?controllableByUserId,
    });
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> sendPlayCommand(
    String sessionId, {
    required String playCommand,
    required List<String> itemIds,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? startIndex,
  }) async {
    await _dio.post(
      '/Sessions/$sessionId/Playing',
      queryParameters: {
        'playCommand': playCommand,
        'itemIds': itemIds.join(','),
        'startPositionTicks': ?startPositionTicks,
        'mediaSourceId': ?mediaSourceId,
        'audioStreamIndex': ?audioStreamIndex,
        'subtitleStreamIndex': ?subtitleStreamIndex,
        'startIndex': ?startIndex,
      },
    );
  }

  @override
  Future<void> sendPlayStateCommand(String sessionId, String command, {int? seekPositionTicks}) async {
    await _dio.post(
      '/Sessions/$sessionId/Playing/$command',
      queryParameters: {
        'seekPositionTicks': ?seekPositionTicks,
      },
    );
  }

  @override
  Future<void> sendMessage(String sessionId, String text, {String? header, int? timeoutMs}) async {
    await _dio.post(
      '/Sessions/$sessionId/Message',
      data: {
        'Text': text,
        'Header': ?header,
        'TimeoutMs': ?timeoutMs,
      },
    );
  }

  @override
  Future<void> sendGeneralCommand(String sessionId, String commandName, {Map<String, String>? arguments}) async {
    await _dio.post(
      '/Sessions/$sessionId/Command',
      data: {
        'Name': commandName,
        'Arguments': ?arguments,
      },
    );
  }
}

