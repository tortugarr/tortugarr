import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/web_playback_capabilities.dart';

void main() {
  test('non-web capability probe stays conservative', () {
    final capabilities = detectWebPlaybackCapabilities();

    expect(capabilities.supportsAvc, isFalse);
    expect(capabilities.supportsHevc, isFalse);
    expect(capabilities.supportsAv1, isFalse);

    expect(capabilities.canDecodeAc3, isFalse);
    expect(capabilities.canDecodeEac3, isFalse);
    expect(capabilities.canDecodeTrueHd, isFalse);
    expect(capabilities.canDecodeFlac, isFalse);
    expect(capabilities.maxPcmChannels, equals(2));
  });
}
