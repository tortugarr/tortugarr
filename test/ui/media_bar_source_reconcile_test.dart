import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/settings/media_bar_settings_screen.dart';

void main() {
  group('reconcileSources', () {
    test('keeps what the server still lists', () {
      final split = reconcileSources(
        stored: {'a', 'b'},
        available: {'a', 'b', 'c'},
        truncated: false,
      );

      expect(split.listed, {'a', 'b'});
      expect(split.unlisted, isEmpty);
      expect(split.stale, isEmpty);
    });

    test('forgets an id the server no longer has', () {
      final split = reconcileSources(
        stored: {'a', 'gone'},
        available: {'a'},
        truncated: false,
      );

      expect(split.listed, {'a'});
      expect(split.stale, {'gone'});
      expect(split.unlisted, isEmpty);
    });

    test('holds back an id a capped fetch could not show', () {
      final split = reconcileSources(
        stored: {'a', 'page2'},
        available: {'a'},
        truncated: true,
      );

      expect(split.listed, {'a'});
      expect(split.unlisted, {'page2'});
      expect(split.stale, isEmpty);
    });

    test('a capped fetch that lists nothing keeps every id', () {
      final split = reconcileSources(
        stored: {'a', 'b'},
        available: const {},
        truncated: true,
      );

      expect(split.listed, isEmpty);
      expect(split.unlisted, {'a', 'b'});
      expect(split.stale, isEmpty);
    });
  });
}
