import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/cast/receiver_device_profiles.dart';
import 'package:moonfin/preference/user_preferences.dart';

Map<String, dynamic> _h264CodecProfile(Map<String, dynamic> profile) {
  final codecProfiles =
      (profile['CodecProfiles'] as List).cast<Map<String, dynamic>>();
  return codecProfiles.firstWhere(
    (entry) => entry['Type'] == 'Video' && entry['Codec'] == 'h264',
  );
}

String? _condition(Map<String, dynamic> codecProfile, String property) {
  final conditions =
      (codecProfile['Conditions'] as List).cast<Map<String, dynamic>>();
  for (final condition in conditions) {
    if (condition['Property'] == property) {
      return condition['Value'] as String?;
    }
  }
  return null;
}

void main() {
  group('chromecastDeviceProfile', () {
    test('caps H264 at level 4.1', () {
      // First and second generation Cast devices stop at level 4.1, and a
      // receiver handed a level it refuses rejects the whole manifest before
      // requesting a segment, so nothing reaches the screen.
      final codecProfile = _h264CodecProfile(chromecastDeviceProfile());

      expect(_condition(codecProfile, 'VideoLevel'), '41');
    });

    test('keeps the profile list free of High 10', () {
      // High 10 is the only way H264 carries 10 bit, and no Cast device
      // decodes it. Leaving it out is what keeps a main 10 source from
      // reaching the receiver at 10 bit.
      final codecProfile = _h264CodecProfile(chromecastDeviceProfile());

      expect(_condition(codecProfile, 'VideoProfile'), isNot(contains('10')));
    });

    test('uses the default ceiling when no preference is set', () {
      expect(chromecastDeviceProfile()['MaxStreamingBitrate'], 20000000);
      expect(
        chromecastDeviceProfile(maxBitrateMbps: 0)['MaxStreamingBitrate'],
        20000000,
      );
    });

    test('honours the user ceiling', () {
      // Receivers differ in what they can actually pull, so the cast path
      // reads the same preference the local players do.
      final profile = chromecastDeviceProfile(maxBitrateMbps: 5);

      expect(profile['MaxStreamingBitrate'], 5000000);
      expect(profile['MaxStaticBitrate'], 5000000);
    });

    test('never raises the ceiling above what casting asked for before', () {
      // The preference describes the user's network, not the receiver, and
      // most installs sit on its default. Feeding it through has to leave
      // them where they already were.
      final fromDefault = int.tryParse(
        UserPreferences.maxBitrate.defaultValue.toString(),
      );

      expect(
        chromecastDeviceProfile(
          maxBitrateMbps: fromDefault,
        )['MaxStreamingBitrate'],
        20000000,
      );
      expect(
        chromecastDeviceProfile(maxBitrateMbps: 200)['MaxStreamingBitrate'],
        20000000,
      );
    });

    test('only ever asks the server for H264', () {
      final transcoding =
          (chromecastDeviceProfile()['TranscodingProfiles'] as List)
              .cast<Map<String, dynamic>>();
      final video = transcoding.firstWhere((entry) => entry['Type'] == 'Video');

      expect(video['VideoCodec'], 'h264');
    });
  });
}
