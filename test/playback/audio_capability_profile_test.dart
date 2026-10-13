import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/audio_capability_profile.dart';

AudioCapabilityProfile _profile({
  AudioRouteType route = AudioRouteType.hdmi,
  bool ac3 = true,
  bool eac3 = true,
  bool dts = false,
  bool dtsHd = false,
  bool trueHd = false,
  int maxPcmChannels = 8,
}) {
  return AudioCapabilityProfile.fromMap({
    'activeRouteType': route.name,
    'canPassthroughAc3': ac3,
    'canPassthroughEac3': eac3,
    'canPassthroughDts': dts,
    'canPassthroughDtsHd': dtsHd,
    'canPassthroughTrueHd': trueHd,
    'maxPcmChannels': maxPcmChannels,
  });
}

void main() {
  group('isDowngradeFrom', () {
    test('leaving the bitstream routes for the speaker is a downgrade', () {
      final hdmi = _profile();
      final speaker = _profile(
        route: AudioRouteType.speaker,
        ac3: false,
        eac3: false,
        maxPcmChannels: 2,
      );
      expect(speaker.isDowngradeFrom(hdmi), isTrue);
      expect(hdmi.isDowngradeFrom(speaker), isFalse);
    });

    test('fewer channels on the same route is a downgrade', () {
      final eight = _profile();
      final two = _profile(maxPcmChannels: 2);
      expect(two.isDowngradeFrom(eight), isTrue);
      expect(eight.isDowngradeFrom(two), isFalse);
    });

    test('losing a single passthrough format is a downgrade', () {
      final withEac3 = _profile();
      final withoutEac3 = _profile(eac3: false);
      expect(withoutEac3.isDowngradeFrom(withEac3), isTrue);
      expect(withEac3.isDowngradeFrom(withoutEac3), isFalse);
    });

    test('hdmi to arc counts only when a lossless format was in play', () {
      // fromMap gates TrueHD and DTS-HD by route, so the move shows up in
      // those flags rather than in the route class, which ARC still belongs
      // to.
      final hdmiTrueHd = _profile(trueHd: true);
      final arcTrueHd = _profile(route: AudioRouteType.arc, trueHd: true);
      expect(arcTrueHd.isDowngradeFrom(hdmiTrueHd), isTrue);

      final hdmiPlain = _profile();
      final arcPlain = _profile(route: AudioRouteType.arc);
      expect(arcPlain.isDowngradeFrom(hdmiPlain), isFalse);
    });

    test('an equal profile is not a downgrade', () {
      expect(_profile().isDowngradeFrom(_profile()), isFalse);
    });

    test('a richer route is never a downgrade', () {
      final arc = _profile(route: AudioRouteType.arc, maxPcmChannels: 6);
      final earc = _profile(route: AudioRouteType.earc, trueHd: true);
      expect(earc.isDowngradeFrom(arc), isFalse);
    });

    test('the unenumerated state reads as a downgrade from a real route', () {
      // It reports eight channels, so only the route class gives it away,
      // which is why apply checks looksEmpty before asking this.
      final hdmi = _profile();
      final unenumerated = _profile(
        route: AudioRouteType.other,
        ac3: false,
        eac3: false,
      );
      expect(unenumerated.isDowngradeFrom(hdmi), isTrue);
    });
  });
}
