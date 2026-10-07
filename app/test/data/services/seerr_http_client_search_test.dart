import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/repositories/seerr_repository.dart';
import 'package:moonfin/data/services/seerr/seerr_query_encoding.dart';

void main() {
  group('strictQueryEncode', () {
    test('encodes a space as %20, never as +', () {
      expect(strictQueryEncode('The Terminator'), 'The%20Terminator');
      expect(strictQueryEncode('The '), 'The%20');
    });

    test('escapes the reserved characters Seerr rejects', () {
      expect(
        strictQueryEncode("Ocean's (11) *!+&="),
        'Ocean%27s%20%2811%29%20%2A%21%2B%26%3D',
      );
    });

    test('leaves the unreserved set untouched', () {
      const plain = 'AZaz09-._~';
      expect(strictQueryEncode(plain), plain);
    });

    test('percent-encodes UTF-8 bytes', () {
      expect(strictQueryEncode('Blå'), 'Bl%C3%A5');
    });
  });

  group('SeerrRepository.isClosedAdapterError', () {
    final options = RequestOptions(path: '/x');

    test('recognises the closed-adapter StateError Dio wraps', () {
      final e = DioException(
        requestOptions: options,
        error: StateError(
          "Can't establish connection after the adapter was closed.",
        ),
      );
      expect(SeerrRepository.isClosedAdapterError(e), isTrue);
    });

    test('ignores other errors', () {
      expect(
        SeerrRepository.isClosedAdapterError(
          DioException(requestOptions: options, message: 'search: HTTP 400'),
        ),
        isFalse,
      );
      expect(
        SeerrRepository.isClosedAdapterError(
          DioException(requestOptions: options, error: StateError('other')),
        ),
        isFalse,
      );
    });
  });
}
