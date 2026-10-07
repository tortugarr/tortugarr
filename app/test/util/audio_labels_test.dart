import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/audio_labels.dart';

void main() {
  group('audioLabelFromProfileCodec', () {
    test('returns Atmos when profile contains atmos', () {
      expect(audioLabelFromProfileCodec('Dolby Atmos', 'truehd'), 'Atmos');
    });

    test('returns DTS:X when DTS profile contains dts:x', () {
      expect(audioLabelFromProfileCodec('DTS:X', 'dts'), 'DTS:X');
    });

    test('returns DTS-HD MA when profile indicates master audio', () {
      expect(audioLabelFromProfileCodec('DTS-HD MA', 'dts'), 'DTS-HD MA');
      expect(audioLabelFromProfileCodec('Master Audio', 'dca'), 'DTS-HD MA');
    });

    test('returns DTS-HD HRA when profile indicates high resolution audio', () {
      expect(audioLabelFromProfileCodec('DTS-HD HRA', 'dts'), 'DTS-HD HRA');
      expect(
        audioLabelFromProfileCodec('High Resolution Audio', 'dts'),
        'DTS-HD HRA',
      );
    });

    test('falls back to DTS for DTS codecs without profile detail', () {
      expect(audioLabelFromProfileCodec(null, 'dts'), 'DTS');
      expect(audioLabelFromProfileCodec('', 'dca'), 'DTS');
    });

    test('returns uppercased codec for non-DTS values', () {
      expect(audioLabelFromProfileCodec(null, 'eac3'), 'EAC3');
      expect(audioLabelFromProfileCodec(null, 'truehd'), 'TRUEHD');
    });

    test('does not misclassify ADTS as DTS', () {
      expect(audioLabelFromProfileCodec(null, 'adts'), 'ADTS');
    });

    test('returns null when codec is null or empty', () {
      expect(audioLabelFromProfileCodec('DTS:X', null), isNull);
      expect(audioLabelFromProfileCodec('DTS:X', ''), isNull);
    });
  });
}
