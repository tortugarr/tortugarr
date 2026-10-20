import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:server_core/server_core.dart';
import 'package:video_player/video_player.dart';

import '../../../auth/repositories/server_repository.dart';
import '../../../auth/repositories/session_repository.dart';
import '../../../auth/store/authentication_preferences.dart';
import '../../../auth/store/credential_store.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../util/pin_code_util.dart';
import '../../../preference/preference_constants.dart';
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
  static const String _introAssetPath = 'assets/intro/tortugarr_intro.mp4';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final DateTime _mountedAt;
  VideoPlayerController? _videoController;
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
    final controller = VideoPlayerController.asset(_introAssetPath);
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      controller.addListener(_onVideoTick);
      await controller.play();
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

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || _videoFinished) return;
    final v = c.value;
    if (!v.isInitialized) return;
    if (v.duration > Duration.zero && v.position >= v.duration) {
      _videoFinished = true;
      _maybeNavigate();
    }
  }

  void _skipVideo() {
    if (_videoFinished) return;
    _videoFinished = true;
    _videoController?.pause();
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
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
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
      await session.stateStream.firstWhere((s) => s == SessionState.ready);
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

    if (credentialStore.consumeSecureStorageUnavailable()) {
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
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width == 0
                        ? 1
                        : _videoController!.value.size.width,
                    height: _videoController!.value.size.height == 0
                        ? 1
                        : _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
