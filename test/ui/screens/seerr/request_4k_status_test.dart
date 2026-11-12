import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';
import 'package:moonfin/ui/screens/seerr/seerr_requests_screen.dart';

SeerrRequest _req({required bool is4k, int? status, int? status4k}) => SeerrRequest(
      id: 1,
      status: SeerrRequest.statusApproved,
      type: 'movie',
      is4k: is4k,
      media: SeerrMedia(id: 1, status: status, status4k: status4k),
    );

void main() {
  final l10n = AppLocalizationsEn();

  test('a 4K request is Available once the title is in the library (one Radarr for every quality)', () {
    final (label, _) = SeerrRequestsScreen.statusInfoFor(_req(is4k: true, status: 5, status4k: 3), l10n);
    expect(label, l10n.seerrAvailableStatus);
  });

  test('a 4K request whose title is not in the library still reads Requested', () {
    final (label, _) = SeerrRequestsScreen.statusInfoFor(_req(is4k: true, status: 3, status4k: 3), l10n);
    expect(label, l10n.seerrRequestedStatus);
  });

  test('a deleted or blocklisted 4K status is kept', () {
    final (label, _) = SeerrRequestsScreen.statusInfoFor(_req(is4k: true, status: 5, status4k: 7), l10n);
    expect(label, l10n.deletedStatus);
  });
}
