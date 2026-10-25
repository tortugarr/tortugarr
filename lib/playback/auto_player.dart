import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../preference/user_preferences.dart';
import '../util/platform_detection.dart';
import 'audio_capability_profile.dart';

/// The two engines Android can play video with.
enum PlayerEngine { media3, mpv }

/// What a file looks like to the engine choice: a short key that groups
/// files the same engine handles alike, and whether it is heavy (4K, HDR,
/// Dolby Vision, HEVC/AV1) or a plain 1080p H.264 file.
@immutable
class FileProfile {
  const FileProfile({
    required this.key,
    required this.heavy,
    required this.wantsTunneling,
    required this.hdAudio,
  });

  final String key;
  final bool heavy;

  /// 4K or HDR: the files that stuttered on Media3 without tunneling.
  final bool wantsTunneling;

  /// TrueHD or DTS-HD, which only Media3 passes through to an amplifier.
  final bool hdAudio;

  static FileProfile of(
    List<Map<String, dynamic>> streams, {
    int? selectedAudioStreamIndex,
  }) {
    Map<String, dynamic>? video;
    for (final s in streams) {
      if (s['Type'] == 'Video') {
        video = s;
        break;
      }
    }
    final audios = streams.where((s) => s['Type'] == 'Audio').toList();
    Map<String, dynamic>? audio;
    for (final s in audios) {
      if (s['Index'] == selectedAudioStreamIndex) audio = s;
    }
    audio ??= audios.where((s) => s['IsDefault'] == true).firstOrNull;
    audio ??= audios.firstOrNull;

    final codec = (video?['Codec'] as String? ?? 'none').toLowerCase();
    final height = (video?['Height'] as num?)?.toInt() ?? 0;
    final range = (video?['VideoRangeType'] as String? ?? 'SDR').toUpperCase();
    final hdr = range != 'SDR' && range.isNotEmpty;
    final tier = height >= 1600
        ? '2160'
        : height > 1100
        ? '1440'
        : height > 0
        ? '1080'
        : '0';
    final audioCodec = (audio?['Codec'] as String? ?? '').toLowerCase();
    final audioProfile = (audio?['Profile'] as String? ?? '').toLowerCase();
    final hdAudio =
        audioCodec == 'truehd' ||
        (audioCodec == 'dts' &&
            (audioProfile.contains('hd') || audioProfile.contains('x')));
    final plainCodec = codec == 'h264' || codec == 'mpeg2video';
    final wantsTunneling = tier == '2160' || hdr;
    return FileProfile(
      key: '$codec-$tier-${hdr ? range.toLowerCase() : 'sdr'}',
      heavy: !plainCodec || tier == '2160' || tier == '1440' || hdr,
      wantsTunneling: wantsTunneling,
      hdAudio: hdAudio,
    );
  }
}

/// Why an engine was picked, for the player menu and the log.
enum AutoPlayerReason {
  /// Picked for this title in the player menu.
  title,

  /// Automatic choice is off, so the engine setting decides.
  setting,

  /// Sound goes to Bluetooth (mpv with Bluetooth audio).
  bluetooth,

  /// This kind of file stuttered on the other engine before.
  learned,

  /// Playback stuttered a moment ago, so this session switched engine.
  stutter,

  /// 4K, HDR, HEVC or HD audio: Media3.
  heavy,

  /// Plain 1080p H.264: mpv, which keeps the timing on TVs where Media3 drops
  /// frames with such files.
  light,
}

@immutable
class PlayerChoice {
  const PlayerChoice(this.engine, {this.tunneling});

  final PlayerEngine engine;

  /// Null leaves tunneling to the setting.
  final bool? tunneling;

  Map<String, dynamic> toJson() => {
    'engine': engine.name,
    if (tunneling != null) 'tunneling': tunneling,
  };

  static PlayerChoice? fromJson(Object? json) {
    if (json is! Map) return null;
    final engine = PlayerEngine.values
        .where((e) => e.name == json['engine'])
        .firstOrNull;
    if (engine == null) return null;
    final tunneling = json['tunneling'];
    return PlayerChoice(engine, tunneling: tunneling is bool ? tunneling : null);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerChoice &&
      other.engine == engine &&
      other.tunneling == tunneling;

  @override
  int get hashCode => Object.hash(engine, tunneling);
}

@immutable
class AutoPlayerDecision {
  const AutoPlayerDecision({
    required this.itemKey,
    required this.profile,
    required this.choice,
    required this.reason,
  });

