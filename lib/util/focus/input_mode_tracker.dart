import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform_detection.dart';

enum InputMode { keyboard, pointer }

class InputModeTracker extends StatefulWidget {
  final Widget child;
  const InputModeTracker({super.key, required this.child});

  static InputMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InputModeProvider>()?.mode ??
      _fallbackMode();

  static bool showFocusVisuals(BuildContext context, bool isFocused) =>
      isFocused && of(context) == InputMode.keyboard;

  /// Whether a pointer is the input being used right now.
  ///
  /// Deliberately *not* suppressed on TV the way [of] is. A mouse attached to
  /// a TV box -- screen mirroring, or a USB mouse -- really is being used, and
  /// a widget that draws hover state has to know. [of] stays pinned to
  /// keyboard there so focus visuals can never vanish for a remote user.
  ///
  /// Kept in its own inherited widget, so a pointer arriving or leaving
  /// rebuilds only those widgets and not every caller of [showFocusVisuals].
  static bool pointerIsLive(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_PointerLiveProvider>()
          ?.pointerLive ??
      false;

  static InputMode _fallbackMode() =>
      PlatformDetection.isTV ? InputMode.keyboard : InputMode.pointer;

  static Offset? _lastPointerDownPosition;

  /// Where the pointer last went down, which is where a menu the pointer asked
  /// for belongs. Null until a pointer has been used, so a remote or a touch
  /// gets the centered menu it expects.
  static Offset? get lastPointerDownPosition => _lastPointerDownPosition;

  static _InputModeTrackerState? _instance;

  @override
  State<InputModeTracker> createState() => _InputModeTrackerState();
}

class _InputModeTrackerState extends State<InputModeTracker> {
  late InputMode _mode;
  bool _pointerLive = false;

  @override
  void initState() {
    super.initState();
    _mode = InputModeTracker._fallbackMode();
    InputModeTracker._instance = this;
    _applyHighlightStrategy(_mode);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    if (InputModeTracker._instance == this) {
      InputModeTracker._instance = null;
    }
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _setPointerLive(false);
      _setMode(InputMode.keyboard);
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    _setPointerLive(true);
    _setMode(InputMode.pointer);
  }

  void _setPointerLive(bool live) {
    if (_pointerLive == live) return;
    setState(() => _pointerLive = live);
  }

  void _onPointerDown(PointerDownEvent event) {
    InputModeTracker._lastPointerDownPosition = event.position;
    _onPointer(event);
  }

  void _setMode(InputMode mode) {
    if (PlatformDetection.isTV && mode == InputMode.pointer) return;
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _applyHighlightStrategy(mode);
  }

  void _applyHighlightStrategy(InputMode mode) {
    FocusManager.instance.highlightStrategy = mode == InputMode.keyboard
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.automatic;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerHover: _onPointer,
      onPointerSignal: _onPointer,
      child: _InputModeProvider(
        mode: _mode,
        child: _PointerLiveProvider(
          pointerLive: _pointerLive,
          child: widget.child,
        ),
      ),
    );
  }
}

class _InputModeProvider extends InheritedWidget {
  final InputMode mode;
  const _InputModeProvider({required this.mode, required super.child});

  @override
  bool updateShouldNotify(covariant _InputModeProvider oldWidget) =>
      oldWidget.mode != mode;
}

class _PointerLiveProvider extends InheritedWidget {
  final bool pointerLive;
  const _PointerLiveProvider({required this.pointerLive, required super.child});

  @override
  bool updateShouldNotify(covariant _PointerLiveProvider oldWidget) =>
      oldWidget.pointerLive != pointerLive;
}
