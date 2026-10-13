import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/navigation/destinations.dart';

void main() {
  group('Destinations.item', () {
    test('stays bare without options', () {
      expect(Destinations.item('abc'), '/item/abc');
    });

    test(
      'carries the browsed season so an inlined special keeps its context',
      () {
        expect(
          Destinations.item(
            'special-id',
            serverId: 's1',
            seasonContext: 'season-1',
          ),
          '/item/special-id?serverId=s1&seasonContext=season-1',
        );
      },
    );

    test('omits an absent or empty season context', () {
      expect(Destinations.item('abc', seasonContext: null), '/item/abc');
      expect(Destinations.item('abc', seasonContext: ''), '/item/abc');
    });

    test('escapes a season context so it survives the query string', () {
      final uri = Uri.parse(Destinations.item('abc', seasonContext: 'a b&c'));
      expect(uri.queryParameters['seasonContext'], 'a b&c');
    });
  });
}
