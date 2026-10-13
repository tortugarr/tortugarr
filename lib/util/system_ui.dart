import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The one owner of the system bars.
///
/// A screen holds a claim on immersive for as long as it wants the bars gone,
/// and the bars come back when the last claim is released. Releasing a claim
/// that is not held does nothing, so a screen can release from every exit path
/// without keeping count.
abstract final class SystemUi {
  static const _transparent = Color(0x00000000);

  static final Set<Object> _claims = Set.identity();
  static _ResumeObserver? _observer;

  @visibleForTesting
  static Future<void> Function(SystemUiMode mode) apply =
      SystemChrome.setEnabledSystemUIMode;

  static bool get immersive => _claims.isNotEmpty;

  static void install() {
    if (_observer != null) return;
    WidgetsBinding.instance.addObserver(_observer = _ResumeObserver());
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    unawaited(_sync());
  }

  /// Applies even when the owner already holds a claim, because Android drops
  /// immersive on its own in cases like picture in picture and a screen coming
  /// back from one wants the bars gone again.
  static void hold(Object owner) {
    _claims.add(owner);
    unawaited(_sync());
  }

  static void release(Object owner) {
    if (_claims.remove(owner)) unawaited(_sync());
  }

  static Future<void> _sync() =>
      apply(immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);

  @visibleForTesting
  static void reset() {
    final observer = _observer;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    _observer = null;
    _claims.clear();
    apply = SystemChrome.setEnabledSystemUIMode;
  }
}

/// Android can reset the window flags while the app sits in the background, so
/// the mode is applied again every time the app comes back.
class _ResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(SystemUi._sync());
  }
}

/// Mix into a screen that hides the bars. The claim goes with the state, so a
/// screen that is popped, replaced or torn down by an error never leaves the
/// bars hidden behind it.
mixin ImmersiveSystemUi<T extends StatefulWidget> on State<T> {
  void setImmersive(bool immersive) =>
      immersive ? SystemUi.hold(this) : SystemUi.release(this);

  @override
  void dispose() {
    SystemUi.release(this);
    super.dispose();
  }
}
