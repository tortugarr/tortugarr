import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:server_core/server_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../auth/repositories/server_repository.dart';
import '../../../auth/repositories/session_repository.dart';
import '../../../auth/store/authentication_preferences.dart';
import '../../../auth/store/credential_store.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../util/pin_code_util.dart';
import '../../../preference/preference_constants.dart';
import '../../../preference/user_preferences.dart';
import '../../navigation/destinations.dart';
import '../../widgets/adaptive/adaptive_dialog.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/pin_entry_dialog.dart';
import '../../widgets/focus/request_initial_focus.dart';

class StartupScreen extends StatefulWidget {
  final bool bootstrapActiveSession;

  const StartupScreen({
    super.key,
    this.bootstrapActiveSession = false,
  });

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(seconds: 5);
  // media_kit copies an asset to the app's files once and reuses that copy, so
  // a new video needs a new file name: under the old name an updated app kept
  // playing the previous intro (2026-10-21).
  static const String _introAssetPath = 'assets/intro/tortugarr_intro_1080p.mp4';
  static const String _shortIntroAssetPath =
      'assets/intro/tortugarr_intro_short_1080p.mp4';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final DateTime _mountedAt;
  // media_kit, like the rest of the app's playback (Moonfin dropped the
  // video_player package).
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _completedSub;
  bool _videoReady = false;
  bool _videoFinished = false;
  bool _destinationReady = false;
  String? _destination;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _mountedAt = DateTime.now();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    _initVideo();
    _initialize();
  }

  Future<void> _initVideo() async {
    try {
      final player = Player();
      _player = player;
      _videoController = VideoController(player);
      _completedSub = player.stream.completed.listen((done) {
        if (done) _onVideoFinished();
      });
      await player.setPlaylistMode(PlaylistMode.none);
      await player.setVolume(100);
      final short = GetIt.instance.isRegistered<UserPreferences>() &&
          GetIt.instance<UserPreferences>().get(UserPreferences.shortIntro);
      await player.open(
        Media('asset:///${short ? _shortIntroAssetPath : _introAssetPath}'),
      );
      if (!mounted) return;
      setState(() => _videoReady = true);
    } catch (_) {
      // Asset missing or unsupported on this platform — fall through to the
      // normal splash hold so the app still boots.
      if (!mounted) return;
      _videoFinished = true;
      _maybeNavigate();
    }
  }

  void _onVideoFinished() {
    if (_videoFinished || !mounted) return;
    _videoFinished = true;
    _maybeNavigate();
  }

  void _skipVideo() {
    if (_videoFinished) return;
    _videoFinished = true;
    unawaited(_player?.pause());
    _maybeNavigate();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Only a fresh press skips the intro. Auto-repeats can arrive without the user
    // touching the remote (a key Android still thinks is held after a remapper
    // launched the app), and they used to cut the intro short.
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    _skipVideo();
    return KeyEventResult.handled;
  }

  void _enqueueDestination(String destination) {
    _destination = destination;
    _destinationReady = true;
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (_navigated) return;
    if (!_videoFinished || !_destinationReady) return;
    _navigated = true;
    final dest = _destination;
    if (dest != null && mounted) {
      context.go(dest);
    }
  }

  /// Wait so the splash stays on screen for at least [_minSplashDuration]
  /// after mount, regardless of how fast init completes. The video is ~10s,
  /// so the 5s floor is the video that ends up driving the timing in practice.
  Future<void> _holdSplash() async {
    final elapsed = DateTime.now().difference(_mountedAt);
    final remaining = _minSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) unawaited(player.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  /// On a cold boot the app can win the race against Wi-Fi association and
  /// see the device as offline for a few seconds. Waiting here keeps the
  /// splash up briefly instead of bouncing the user to the offline fallback.
  /// Once online, also settle server reachability (the boot-time check runs
  /// before a client exists) so home loads in the right online/offline mode.
  Future<void> _waitForNetworkSettle() async {
    final connectivity = GetIt.instance<ConnectivityService>();
    if (!connectivity.isOnline) {
      await connectivity.waitForOnline(const Duration(seconds: 5));
    }
    if (connectivity.isOnline &&
        GetIt.instance.isRegistered<MediaServerClient>()) {
      try {
        await connectivity.recheckNow();
      } catch (_) {}
    }
  }

  Future<void> _initialize() async {
    final session = GetIt.instance<SessionRepository>();
    final serverRepo = GetIt.instance<ServerRepository>();
    final credentialStore = GetIt.instance<CredentialStore>();
    final authPrefs = GetIt.instance<AuthenticationPreferences>();

    if (session.state != SessionState.ready) {
      // Never wait here forever. A session that cannot finish restoring would
      // otherwise hold the splash with nothing on screen to say why.
      await session.stateStream
          .firstWhere((s) => s == SessionState.ready)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => SessionState.ready,
          );
    }

    await serverRepo.loadStoredServers();

    if (widget.bootstrapActiveSession && session.activeUserId != null) {
      await _waitForNetworkSettle();
      await _holdSplash();
      if (!mounted) return;
      _enqueueDestination(Destinations.home);
      return;
    }

    final behavior = authPrefs.loginBehavior;
    String? targetUserId;

    // Always start with the last-used server as a universal fallback so that
    // any edge case where a behavior-specific ID is not set still lands on
    // the correct server's user-select page rather than the Add Server screen.
    String? targetServerId = authPrefs.savedLastServerId.isNotEmpty
        ? authPrefs.savedLastServerId
        : null;

    if (behavior == UserSelectBehavior.lastUser) {
      targetUserId = authPrefs.savedLastUserId;
    } else if (behavior == UserSelectBehavior.currentUser) {
      final autoServerId = authPrefs.savedAutoLoginServerId;
      if (autoServerId.isNotEmpty) targetServerId = autoServerId;
      targetUserId = authPrefs.savedAutoLoginUserId;
    }

    bool pinEnabledForAutoLoginUser = false;
    if (targetUserId != null && targetUserId.isNotEmpty) {
      final store = GetIt.instance<PreferenceStore>();
      final pinUtil = PinCodeUtil(store, targetUserId);
      pinEnabledForAutoLoginUser = pinUtil.isPinEnabled;
    }

    final restored = (authPrefs.shouldAlwaysAuthenticate || pinEnabledForAutoLoginUser)
        ? false
        : await session.restoreSession();

    if (!mounted) return;

    // Read the flag either way so a one-off failure doesn't carry over to the
    // next launch, but only warn when it cost the user something. A session
    // that came back has the token it needs and the warning is just noise.
    final storageFailed = credentialStore.consumeSecureStorageUnavailable();
    if (storageFailed && !(restored && session.activeUserId != null)) {
      await _showSecureStorageWarning();
      if (!mounted) return;
    }

    if (restored && session.activeUserId != null) {
      final store = GetIt.instance<PreferenceStore>();
      final pinUtil = PinCodeUtil(store, session.activeUserId!);

      if (pinUtil.isPinEnabled) {
        final verified = await PinEntryDialog.show(
          context,
          mode: PinEntryMode.verify,
          onVerify: pinUtil.verifyPin,
          onForgotPin: () {
            if (mounted) context.go(Destinations.serverSelect);
          },
        );

        if (!verified) {
          _enqueueDestination(Destinations.serverSelect);
          return;
        }
      }

      await _waitForNetworkSettle();
      await _holdSplash();
      if (!mounted) return;
      _enqueueDestination(Destinations.home);
    } else {
      await _holdSplash();
      if (!mounted) return;
      if (targetServerId != null && targetServerId.isNotEmpty) {
        // A previously-used server is known — go straight to user selection
        // for that server rather than the Add Server page.
        _enqueueDestination('${Destinations.server}?serverId=$targetServerId');
      } else {
        _enqueueDestination(Destinations.serverSelect);
      }
    }
  }

  Future<void> _showSecureStorageWarning() async {
    final l10n = AppLocalizations.of(context);
    await showFocusRestoringDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.secureStorageUnavailable),
        content: Text(
          l10n.secureStorageUnavailableMessage,
        ),
        actions: [
          adaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RequestInitialFocus(
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skipVideo,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _videoReady && _videoController != null
            ? FadeTransition(
                opacity: _fadeAnimation,
                child: Video(
                  controller: _videoController!,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                  fill: Colors.black,
                ),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
