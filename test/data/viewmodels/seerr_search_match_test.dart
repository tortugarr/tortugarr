import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/viewmodels/seerr_media_detail_view_model.dart';

SeerrDiscoverItem hit(int id, String? mediaType) =>
    SeerrDiscoverItem(id: id, mediaType: mediaType);

void main() {
  group('bestSearchMatch', () {
    test('takes the hit of the kind that was asked for, not the most popular', () {
      final results = [hit(1, 'tv'), hit(2, 'movie')];
      expect(SeerrMediaDetailViewModel.bestSearchMatch(results, 'movie').id, 2);
      expect(SeerrMediaDetailViewModel.bestSearchMatch(results, 'tv').id, 1);
    });

    test('keeps the first hit when nothing matches, since a guess beats nothing', () {
      final results = [hit(7, 'person'), hit(8, 'collection')];
      expect(SeerrMediaDetailViewModel.bestSearchMatch(results, 'movie').id, 7);
    });

    test('skips a hit that never said what kind it is', () {
      final results = [hit(3, null), hit(4, 'movie')];
      expect(SeerrMediaDetailViewModel.bestSearchMatch(results, 'movie').id, 4);
    });
  });
}
