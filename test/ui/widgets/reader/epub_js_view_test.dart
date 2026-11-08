import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/reader/epub_js_view.dart';

void main() {
  group('EpubJsLocation.tryParse', () {
    const cfi = 'epubcfi(/6/8!/4/2/10/1:120)';

    test('reads a relocated message', () {
      final location = EpubJsLocation.tryParse({
        'type': 'relocated',
        'cfi': cfi,
        'index': 3,
        'percentage': 0.42,
        'atEnd': false,
        'minutesLeft': 6,
      })!;

      expect(location.cfi, cfi);
      expect(location.sectionIndex, 3);
      expect(location.fraction, 0.42);
      expect(location.atEnd, isFalse);
      expect(location.minutesLeftInSection, 6);
    });

    test('has no fraction before the location index is built', () {
      final location = EpubJsLocation.tryParse({
        'cfi': cfi,
        'index': 0,
        'percentage': null,
        'minutesLeft': null,
      })!;

      expect(location.fraction, isNull);
      expect(location.minutesLeftInSection, isNull);
    });

    test('a whole number percentage still counts', () {
      expect(
        EpubJsLocation.tryParse({'cfi': cfi, 'index': 9, 'percentage': 1})!
            .fraction,
        1.0,
      );
    });

    test('a percentage outside 0 to 1 is clamped', () {
      expect(
        EpubJsLocation.tryParse({'cfi': cfi, 'index': 0, 'percentage': 3})!
            .fraction,
        1.0,
      );
    });

    test('drops messages without a usable place', () {
      expect(EpubJsLocation.tryParse(null), isNull);
      expect(EpubJsLocation.tryParse('relocated'), isNull);
      expect(EpubJsLocation.tryParse({'index': 1}), isNull);
      expect(EpubJsLocation.tryParse({'cfi': '/6/8', 'index': 1}), isNull);
      expect(EpubJsLocation.tryParse({'cfi': cfi, 'index': -1}), isNull);
      expect(EpubJsLocation.tryParse({'cfi': cfi, 'index': '2'}), isNull);
    });
  });
}
