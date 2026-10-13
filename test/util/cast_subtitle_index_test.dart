import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/cast/google_cast_provider.dart';

void main() {
  group('isExplicitSubtitlePick', () {
    test('subtitles off is not a track pick', () {
      expect(isExplicitSubtitlePick(-1), isFalse);
      expect(isExplicitSubtitlePick(-2), isFalse);
      expect(isExplicitSubtitlePick(null), isFalse);
    });

    test('a chosen track is', () {
      expect(isExplicitSubtitlePick(0), isTrue);
      expect(isExplicitSubtitlePick(5), isTrue);
    });
  });
}