  final String itemKey;
  final FileProfile profile;
  final PlayerChoice choice;
  final AutoPlayerReason reason;
}

/// The engine rules as a pure function, so tests can walk every branch.
/// Tunneling for a file the automatic player sends to Media3: on, except for a
/// light file kept on Media3 only to pass TrueHD/DTS-HD through. On the TCL TV
/// Media3 without tunneling froze on plain 1080p H.264 (Musk, 2026-10-25) and
/// stuttered on 4K, while both played cleanly with it.
bool? media3Tunneling(FileProfile profile) =>
    profile.wantsTunneling || profile.heavy || !profile.hdAudio ? true : null;

AutoPlayerDecision decideAutoPlayer({
  required String itemKey,
  required FileProfile profile,
  required bool automatic,
  required bool settingPrefersMedia3,
  required bool bluetoothToMpv,
  PlayerChoice? titleChoice,
  PlayerChoice? sessionChoice,
  PlayerEngine? learned,
}) {
  AutoPlayerDecision pick(PlayerChoice choice, AutoPlayerReason reason) =>
      AutoPlayerDecision(
        itemKey: itemKey,
        profile: profile,
        choice: choice,
        reason: reason,
      );

  if (titleChoice != null) return pick(titleChoice, AutoPlayerReason.title);
  if (!automatic) {
    return pick(
      PlayerChoice(
        settingPrefersMedia3 ? PlayerEngine.media3 : PlayerEngine.mpv,
      ),
      !settingPrefersMedia3 && bluetoothToMpv
          ? AutoPlayerReason.bluetooth
          : AutoPlayerReason.setting,
    );
  }
  if (sessionChoice != null) return pick(sessionChoice, AutoPlayerReason.stutter);
  final tunneling = media3Tunneling(profile);
  if (learned != null) {
    return pick(
      PlayerChoice(
        learned,
        tunneling: learned == PlayerEngine.media3 ? tunneling : null,
      ),
      AutoPlayerReason.learned,
    );
  }
  if (profile.heavy || profile.hdAudio) {
    return pick(
      PlayerChoice(PlayerEngine.media3, tunneling: tunneling),
      AutoPlayerReason.heavy,
    );
  }
  // mpv decodes in software here, which a TV can't do for 4K, so Bluetooth
  // only moves files that were going to mpv anyway (2026-10-22: Dune on a
  // headset stuttered on mpv and played cleanly on Media3 with tunneling).
  return pick(
    const PlayerChoice(PlayerEngine.mpv),
    bluetoothToMpv ? AutoPlayerReason.bluetooth : AutoPlayerReason.light,
  );
}

/// Counts dropped frames and audio underruns and says when playback has
/// stuttered enough to try the other engine. The first seconds after a start
/// or a seek are ignored: both engines drop a frame or two while settling.
class StutterMeter {
  StutterMeter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const settle = Duration(seconds: 12);
  static const window = Duration(seconds: 30);
  static const droppedFramesLimit = 24;
  static const underrunLimit = 4;

  DateTime _settledAt = DateTime.fromMillisecondsSinceEpoch(0);
  final _drops = <(DateTime, int)>[];
  final _underruns = <DateTime>[];

  void restart() {
    _settledAt = _clock().add(settle);
    _drops.clear();
    _underruns.clear();
  }

  /// True once the window holds enough trouble.
  bool addDroppedFrames(int count) {
    final now = _clock();
    if (now.isBefore(_settledAt) || count <= 0) return false;
    _drops.add((now, count));
    return _check(now);
  }

  bool addUnderrun() {
    final now = _clock();
    if (now.isBefore(_settledAt)) return false;
    _underruns.add(now);
    return _check(now);
  }

  bool _check(DateTime now) {
    final from = now.subtract(window);
    _drops.removeWhere((d) => d.$1.isBefore(from));
    _underruns.removeWhere((t) => t.isBefore(from));
    final dropped = _drops.fold<int>(0, (sum, d) => sum + d.$2);
    return dropped >= droppedFramesLimit || _underruns.length >= underrunLimit;
  }
}

/// Picks Media3 or mpv per film on Android TV, remembers the choice made in
/// the player menu per title and, after a stutter, what worked per kind of
/// file on this device.
class AutoPlayer {
  AutoPlayer(this._prefs, {StutterMeter? meter})
    : _meter = meter ?? StutterMeter() {
    instance = this;
  }

  /// The app's one instance, for the backends, which are built before it is
  /// handed around.
  static AutoPlayer? instance;

  final UserPreferences _prefs;
  final StutterMeter _meter;

  /// The decision behind the playback that is running now.
  AutoPlayerDecision? current;

