import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/seerr/seerr_error.dart';

void main() {
  group('SeerrUser.hasPermission', () {
    test('user id 1 holds nothing beyond their permission bits', () {
      const user = SeerrUser(id: 1, permissions: 0);

      expect(user.hasPermission(SeerrPermission.manageRequests), isFalse);
      expect(user.isAdmin, isFalse);
    });

    test('the admin bit still grants everything', () {
      const user = SeerrUser(id: 5, permissions: SeerrPermission.admin);

      expect(user.hasPermission(SeerrPermission.manageRequests), isTrue);
      expect(user.hasPermission(SeerrPermission.request4k), isTrue);
    });

    test('a plain bit grants only itself', () {
      const user = SeerrUser(id: 5, permissions: SeerrPermission.request);

      expect(user.hasPermission(SeerrPermission.request), isTrue);
      expect(user.hasPermission(SeerrPermission.manageRequests), isFalse);
    });
  });

  group('SeerrRequestException.fromResponse', () {
    test('a 401 with a message is a permission denial', () {
      const message = 'You do not have permission to delete this request.';
      final e = SeerrRequestException.fromResponse(401, {'message': message});

      expect(e, isNotNull);
      expect(e!.kind, SeerrRequestErrorKind.permission);
      expect(e.serverMessage, message);
    });

    test('the plugin session bodies keep the generic path', () {
      final expired = SeerrRequestException.fromResponse(401, {
        'error': 'Seerr session expired',
        'code': 'SESSION_EXPIRED',
      });
      final missing = SeerrRequestException.fromResponse(401, {
        'error': 'Not authenticated with Seerr',
        'code': 'NO_SESSION',
      });

      expect(expired, isNull);
      expect(missing, isNull);
    });
  });
}
