import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/services/youtube_stream_resolver.dart';
import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../../util/artwork_timing.dart';
import '../../util/clock_format.dart';
import '../../util/platform_detection.dart';
import '../widgets/offline_aware_image.dart';
import '../widgets/playback/loading_animation_widget.dart';
import 'bouncing_box.dart';
import 'screensaver_content_service.dart';
import 'screensaver_gradient_backdrops.dart';

/// Asset and box size (keeps the artwork's aspect) for each Tortugarr logo
/// choice. The logo component shows the chosen one.
({String asset, double width, double height}) screensaverLogoAsset(
  ScreensaverLogoImage image,
) =>
    switch (image) {
      ScreensaverLogoImage.badge =>
        (asset: 'assets/images/screensaver_badge.png', width: 320, height: 326),
      ScreensaverLogoImage.vhs =>
        (asset: 'assets/images/screensaver_vhs.png', width: 420, height: 305),
      ScreensaverLogoImage.sign =>
        (asset: 'assets/images/screensaver_sign.png', width: 400, height: 361),
    };

class ScreensaverView extends StatefulWidget {
  const ScreensaverView({super.key});

  @override
  State<ScreensaverView> createState() => _ScreensaverViewState();
}

class _ScreensaverViewState extends State<ScreensaverView> {
  /// How long a slide without a trailer stays up.
  static const _slideDuration = Duration(seconds: 30);

  /// A trailer that never reports completion still moves on after this.
  static const _maxTrailerDuration = Duration(minutes: 3);

  final _prefs = GetIt.instance<UserPreferences>();
  late final ScreensaverContentService _service;

  List<ScreensaverItem> _items = const [];
  int _index = -1;
  bool _libraryEmpty = false;
  Timer? _slideTimer;