  /// Fires once per playback when it stutters enough to try the other engine.
  final stutters = StreamController<AutoPlayerDecision>.broadcast();

  bool _reported = false;

  /// Android has both engines, so the player menu works there; the automatic
  /// choice is tuned for TVs and stays on Android TV.
  bool get available => PlatformDetection.isAndroid;

  bool get automatic =>
      available &&
      PlatformDetection.isTV &&
      _prefs.get(UserPreferences.autoPlayerEnabled);

  /// Engine picked after a stutter, per title, for the rest of this run.
  final _sessionChoices = <String, PlayerChoice>{};

  AutoPlayerDecision decide({
    required String itemKey,
    required List<Map<String, dynamic>> streams,
    int? selectedAudioStreamIndex,
  }) {
    final profile = FileProfile.of(
      streams,
      selectedAudioStreamIndex: selectedAudioStreamIndex,
    );
    final bluetooth =
        PlatformDetection.isTV &&
        _prefs.get(UserPreferences.mpvOnBluetooth) &&
        _prefs.detectedAudioCapabilities.activeRouteType ==
            AudioRouteType.bluetooth;
    final decision = decideAutoPlayer(
      itemKey: itemKey,
      profile: profile,
      automatic: automatic,
      settingPrefersMedia3: _prefs.prefersMedia3Now,
      bluetoothToMpv: bluetooth,
      titleChoice: available ? titleChoice(itemKey) : null,
      sessionChoice: _sessionChoices[itemKey],
      learned: _learned()[profile.key],
    );
    current = decision;
    _reported = false;
    _meter.restart();
    return decision;
  }

  /// Tunneling for the Media3 session that is starting, or null to follow the
  /// setting.
  bool? get sessionTunneling =>
      current?.choice.engine == PlayerEngine.media3
          ? current?.choice.tunneling
          : null;

  PlayerChoice? titleChoice(String itemKey) =>
      PlayerChoice.fromJson(_titleChoices()[itemKey]);

  Future<void> setTitleChoice(String itemKey, PlayerChoice? choice) async {
    final all = _titleChoices();
    if (choice == null) {
      all.remove(itemKey);
    } else {
      all[itemKey] = choice.toJson();
    }
    // Bounded: a long-lived TV should not grow this forever.
    while (all.length > 500) {
      all.remove(all.keys.first);
    }
    await _prefs.set(UserPreferences.autoPlayerTitleChoices, jsonEncode(all));
  }

  /// Hands [decision]'s title to the other engine for the rest of this run and
  /// remembers it for this kind of file. Returns the engine switched to.
  Future<PlayerEngine> switchAfterStutter(AutoPlayerDecision decision) async {
    final other = decision.choice.engine == PlayerEngine.media3
        ? PlayerEngine.mpv
        : PlayerEngine.media3;
    _sessionChoices[decision.itemKey] = PlayerChoice(
      other,
      tunneling: other == PlayerEngine.media3
          ? media3Tunneling(decision.profile)
          : null,
    );
    await learn(decision.profile.key, other);
    return other;
  }

  /// Remembers that [engine] is the one to start this kind of file with.
  Future<void> learn(String profileKey, PlayerEngine engine) async {
    final all = Map<String, dynamic>.from(_learnedRaw());
    all[profileKey] = engine.name;
    await _prefs.set(UserPreferences.autoPlayerLearned, jsonEncode(all));
  }

  /// A seek or a resume settles like a start.
  void settle() => _meter.restart();

  void reportDroppedFrames(int count) {
    if (_meter.addDroppedFrames(count)) _report();
  }

  void reportUnderrun() {
    if (_meter.addUnderrun()) _report();
  }

  /// The player never got going, or its picture froze: try the other engine
  /// at once. Unlike stutter this needs no counting (2026-10-25: Musk and
  /// MacGyver stood still on one engine and played on the other).
  void reportStall() => _report();

  void _report() {
    final decision = current;
    if (decision == null || _reported || !automatic) return;
    _reported = true;
    stutters.add(decision);
  }

  Map<String, dynamic> _titleChoices() =>
      _decode(_prefs.get(UserPreferences.autoPlayerTitleChoices));

  Map<String, dynamic> _learnedRaw() =>
      _decode(_prefs.get(UserPreferences.autoPlayerLearned));

  Map<String, PlayerEngine> _learned() {
    final out = <String, PlayerEngine>{};
    for (final e in _learnedRaw().entries) {
      final engine = PlayerEngine.values
          .where((v) => v.name == e.value)
          .firstOrNull;
      if (engine != null) out[e.key] = engine;
    }
    return out;
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return <String, dynamic>{};
  }
}
