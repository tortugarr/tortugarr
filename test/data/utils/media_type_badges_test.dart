import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/utils/media_type_badges.dart';
import 'package:moonfin/preference/preference_constants.dart';

AggregatedItem _item(String? mediaType) => AggregatedItem(
  id: 'i',
  serverId: 'srv1',
  rawData: {'SeerrMediaType': ?mediaType},
);

void main() {
  group('showsMediaTypeBadges', () {
    final mixed = [_item('movie'), _item('tv')];
    final moviesOnly = [_item('movie'), _item('movie')];

    test('always and never ignore what the row holds', () {
      expect(showsMediaTypeBadges(MediaTypeBadgeBehavior.always, const []), isTrue);
      expect(showsMediaTypeBadges(MediaTypeBadgeBehavior.never, mixed), isFalse);
    });

    test('mixed rows only asks whether both kinds are present', () {
      expect(
        showsMediaTypeBadges(MediaTypeBadgeBehavior.mixedRowsOnly, mixed),
        isTrue,
      );
      expect(
        showsMediaTypeBadges(MediaTypeBadgeBehavior.mixedRowsOnly, moviesOnly),
        isFalse,
      );
    });

    test('a media type reads whatever case it arrives in', () {
      expect(
        showsMediaTypeBadges(
          MediaTypeBadgeBehavior.mixedRowsOnly,
          [_item('Movie'), _item('TV')],
        ),
        isTrue,
      );
    });

    test('items carrying no media type never make a row mixed', () {
      expect(
        showsMediaTypeBadges(
          MediaTypeBadgeBehavior.mixedRowsOnly,
          [_item('movie'), _item(null), _item('person')],
        ),
        isFalse,
      );
    });
  });
}
