import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';

// Continue Watching / Next Up open an Episode page; it must get the same
// missing-episode merge as the Season page it belongs to.
void main() {
  group('MissingEpisodes.appliesTo', () {
    test('series, season and episode pages merge missing episodes', () {
      expect(MissingEpisodes.appliesTo('Series'), isTrue);
      expect(MissingEpisodes.appliesTo('Season'), isTrue);
      expect(MissingEpisodes.appliesTo('Episode'), isTrue);
    });

    test('other pages do not', () {
      expect(MissingEpisodes.appliesTo('Movie'), isFalse);
      expect(MissingEpisodes.appliesTo('BoxSet'), isFalse);
      expect(MissingEpisodes.appliesTo(null), isFalse);
    });
  });

  group('MissingEpisodes.seasonShownBy', () {
    test('a season page lists its own season', () {
      expect(
        MissingEpisodes.seasonShownBy(itemType: 'Season', indexNumber: 3),
        3,
      );
    });

    test('an episode page lists the season it belongs to', () {
      expect(
        MissingEpisodes.seasonShownBy(
          itemType: 'Episode',
          indexNumber: 7,
          parentIndexNumber: 3,
        ),
        3,
      );
    });

    test('a series page lists no single season', () {
      expect(
        MissingEpisodes.seasonShownBy(itemType: 'Series', indexNumber: 1),
        isNull,
      );
    });

    test('an episode without season number lists none', () {
      expect(
        MissingEpisodes.seasonShownBy(itemType: 'Episode', indexNumber: 2),
        isNull,
      );
    });
  });
}
