import 'package:flutter_test/flutter_test.dart';
import 'package:playback_core/playback_core.dart';

// The issue #1672 file shape: the server numbers an external audio file ahead
// of the two tracks the container holds.
const _mediaStreams = <Map<String, dynamic>>[
  {'Index': 0, 'Type': 'Audio', 'IsExternal': true},
  {'Index': 1, 'Type': 'Video', 'IsExternal': false},
  {'Index': 2, 'Type': 'Audio', 'IsExternal': false, 'Codec': 'eac3'},
  {'Index': 3, 'Type': 'Audio', 'IsExternal': false, 'Codec': 'aac'},
];

// What a profile with AAC sent to the server for conversion looks like.
const _aacHeldBack = <String, dynamic>{
  'DirectPlayProfiles': [
    {'Type': 'Video', 'AudioCodec': 'ac3,eac3'},
    {'Type': 'Audio', 'AudioCodec': 'aac,ac3,eac3'},
  ],
};

class _TestBackend extends Fake implements PlayerBackend {
  final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[];
  final List<int> audioTracks = <int>[];
  Map<String, dynamic> profile = <String, dynamic>{};

  @override
  Duration get position => const Duration(seconds: 90);

  @override
  Duration get duration =>
      payloads.isEmpty ? Duration.zero : const Duration(minutes: 30);

  @override
  Duration get buffer => Duration.zero;

  @override
  bool get isPlaying => true;

  @override
  double get playbackSpeed => 1.0;

  @override
  bool get isBuffering => false;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferStream => const Stream<Duration>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get bufferingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Map<String, dynamic>>? get errorStream => null;

  @override
  bool get supportsRuntimeTrackSelection => false;

  @override
  bool get supportsDirectPlayAudioSwitch => true;

  @override
  bool get canRenderBitmapSubtitles => false;

  @override
  bool get demuxesEmbeddedSubtitles => true;

  @override
  bool get requiresStartupMediaReadyCheck => false;

  @override
  bool get nativelyHandlesStartPosition => true;

  @override
  Map<String, dynamic> getDeviceProfile({
    bool useProgressiveTranscode = false,
  }) => profile;

  @override
  Future<void> play(
    dynamic mediaItem, {
    Duration startPosition = Duration.zero,
  }) async {
    payloads.add(mediaItem as Map<String, dynamic>);
  }

  @override
  Future<void> setAudioTrack(int index) async => audioTracks.add(index);

  @override
  Future<void> disableSubtitleTrack() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSubtitleRendererMode(SubtitleRendererMode mode) async {}

  @override
  Future<void> waitForTracksReady() async {}

  @override
  void dispose() {}
}

class _TestResolver extends MediaStreamResolver {
  final List<int?> requestedAudio = <int?>[];
  final List<String?> requestedSources = <String?>[];
  int? serverDefaultAudio;

  @override
  Future<StreamResolutionResult> resolve(
    dynamic mediaItem, {
    Map<String, dynamic>? deviceProfile,
    int? maxStreamingBitrate,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? startTimeTicks,
    String? mediaSourceId,
    bool enableDirectPlay = true,
    bool enableDirectStream = true,
    bool enableTranscoding = true,
  }) async {
    requestedAudio.add(audioStreamIndex);
    requestedSources.add(mediaSourceId);
    return StreamResolutionResult(
      streamUrl: 'https://example.test/session-${requestedAudio.length}',
      mediaSourceId: 'movie',
      playSessionId: 'session-${requestedAudio.length}',
      playMethod: StreamPlayMethod.directPlay,
      mediaStreams: _mediaStreams,
      selectedAudioStreamIndex: serverDefaultAudio,
    );
  }
}

class _TestService extends Fake implements PlayerService {
  @override
  Future<void> onPlaybackStart(
    dynamic mediaItem,
    StreamResolutionResult resolution, {
    int? positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {}

  @override
  Future<void> onPlaybackProgress(
    dynamic mediaItem,
    StreamResolutionResult resolution,
    Duration position, {
    bool isPaused = false,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? volumeLevel,
    bool? isMuted,
  }) async {}

  @override
  Future<void> onPlaybackStop(
    dynamic mediaItem,
    StreamResolutionResult resolution,
    Duration position, {
    bool releaseLiveStream = true,
  }) async {}

  @override
  Future<void> closeLiveStream(String liveStreamId) async {}

  @override
  Future<void> stopTranscoding(StreamResolutionResult resolution) async {}

  @override
  void dispose() {}
}

void main() {
  late _TestBackend backend;
  late _TestResolver resolver;
  late PlaybackManager manager;

  setUp(() {
    backend = _TestBackend();
    resolver = _TestResolver();
    manager = PlaybackManager()
      ..setBackend(backend)
      ..setResolver(resolver)
      ..setPlayerService(_TestService());
  });

  tearDown(() => manager.dispose());

  Future<void> startPlayback({int? audioStreamIndex}) => manager.playItems(
    <dynamic>[
      <String, dynamic>{'Id': 'movie', 'Type': 'Movie'},
    ],
    audioStreamIndex: audioStreamIndex,
    audioSelectionExplicit: audioStreamIndex != null,
  );

  test('the first embedded track opens on the container first track', () async {
    await startPlayback(audioStreamIndex: 2);

    expect(backend.payloads.single['audioTrackOrdinal'], 1);
    expect(backend.audioTracks, everyElement(1));
  });

  test('switching to the second embedded track picks it in place', () async {
    await startPlayback(audioStreamIndex: 2);
    backend.audioTracks.clear();

    await manager.changeAudioTrack(3);

    expect(backend.audioTracks, isNotEmpty);
    expect(backend.audioTracks, everyElement(2));
    expect(resolver.requestedAudio, hasLength(1));
  });

  test('a track in a codec the profile no longer direct plays asks the '
      'server for it', () async {
    backend.profile = _aacHeldBack;
    await startPlayback(audioStreamIndex: 2);
    backend.audioTracks.clear();

    await manager.changeAudioTrack(3);

    expect(resolver.requestedAudio.last, 3);
    expect(backend.payloads, hasLength(2));
  });

  test('an unnamed track in a held back codec is named and '
      'asked again', () async {
    backend.profile = _aacHeldBack;
    resolver.serverDefaultAudio = 3;

    await startPlayback();

    expect(resolver.requestedAudio, <int?>[null, 3]);
    expect(resolver.requestedSources.last, 'movie');
  });

  test('an unnamed track in a codec video still plays is not '
      'asked again', () async {
    backend.profile = _aacHeldBack;
    resolver.serverDefaultAudio = 2;

    await startPlayback();

    expect(resolver.requestedAudio, <int?>[null]);
  });

  test('a named track goes again with its source when the server judged '
      'a held back default', () async {
    backend.profile = _aacHeldBack;
    resolver.serverDefaultAudio = 3;

    await startPlayback(audioStreamIndex: 2);

    expect(resolver.requestedAudio, <int?>[2, 2]);
    expect(resolver.requestedSources, <String?>[null, 'movie']);
  });

  test('switching to the external file asks the server for it', () async {
    await startPlayback(audioStreamIndex: 2);
    backend.audioTracks.clear();

    await manager.changeAudioTrack(0);

    expect(resolver.requestedAudio.last, 0);
    expect(backend.payloads, hasLength(2));
    expect(backend.audioTracks, isNot(contains(1)));
  });
}
