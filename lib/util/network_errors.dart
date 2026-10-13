import 'package:dio/dio.dart';

/// Whether [error] is the server being unreachable rather than a bug, so a
/// screen can show its localized connection message instead of the raw
/// exception text.
bool isNetworkException(Object? error) {
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };
}
