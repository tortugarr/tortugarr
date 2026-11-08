import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/audio_capability_profile.dart';
import 'package:moonfin/playback/lossless_audio_bridge.dart';

AudioCapabilityProfile _route(AudioRouteType route, {int maxPcmChannels = 8}) =>
    AudioCapabilityProfile.fromMap({
      'activeRouteType': route.name,
      'maxPcmChannels': maxPcmChannels,
    });

bool _decides(
  AudioCapabilityProfile profile, {
  int maxAudioChannels = 0,
  bool downmixToStereo = false,
}) => usesLosslessAudioBridge(
  profile,
  maxAudioChannels: maxAudioChannels,
  downmixToStereo: downmixToStereo,
);

void main() {
  group('lossless audio bridge', () {
    test('an HDMI route reporting multichannel PCM bridges losslessly', () {
      expect(_decides(_route(AudioRouteType.hdmi, maxPcmChannels: 32)), isTrue);
      expect(_decides(_route(AudioRouteType.hdmi, maxPcmChannels: 6)), isTrue);
      expect(
        _decides(_route(AudioRouteType.hdmi), maxAudioChannels: 8),
        isTrue,
      );
      expect(
        _decides(_route(AudioRouteType.hdmi), maxAudioChannels: 6),
        isTrue,
      );
    });

    test("eARC carries multichannel PCM and plain ARC doesn't", () {
      expect(_decides(_route(AudioRouteType.earc)), isTrue);
      expect(_decides(_route(AudioRouteType.arc)), isFalse);
    });

    test('a stereo-only HDMI route keeps the EAC3 bridge', () {
      expect(_decides(_route(AudioRouteType.hdmi, maxPcmChannels: 2)), isFalse);
    });

    test('a route without a probe keeps the EAC3 bridge', () {
      expect(_decides(const AudioCapabilityProfile.optimistic()), isFalse);
      for (final route in const [
        AudioRouteType.other,
        AudioRouteType.speaker,
        AudioRouteType.headphones,
        AudioRouteType.bluetooth,
      ]) {
        expect(_decides(_route(route)), isFalse, reason: route.name);
      }
    });

    test('asking for stereo keeps the EAC3 bridge', () {
      final hdmi = _route(AudioRouteType.hdmi);
      expect(_decides(hdmi, downmixToStereo: true), isFalse);
      expect(_decides(hdmi, maxAudioChannels: 2), isFalse);
      expect(_decides(hdmi, maxAudioChannels: 1), isFalse);
    });
  });
}
