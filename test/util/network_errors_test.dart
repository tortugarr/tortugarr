import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/network_errors.dart';

DioException _dio(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/Items'),
  type: type,
);

// The library and favorites screens key their localized connection message on
// this, so a wrong answer shows raw exception text to the user again.
void main() {
  test('unreachable server shapes count as network errors', () {
    expect(
      isNetworkException(_dio(DioExceptionType.connectionTimeout)),
      isTrue,
    );
    expect(isNetworkException(_dio(DioExceptionType.connectionError)), isTrue);
    expect(isNetworkException(_dio(DioExceptionType.sendTimeout)), isTrue);
    expect(isNetworkException(_dio(DioExceptionType.receiveTimeout)), isTrue);
  });

  test('server answers and plain bugs do not', () {
    expect(isNetworkException(_dio(DioExceptionType.badResponse)), isFalse);
    expect(isNetworkException(_dio(DioExceptionType.cancel)), isFalse);
    expect(isNetworkException(StateError('bug')), isFalse);
    expect(isNetworkException(null), isFalse);
  });
}
