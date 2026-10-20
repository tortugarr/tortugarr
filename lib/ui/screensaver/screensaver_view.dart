import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/services/youtube_stream_resolver.dart';
import '../../preference/preference_constants.dart';
import '../../preference/user_preferences.dart';
import '../../util/clock_format.dart';
import '../../util/platform_detection.dart';
import 'bouncing_box.dart';
import 'screensaver_content_service.dart';

/// Asset and box size (keeps the artwork's aspect) for each logo choice.
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
    if (_prefs.get(UserPreferences.screensaverMode) == ScreensaverMode.library) {
      _startSlideshow();
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSlideshow() async {
    // No logo splash first: the video mode shows only library content.
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
      precacheImage(
        CachedNetworkImageProvider(_items[_index + 1].backdropUrl),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _prefs.get(UserPreferences.screensaverMode);
    final dim = _prefs.get(UserPreferences.screensaverDimming).clamp(0, 90);
    final clockMode = _prefs.get(UserPreferences.screensaverClockMode);
    final videoMode = mode == ScreensaverMode.library && !_libraryEmpty;
    final showSlides = videoMode && _index >= 0;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showSlides)
            AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              child: _SlideView(
                key: ValueKey(_index),
                item: _items[_index],
                audio: _prefs.get(UserPreferences.screensaverAudio),
                onTrailerStarted: () => _onTrailerStarted(_index),
                onTrailerEnded: () => _onTrailerEnded(_index),
              ),
            )
          else if (!videoMode)
            _BouncingLogo(_prefs.get(UserPreferences.screensaverLogoImage)),
          if (dim > 0)
            ColoredBox(color: Colors.black.withValues(alpha: dim / 100)),
          if (clockMode != ScreensaverClockMode.off)
            _ScreensaverClock(
              bouncing: clockMode == ScreensaverClockMode.bouncing,
              opacity: 1 - (dim / 100) * 0.7,
              use24Hour: _prefs.get(UserPreferences.use24HourClock),
            ),
        ],
      ),
    );
  }
}

class _BouncingLogo extends StatelessWidget {
  const _BouncingLogo(this.image);

  final ScreensaverLogoImage image;

  @override
  Widget build(BuildContext context) {
    final logo = screensaverLogoAsset(image);
    return BouncingBox(
      childWidth: logo.width,
      childHeight: logo.height,
      child: Image.asset(logo.asset, fit: BoxFit.contain),
    );
  }
}

/// One library title: its backdrop with a slow zoom, and its trailer on top
/// once it plays. Muted unless the user turned on screensaver sound.
class _SlideView extends StatefulWidget {
  const _SlideView({
    super.key,
    required this.item,
    required this.audio,
    required this.onTrailerStarted,
    required this.onTrailerEnded,
  });

  final ScreensaverItem item;
  final bool audio;
  final VoidCallback onTrailerStarted;
  final VoidCallback onTrailerEnded;

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView>
    with SingleTickerProviderStateMixin {
  static const _resolveTimeout = Duration(seconds: 10);
  static const _openTimeout = Duration(seconds: 15);

  late final AnimationController _kenBurns;
  Player? _player;
  VideoController? _video;
  StreamSubscription<bool>? _completedSub;
  bool _videoVisible = false;

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
      if (!mounted || stream == null || stream.isEmpty) return;
      final player = Player(
        configuration: const PlayerConfiguration(libass: false),
      );
      _player = player;
      _video = VideoController(player);
      await player.setVolume(widget.audio ? 100 : 0);
      await player
          .open(videoId != null
              ? Media(stream, httpHeaders: YouTubeStreamResolver.youtubeHeaders)
              : Media(stream))
          .timeout(_openTimeout);
      if (!mounted) return;
      _completedSub = player.stream.completed.listen((done) {
        if (done && mounted) widget.onTrailerEnded();
      });
      setState(() => _videoVisible = true);
      widget.onTrailerStarted();
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
          scale: Tween<double>(begin: 1.0, end: 1.1).animate(_kenBurns),
          child: CachedNetworkImage(
            imageUrl: widget.item.backdropUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 500),
            placeholder: (_, _) => const ColoredBox(color: Colors.black),
            errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
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
                ? CachedNetworkImage(
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

class _ScreensaverClock extends StatefulWidget {
  const _ScreensaverClock({
    required this.bouncing,
    required this.opacity,
    required this.use24Hour,
  });

  final bool bouncing;
  final double opacity;
  final bool use24Hour;

  @override
  State<_ScreensaverClock> createState() => _ScreensaverClockState();
}

class _ScreensaverClockState extends State<_ScreensaverClock> {
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
    final text = Text(
      formatClockTime(DateTime.now(), use24Hour: widget.use24Hour),
      style: TextStyle(
        color: Colors.white.withValues(alpha: widget.opacity),
        fontSize: 32,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (widget.bouncing) {
      return BouncingBox(
        childWidth: 200,
        childHeight: 56,
        child: Center(child: text),
      );
    }
    return Align(
      alignment: Alignment.topRight,
      child: Padding(padding: const EdgeInsets.all(48), child: text),
    );
  }
}
