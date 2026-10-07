import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/playback/audio_capability_probe.dart';
import 'package:moonfin/playback/audio_capability_profile.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UserPreferences> _prefs([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final store = PreferenceStore();
  await store.init();
  return UserPreferences(store);
}

AudioCapabilityProfile _profile({
  int maxPcmChannels = 8,
  AudioRouteType activeRouteType = AudioRouteType.hdmi,
  bool canPassthroughAc3 = false,
  bool canPassthroughEac3 = false,
}) {
  return AudioCapabilityProfile(
    canDecodeAc3: true,
    canDecodeEac3: true,
    canDecodeDts: true,
    canDecodeDtsHd: true,
    canDecodeTrueHd: true,
    canDecodeFlac: true,
    canPassthroughAc3: canPassthroughAc3,
    canPassthroughEac3: canPassthroughEac3,
    canPassthroughEac3Joc: false,
    canPassthroughDts: false,
    canPassthroughDtsHd: false,
    canPassthroughDtsX: false,
    canPassthroughTrueHd: false,
    canPassthroughTrueHdJoc: false,
    maxPcmChannels: maxPcmChannels,
    activeRouteType: activeRouteType,
    routeSupportsHdAudio: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyAudioPassthroughPreset', () {
    test('stereo preset resets an explicit channel cap to Auto', () async {
      final prefs = await _prefs();
      await prefs.set(UserPreferences.maxAudioChannels, 2);

      await prefs.applyAudioPassthroughPreset(AudioPassthroughPreset.stereo);

      expect(prefs.get(UserPreferences.maxAudioChannels), 0);
      expect(
        prefs.get(UserPreferences.audioOutputMode),
        AudioOutputMode.forceStereo,
      );
    });

    test('auto preset also resets the channel cap', () async {
      final prefs = await _prefs();
      await prefs.set(UserPreferences.maxAudioChannels, 2);

      await prefs.applyAudioPassthroughPreset(AudioPassthroughPreset.auto);

      expect(prefs.get(UserPreferences.maxAudioChannels), 0);
      expect(
        prefs.get(UserPreferences.audioOutputMode),
        AudioOutputMode.auto,
      );
    });
  });

  group('AudioCapabilityProbe.recommendedPresetFor', () {
    test('null probe result recommends auto', () {
      expect(
        AudioCapabilityProbe.recommendedPresetFor(null),
        AudioPassthroughPreset.auto,
      );
    });

    test(
      'a degenerate result (stereo on an unidentified route) recommends '
      'auto so a failed probe never locks in forced stereo',
      () {
        final degenerate = _profile(
          maxPcmChannels: 2,
          activeRouteType: AudioRouteType.other,
        );

        expect(
          AudioCapabilityProbe.recommendedPresetFor(degenerate),
          AudioPassthroughPreset.auto,
        );
      },
    );

    test('a genuine stereo sink on a real route recommends stereo', () {
      final stereoTv = _profile(
        maxPcmChannels: 2,
        activeRouteType: AudioRouteType.hdmi,
      );

      expect(
        AudioCapabilityProbe.recommendedPresetFor(stereoTv),
        AudioPassthroughPreset.stereo,
      );
    });

    test('an AVR route with passthrough recommends surround receiver', () {
      final avr = _profile(
        maxPcmChannels: 8,
        activeRouteType: AudioRouteType.earc,
        canPassthroughAc3: true,
        canPassthroughEac3: true,
      );

      expect(
        AudioCapabilityProbe.recommendedPresetFor(avr),
        AudioPassthroughPreset.surroundReceiver,
      );
    });

    test('a multichannel non-AVR route recommends auto', () {
      final multichannel = _profile(
        maxPcmChannels: 8,
        activeRouteType: AudioRouteType.bluetooth,
      );

      expect(
        AudioCapabilityProbe.recommendedPresetFor(multichannel),
        AudioPassthroughPreset.auto,
      );
    });
  });
}