  @override
  void initState() {
    super.initState();
    _service = ScreensaverContentService(_prefs);
    if (_prefs.get(UserPreferences.screensaverBackdrop) ==
        ScreensaverBackdrop.library) {
      _startSlideshow();
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSlideshow() async {
    // No logo splash first: the library backdrop shows only library content.
    final items = await _service.loadBatch();
    if (!mounted) return;
    if (items.isEmpty) {
      setState(() => _libraryEmpty = true);
      return;
    }
    setState(() {
      _items = items;
      _index = 0;
    });
    _precacheNext();
    _scheduleAdvance(_slideDuration);
  }

  void _scheduleAdvance(Duration after) {
    _slideTimer?.cancel();
    _slideTimer = Timer(after, _advance);
  }

  void _onTrailerStarted(int index) {
    if (!mounted || index != _index) return;
    _scheduleAdvance(_maxTrailerDuration);
  }

  void _onTrailerEnded(int index) {
    if (!mounted || index != _index) return;
    _advance();
  }

  Future<void> _advance() async {
    if (!mounted || _items.isEmpty) return;
    if (_index + 1 >= _items.length) {
      final items = await _service.loadBatch();
      if (!mounted) return;
      if (items.isNotEmpty) {
        setState(() {
          _items = items;
          _index = 0;
        });
        _precacheNext();
        _scheduleAdvance(_slideDuration);
        return;
      }
      setState(() => _index = 0);
      _scheduleAdvance(_slideDuration);
      return;
    }
    setState(() => _index++);
    _precacheNext();
    _scheduleAdvance(_slideDuration);
  }

  void _precacheNext() {
    if (_index + 1 < _items.length) {
      ArtworkDecode.precache(
        context,
        _items[_index + 1].backdropUrl,
        layoutWidth: MediaQuery.sizeOf(context).width,
        layoutHeight: MediaQuery.sizeOf(context).height,
        sourceAspectRatio: 16 / 9,
        scale: ScreensaverSlide.kenBurnsScale,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = _prefs.get(UserPreferences.screensaverBackdrop);
    final dim = _prefs.get(UserPreferences.screensaverDimming).clamp(0, 90);
    final component = _prefs.get(UserPreferences.screensaverComponent);
    final movement = _prefs.get(UserPreferences.screensaverMovement);
    final position = _prefs.get(UserPreferences.screensaverPosition);
    final size = _prefs.get(UserPreferences.screensaverSize);

    final showSlides =
        backdrop == ScreensaverBackdrop.library &&
        !_libraryEmpty &&
        _index >= 0;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop layer
          if (showSlides)
            AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              child: ScreensaverSlide(
                key: ValueKey(_index),
                item: _items[_index],
                audio: _prefs.get(UserPreferences.screensaverAudio),
                onTrailerStarted: () => _onTrailerStarted(_index),
                onTrailerEnded: () => _onTrailerEnded(_index),
              ),
            )
          else if (backdrop == ScreensaverBackdrop.moonfin ||
              backdrop == ScreensaverBackdrop.calm ||
              backdrop == ScreensaverBackdrop.neonPulse ||
              backdrop == ScreensaverBackdrop.aurora)
            AnimatedGradientBackdrop(backdrop: backdrop)
          else
            const ColoredBox(color: Colors.black),

          // Dimming layer
          if (dim > 0)
            ColoredBox(color: Colors.black.withValues(alpha: dim / 100)),

          // Additional Component layer
          if (component != ScreensaverComponent.none)
            _buildAdditionalComponent(
              component: component,
              movement: movement,
              position: position,
              size: size,
              dim: dim,
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalComponent({
    required ScreensaverComponent component,
    required ScreensaverMovement movement,
    required ScreensaverPosition position,
    required ScreensaverSize size,
    required int dim,
  }) {
    if (component == ScreensaverComponent.none) {
      return const SizedBox.shrink();
    }

    final scale = size.scaleFactor;
    final logo =
        screensaverLogoAsset(_prefs.get(UserPreferences.screensaverLogoImage));
    final (double width, double height) = switch (component) {
      ScreensaverComponent.none => (0.0, 0.0),
      ScreensaverComponent.moonfinLogo =>
        (logo.width * scale, logo.height * scale),
      ScreensaverComponent.clock => (200.0 * scale, 56.0 * scale),
      ScreensaverComponent.runner => (120.0 * scale, 120.0 * scale),
    };

    Widget renderContent({required bool movingLeft}) {
      switch (component) {
        case ScreensaverComponent.none:
          return const SizedBox.shrink();
        case ScreensaverComponent.moonfinLogo:
          return Image.asset(logo.asset, fit: BoxFit.contain);
        case ScreensaverComponent.clock:
          return ScreensaverClock(
            opacity: 1 - (dim / 100) * 0.7,
            use24Hour: _prefs.get(UserPreferences.use24HourClock),
            fontSize: 32 * scale,
          );
        case ScreensaverComponent.runner:
          return Center(
            child: RunnerAnimation(
              size: 96 * scale,
              flipHorizontal: movingLeft,
              speed: movement.loadingSpeed,
            ),
          );
      }
    }

    if (movement.isBouncing) {
      return BouncingBox(
        childWidth: width,
        childHeight: height,
        speedMultiplier: movement.speedMultiplier,
        builder: (context, movingLeft) => renderContent(movingLeft: movingLeft),
      );
    }

    return Align(
      alignment: position.alignment,
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: SizedBox(
          width: width,
          height: height,
          child: renderContent(movingLeft: false),
        ),
      ),
    );
  }
}

extension ScreensaverPositionX on ScreensaverPosition {
  Alignment get alignment => switch (this) {
        ScreensaverPosition.topLeft => Alignment.topLeft,
        ScreensaverPosition.topCenter => Alignment.topCenter,
        ScreensaverPosition.topRight => Alignment.topRight,
        ScreensaverPosition.middleLeft => Alignment.centerLeft,
        ScreensaverPosition.middle => Alignment.center,
        ScreensaverPosition.middleRight => Alignment.centerRight,
        ScreensaverPosition.bottomLeft => Alignment.bottomLeft,
        ScreensaverPosition.bottomCenter => Alignment.bottomCenter,
        ScreensaverPosition.bottomRight => Alignment.bottomRight,
      };
}

extension ScreensaverSizeX on ScreensaverSize {
  double get scaleFactor => switch (this) {
        ScreensaverSize.thumbnail => 0.45,
        ScreensaverSize.small => 0.70,
        ScreensaverSize.medium => 1.0,
        ScreensaverSize.large => 1.5,
      };
}


/// One slide of the library screensaver. Public only so a test can drive
/// its failure path.
@visibleForTesting
class ScreensaverSlide extends StatefulWidget {
  /// Where the Ken Burns zoom ends.
  static const kenBurnsScale = 1.1;

  const ScreensaverSlide({
    super.key,
    required this.item,
    this.audio = false,
    this.onTrailerStarted,
    this.onTrailerEnded,
  });

  final ScreensaverItem item;

  /// The trailer plays over the backdrop, muted unless this is set.
  final bool audio;
  final VoidCallback? onTrailerStarted;
  final VoidCallback? onTrailerEnded;

  @override
  State<ScreensaverSlide> createState() => _ScreensaverSlideState();
}

class _ScreensaverSlideState extends State<ScreensaverSlide>
    with SingleTickerProviderStateMixin {
  static const _resolveTimeout = Duration(seconds: 10);
  static const _openTimeout = Duration(seconds: 15);

  late final AnimationController _kenBurns;
  bool _reportedFailure = false;
  Player? _player;
  VideoController? _video;
  StreamSubscription<bool>? _completedSub;
  bool _videoVisible = false;

  /// The error builder runs during build and the log notifies its listeners
  /// at once, so the report waits for the frame to end rather than marking
  /// another screen dirty mid build. Once per slide, since the builder runs
  /// again on every rebuild of the failed image.
  void _reportFailure(String url, Object error) {
    if (_reportedFailure) return;
    _reportedFailure = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ArtworkTimings.screensaverSlideFailed(url, error);
    });
  }

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();
    final trailer = widget.item.trailerUrl;
    if (trailer != null &&
        !kIsWeb &&
        !PlatformDetection.useApplePreviewPlayer) {
      unawaited(_playTrailer(trailer));
    }
  }

  Future<void> _playTrailer(String trailerUrl) async {
    try {
      final videoId = YouTubeStreamResolver.extractVideoId(trailerUrl);
      final stream = await YouTubeStreamResolver.resolveFromUrl(trailerUrl)
          .timeout(_resolveTimeout, onTimeout: () => null);
      final url = stream?.url;
      if (!mounted || url == null || url.isEmpty) return;
      final player = Player(
        configuration: const PlayerConfiguration(libass: false),
      );
      _player = player;
      _video = VideoController(player);
      await player.setVolume(widget.audio ? 100 : 0);
      // The trailer's own soundtrack, not a machine dub (as the trailer player).
      await YouTubeStreamResolver.preferAudioLanguage(
        player,
        stream?.audioLanguage,
      );
      await player
          .open(videoId != null
              ? Media(url, httpHeaders: YouTubeStreamResolver.youtubeHeaders)
              : Media(url))
          .timeout(_openTimeout);
      if (!mounted) return;
      _completedSub = player.stream.completed.listen((done) {
        if (done && mounted) widget.onTrailerEnded?.call();
      });
      setState(() => _videoVisible = true);
      widget.onTrailerStarted?.call();
    } catch (_) {
      // No trailer: the backdrop stays, and the slide moves on after its time.
    }
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    final player = _player;
    _player = null;
    if (player != null) unawaited(player.dispose());
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Stack(
      fit: StackFit.expand,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 1.0,
            end: ScreensaverSlide.kenBurnsScale,
          ).animate(_kenBurns),
          child: OfflineAwareImage(
            imageUrl: widget.item.backdropUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            // The zoom ends at kenBurnsScale, so decode for that size or the
            // last seconds of every slide paint an upscaled frame.
            sourceAspectRatio: 16 / 9,
            decodeScale: ScreensaverSlide.kenBurnsScale,
            placeholder: (_, _) => const ColoredBox(color: Colors.black),
            errorWidget: (_, url, error) {
              _reportFailure(url, error);
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
        if (video != null)
          AnimatedOpacity(
            opacity: _videoVisible ? 1 : 0,
            duration: const Duration(milliseconds: 800),
            child: Video(
              controller: video,
              controls: NoVideoControls,
              fit: BoxFit.cover,
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [Color(0x33000000), Color(0xB3000000)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: widget.item.logoUrl != null
                ? OfflineAwareImage(
                    imageUrl: widget.item.logoUrl!,
                    width: 400,
                    height: 120,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => _SlideTitle(widget.item.name),
                  )
                : _SlideTitle(widget.item.name),
          ),
        ),
      ],
    );
  }
}

class _SlideTitle extends StatelessWidget {
  const _SlideTitle(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class ScreensaverClock extends StatefulWidget {
  const ScreensaverClock({
    super.key,
    required this.opacity,
    required this.use24Hour,
    this.fontSize = 32,
  });

  final double opacity;
  final bool use24Hour;
  final double fontSize;

  @override
  State<ScreensaverClock> createState() => _ScreensaverClockState();
}

class _ScreensaverClockState extends State<ScreensaverClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        formatClockTime(DateTime.now(), use24Hour: widget.use24Hour),
        style: TextStyle(
          color: Colors.white.withValues(alpha: widget.opacity),
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
