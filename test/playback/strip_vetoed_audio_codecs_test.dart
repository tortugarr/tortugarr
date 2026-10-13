import 'package:flutter_test/flutter_test.dart';
import 'package:playback_core/playback_core.dart';

Map<String, dynamic> _profile() => {
  'DirectPlayProfiles': [
    {'Container': 'mkv', 'AudioCodec': 'aac,ac3,eac3,flac'},
    {'Container': 'mp4', 'AudioCodec': 'eac3'},
  ],
  'TranscodingProfiles': [
    {'Container': 'ts', 'AudioCodec': 'aac,ac3,EAC3,mp3'},
  ],
  'CodecProfiles': [
    {'Type': 'VideoAudio', 'Codec': 'eac3'},
  ],
};

void main() {
  test('the vetoed codec leaves every audio list, case insensitively', () {
    final profile = _profile();
    stripVetoedAudioCodecs(profile, {'eac3'});

    final direct = profile['DirectPlayProfiles'] as List;
    expect((direct.first as Map)['AudioCodec'], 'aac,ac3,flac');
    final transcoding = profile['TranscodingProfiles'] as List;
    expect((transcoding.single as Map)['AudioCodec'], 'aac,ac3,mp3');
  });

  test('an entry with nothing left is dropped, empty would mean anything', () {
    final profile = _profile();
    stripVetoedAudioCodecs(profile, {'eac3'});

    final direct = profile['DirectPlayProfiles'] as List;
    expect(direct, hasLength(1));
    expect((direct.single as Map)['Container'], 'mkv');
  });

  test('an empty veto set touches nothing', () {
    final profile = _profile();
    stripVetoedAudioCodecs(profile, const {});

    expect(profile, _profile());
  });

  test('codecs that were not vetoed survive untouched', () {
    final profile = _profile();
    stripVetoedAudioCodecs(profile, {'dts', 'dca'});

    expect(profile, _profile());
  });
}
