import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

class EmbyUserViewsApi implements UserViewsApi {
  final Dio _dio;
  final String Function() _getUserId;
  Map<String, dynamic>? _cached;
  DateTime? _cachedAt;
  static const _cacheDuration = Duration(minutes: 5);

  EmbyUserViewsApi(this._dio, this._getUserId);

  // Emby has no includeHidden parameter and hides My Media entries on the
  // client, so the flag doesn't change what comes back here.
  @override
  Future<Map<String, dynamic>> getUserViews({
    bool includeHidden = false,
  }) async {
    if (_cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheDuration) {
      return _cached!;
    }
    final userId = _getUserId();
    final response = await _dio.get('/Users/$userId/Views');
    _cached = response.data as Map<String, dynamic>;
    _cachedAt = DateTime.now();
    return _cached!;
  }

  void invalidateCache() {
    _cached = null;
    _cachedAt = null;
  }
}
