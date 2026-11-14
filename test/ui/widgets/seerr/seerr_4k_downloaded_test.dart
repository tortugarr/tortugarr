import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/viewmodels/seerr_media_detail_view_model.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';
import 'package:moonfin/ui/widgets/seerr/seerr_status_pill.dart';

SeerrMediaDetailState _state({required int hd, required int uhd}) =>
    SeerrMediaDetailState(
      movie: SeerrMovieDetails(
        id: 155,
        title: 'The Dark Knight',
        mediaInfo: SeerrMediaInfo(status: hd, status4k: uhd),
      ),
    );

void main() {
  final l10n = AppLocalizationsEn();

  group('4K that Seerr calls deleted', () {
    test('reads "Downloaded!" while the title is in the library', () {
      final tracks = seerrStatusTracks(_state(hd: 5, uhd: 7), l10n);
      final (uhd, label) = tracks.last;
      expect(label, '4K');
      expect(uhd.downloaded, isTrue);
      expect(uhd.isFullyAvailable, isTrue);
      expect(seerrStatusLabel(uhd, l10n), 'Downloaded!');
      expect(seerrStatusIsNoteworthy(uhd), isTrue);
    });

    test('still reads "Deleted" when the title is gone from the library', () {
      final tracks = seerrStatusTracks(_state(hd: 1, uhd: 7), l10n);
      final (uhd, _) = tracks.last;
      expect(uhd.downloaded, isFalse);
      expect(seerrStatusLabel(uhd, l10n), 'Deleted');
    });

    test('the HD track is left as it is', () {
      final tracks = seerrStatusTracks(_state(hd: 5, uhd: 7), l10n);
      final (hd, label) = tracks.first;
      expect(label, 'HD');
      expect(hd.downloaded, isFalse);
      expect(seerrStatusLabel(hd, l10n), 'Available');
    });

    test('a server with no 4K state shows only the HD track', () {
      final tracks = seerrStatusTracks(_state(hd: 5, uhd: 1), l10n);
      expect(tracks, hasLength(1));
    });
  });
}
