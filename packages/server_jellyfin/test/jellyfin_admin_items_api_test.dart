import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';
import 'package:server_jellyfin/src/api/jellyfin_admin_items_api.dart';
import 'package:test/test.dart';

class _FakeServer extends Interceptor {
  _FakeServer(this.handle);

  final void Function(RequestOptions options, RequestInterceptorHandler handler)
  handle;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handle(options, handler);
}

void main() {
  test('refresh always names both modes', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(Response(requestOptions: options, statusCode: 204));
        }),
      );

    await JellyfinAdminItemsApi(dio).refreshItem('movie-1');

    expect(request?.method, 'POST');
    expect(request?.path, '/Items/movie-1/Refresh');
    expect(request?.queryParameters['MetadataRefreshMode'], 'Default');
    expect(request?.queryParameters['ImageRefreshMode'], 'Default');
  });

  test('replacing everything asks every provider again', () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(
        _FakeServer((options, handler) {
          request = options;
          handler.resolve(Response(requestOptions: options, statusCode: 204));
        }),
      );

    await JellyfinAdminItemsApi(dio).refreshItem(
      'movie-1',
      replaceAllMetadata: true,
      replaceAllImages: true,
      metadataRefreshMode: MetadataRefreshMode.fullRefresh,
      imageRefreshMode: MetadataRefreshMode.fullRefresh,
    );

    expect(request?.queryParameters, {
      'MetadataRefreshMode': 'FullRefresh',
      'ImageRefreshMode': 'FullRefresh',
      'ReplaceAllMetadata': true,
      'ReplaceAllImages': true,
    });
  });
}
