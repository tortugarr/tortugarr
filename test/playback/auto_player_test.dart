import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/playback/auto_player.dart';

Map<String, dynamic> _video(String codec, int height, {String range = 'SDR'}) =>
    {'Type': 'Video', 'Codec': codec, 'Height': height, 'VideoRangeType': range};

Map<String, dynamic> _audio(
  String codec, {
  int index = 1,
  String? profile,
  bool isDefault = false,
}) => {
  'Type': 'Audio',
  'Index': index,
  'Codec': codec,
  'Profile': ?profile,
  'IsDefault': isDefault,
};

AutoPlayerDecision _decide(
  FileProfile profile, {
  bool automatic = true,
  bool settingPrefersMedia3 = true,
  bool bluetooth = false,
  PlayerChoice? title,
  PlayerEngine? learned,
}) => decideAutoPlayer(
  itemKey: 'item',
  profile: profile,
  automatic: automatic,
  settingPrefersMedia3: settingPrefersMedia3,
  bluetoothToMpv: bluetooth,
  titleChoice: title,
  learned: learned,
);

void main() {
  group('FileProfile', () {
    test('plain 1080p H.264 with AAC is light', () {
      final p = FileProfile.of([_video('h264', 1080), _audio('aac')]);
      expect(p.heavy, isFalse);
      expect(p.wantsTunneling, isFalse);
      expect(p.key, 'h264-1080-sdr');
    });

    test('4K Dolby Vision HEVC is heavy and wants tunneling', () {
      final p = FileProfile.of([
        _video('hevc', 2160, range: 'DOVIWithHDR10'),
        _audio('eac3'),
      ]);
      expect(p.heavy, isTrue);
      expect(p.wantsTunneling, isTrue);
      expect(p.key, 'hevc-2160-doviwithhdr10');
    });

    test('1080p HEVC is heavy without tunneling', () {
      final p = FileProfile.of([_video('hevc', 1080), _audio('aac')]);
      expect(p.heavy, isTrue);
      expect(p.wantsTunneling, isFalse);
    });

    test('the selected audio stream decides HD audio', () {
      final streams = [
        _video('h264', 1080),
        _audio('aac', index: 1, isDefault: true),
        _audio('truehd', index: 2, profile: 'Dolby TrueHD + Dolby Atmos'),
      ];
      expect(FileProfile.of(streams).hdAudio, isFalse);
      expect(
        FileProfile.of(streams, selectedAudioStreamIndex: 2).hdAudio,
        isTrue,
      );
    });

    test('DTS-HD MA counts as HD audio, plain DTS does not', () {
      expect(
        FileProfile.of([
          _video('h264', 1080),
          _audio('dts', profile: 'DTS-HD MA'),
        ]).hdAudio,
        isTrue,
      );
      expect(
        FileProfile.of([_video('h264', 1080), _audio('dts', profile: 'DTS')])
            .hdAudio,
        isFalse,
      );
    });
  });

  group('decideAutoPlayer', () {
    final light = FileProfile.of([_video('h264', 1080), _audio('aac')]);
    final heavy = FileProfile.of([
      _video('hevc', 2160, range: 'HDR10'),
      _audio('eac3'),
    ]);

    test('light files go to mpv', () {
      final d = _decide(light);
      expect(d.choice.engine, PlayerEngine.mpv);
      expect(d.reason, AutoPlayerReason.light);
    });

    test('heavy files go to Media3 with tunneling', () {
      final d = _decide(heavy);
      expect(d.choice, const PlayerChoice(PlayerEngine.media3, tunneling: true));
      expect(d.reason, AutoPlayerReason.heavy);
    });

    test('HD audio keeps a light file on Media3 for passthrough', () {
      final p = FileProfile.of([
        _video('h264', 1080),
        _audio('truehd', profile: 'Dolby TrueHD'),
      ]);
      final d = _decide(p);
      expect(d.choice.engine, PlayerEngine.media3);
      expect(d.choice.tunneling, isNull);
    });

    test('the title choice wins over everything', () {
      const pick = PlayerChoice(PlayerEngine.mpv);
      final d = _decide(
        heavy,
        title: pick,
        bluetooth: true,
        learned: PlayerEngine.media3,
      );
      expect(d.choice, pick);
      expect(d.reason, AutoPlayerReason.title);
    });

    test('Bluetooth keeps heavy files on Media3, which mpv cannot decode', () {
      final d = _decide(heavy, bluetooth: true);
      expect(d.choice, const PlayerChoice(PlayerEngine.media3, tunneling: true));
      expect(d.reason, AutoPlayerReason.heavy);
    });

    test('Bluetooth names itself for light files on mpv', () {
      final d = _decide(light, bluetooth: true);
      expect(d.choice.engine, PlayerEngine.mpv);
      expect(d.reason, AutoPlayerReason.bluetooth);
    });

    test('a switch after a stutter beats the rules and the learned engine', () {
      const switched = PlayerChoice(PlayerEngine.media3, tunneling: true);
      final d = decideAutoPlayer(
        itemKey: 'item',
        profile: light,
        automatic: true,
        settingPrefersMedia3: true,
        bluetoothToMpv: true,
        sessionChoice: switched,
        learned: PlayerEngine.mpv,
      );
      expect(d.choice, switched);
      expect(d.reason, AutoPlayerReason.stutter);
    });

    test('a learned engine beats the rules', () {
      final d = _decide(light, learned: PlayerEngine.media3);
      expect(d.choice.engine, PlayerEngine.media3);
      expect(d.reason, AutoPlayerReason.learned);
      final h = _decide(heavy, learned: PlayerEngine.mpv);
      expect(h.choice, const PlayerChoice(PlayerEngine.mpv));
    });

    test('off: the engine setting decides and tunneling follows the setting', () {
      final d = _decide(heavy, automatic: false, settingPrefersMedia3: false);
      expect(d.choice, const PlayerChoice(PlayerEngine.mpv));
      expect(d.reason, AutoPlayerReason.setting);
      final m = _decide(light, automatic: false);
      expect(m.choice, const PlayerChoice(PlayerEngine.media3));
    });
  });

  group('PlayerChoice JSON', () {
    test('round trips', () {
      const c = PlayerChoice(PlayerEngine.media3, tunneling: true);
      expect(PlayerChoice.fromJson(c.toJson()), c);
      expect(PlayerChoice.fromJson({'engine': 'nope'}), isNull);
      expect(PlayerChoice.fromJson(null), isNull);
    });
  });

  group('StutterMeter', () {
    late DateTime now;
    late StutterMeter meter;

    setUp(() {
      now = DateTime(2026, 10, 22, 20);
      meter = StutterMeter(clock: () => now)..restart();
    });

    test('ignores drops while playback settles', () {
      expect(meter.addDroppedFrames(100), isFalse);
    });

    test('trips on enough dropped frames inside the window', () {
      now = now.add(StutterMeter.settle + const Duration(seconds: 1));
      expect(meter.addDroppedFrames(10), isFalse);
      now = now.add(const Duration(seconds: 10));
      expect(meter.addDroppedFrames(10), isFalse);
      now = now.add(const Duration(seconds: 10));
      expect(meter.addDroppedFrames(10), isTrue);
    });

    test('old drops fall out of the window', () {
      now = now.add(StutterMeter.settle + const Duration(seconds: 1));
      expect(meter.addDroppedFrames(20), isFalse);
      now = now.add(StutterMeter.window + const Duration(seconds: 1));
      expect(meter.addDroppedFrames(10), isFalse);
    });

    test('trips on repeated audio underruns', () {
      now = now.add(StutterMeter.settle + const Duration(seconds: 1));
      for (var i = 0; i < StutterMeter.underrunLimit - 1; i++) {
        expect(meter.addUnderrun(), isFalse);
      }
      expect(meter.addUnderrun(), isTrue);
    });
  });
}
