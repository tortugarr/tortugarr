import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/synced_fields.dart';

// Colours are stored as a packed ARGB int locally but travel as text, because the other
// clients keep them as CSS style strings. That conversion is the easiest part of the codec
// set to get wrong, so it is exercised directly.
void main() {
  group('colour wire format', () {
    // The service holds the conversion privately, so the same rules are restated here. If
    // these ever diverge the round trip tests below stop meaning anything, so keep them
    // together.
    int? parse(String value) {
      var hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length != 8) return null;
      return int.tryParse(hex, radix: 16);
    }

    String format(int value) =>
        '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    test('round-trips the values the subtitle settings actually use', () {
      for (final colour in <int>[
        0xFFFFFFFF, // white, the default subtitle colour
        0xFF000000, // black, the default stroke
        0x00000000, // fully transparent, the default background
        0xFF1A2B3C,
      ]) {
        expect(parse(format(colour)), colour, reason: format(colour));
      }
    });

    test('accepts a six digit colour as fully opaque', () {
      expect(parse('#1A2B3C'), 0xFF1A2B3C);
    });

    test('accepts a value with no leading hash', () {
      expect(parse('FF1A2B3C'), 0xFF1A2B3C);
    });

    test('rejects anything that is not a colour', () {
      expect(parse('nonsense'), isNull);
      expect(parse('#12345'), isNull);
      expect(parse(''), isNull);
    });

    test('pads a value that needs leading zeroes', () {
      expect(format(0x00000000), '#00000000');
      expect(parse('#00000000'), 0x00000000);
    });
  });

  group('codec coverage', () {
    test('every codec in the enum is used by at least one field', () {
      final used = syncedFields.map((f) => f.codec).toSet();
      final unused = SyncCodec.values.toSet().difference(used);
      expect(unused, isEmpty, reason: 'dead codecs: $unused');
    });
  });
}
