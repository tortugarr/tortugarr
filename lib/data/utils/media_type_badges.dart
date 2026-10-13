import '../../preference/preference_constants.dart';
import '../models/aggregated_item.dart';

bool showsMediaTypeBadges(
  MediaTypeBadgeBehavior behavior,
  List<AggregatedItem> items,
) {
  switch (behavior) {
    case MediaTypeBadgeBehavior.always:
      return true;
    case MediaTypeBadgeBehavior.never:
      return false;
    case MediaTypeBadgeBehavior.mixedRowsOnly:
      var sawMovie = false;
      var sawSeries = false;
      for (final item in items) {
        switch (item.seerrMediaType?.toLowerCase()) {
          case 'movie':
            sawMovie = true;
          case 'tv':
            sawSeries = true;
        }
        if (sawMovie && sawSeries) return true;
      }
      return false;
  }
}
