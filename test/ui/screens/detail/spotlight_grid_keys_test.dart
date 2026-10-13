// The Spotlight modal grids key every cell so a rebuild reuses the elements
// already on screen. Those keys have to stay unique, because the lists behind
// them can name the same title or person more than once and Flutter asserts
// on duplicate keys among siblings.
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';
import 'package:moonfin/util/seerr_credits.dart';

void main() {
  group('spotlightCellKeys', () {
    test('leaves distinct ids alone', () {
      expect(spotlightCellKeys(['a', 'b', 'c']), ['a', 'b', 'c']);
    });

    test('gives every repeat its own key', () {
      expect(spotlightCellKeys(['a', 'b', 'a', 'a']), [
        'a',
        'b',
        'a#1',
        'a#2',
      ]);
    });

    test('the same list always produces the same keys', () {
      const ids = ['x', 'y', 'x'];
      expect(spotlightCellKeys(ids), spotlightCellKeys(ids));
    });
  });

  group('spotlightDedupePeople', () {
    test('folds a repeated person into one entry and joins their roles', () {
      final people = spotlightDedupePeople([
        {'Id': 'p1', 'Name': 'Ripley', 'Role': 'Ellen Ripley'},
        {'Id': 'p1', 'Name': 'Ripley', 'Role': 'Narrator'},
        {'Id': 'p2', 'Name': 'Hicks', 'Role': 'Corporal'},
      ]);

      expect(people, hasLength(2));
      expect(people.first['Role'], 'Ellen Ripley · Narrator');
      expect(people.last['Role'], 'Corporal');
    });

    test('drops entries with nothing to key on', () {
      expect(spotlightDedupePeople([{'Role': 'Extra'}]), isEmpty);
    });
  });

  group('groupSeerrCredits', () {
    test('a title credited twice becomes one entry with both jobs', () {
      final grouped = groupSeerrCredits(const [
        SeerrDiscoverItem(id: 11, title: 'Aliens', job: 'Director'),
        SeerrDiscoverItem(id: 11, title: 'Aliens', job: 'Writer'),
        SeerrDiscoverItem(id: 12, title: 'Avatar', job: 'Director'),
      ], isCrew: true);

      expect(grouped.map((i) => i.id), [11, 12]);
      expect(grouped.first.job, 'Director, Writer');
    });

    test('cast entries join their characters instead', () {
      final grouped = groupSeerrCredits(const [
        SeerrDiscoverItem(id: 7, title: 'Twins', character: 'Julius'),
        SeerrDiscoverItem(id: 7, title: 'Twins', character: 'Vincent'),
      ], isCrew: false);

      expect(grouped.single.character, 'Julius, Vincent');
    });

    test('every id survives exactly once, so grid keys stay unique', () {
      final grouped = groupSeerrCredits(const [
        SeerrDiscoverItem(id: 1, title: 'A', job: 'Director'),
        SeerrDiscoverItem(id: 1, title: 'A', job: 'Writer'),
        SeerrDiscoverItem(id: 1, title: 'A', job: 'Producer'),
      ], isCrew: true);

      final ids = grouped.map((i) => '${i.id}').toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(spotlightCellKeys(ids), ids);
    });
  });
}
