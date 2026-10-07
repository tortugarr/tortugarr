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

  static InputMode _fallbackMode() =>
      PlatformDetection.isTV ? InputMode.keyboard : InputMode.pointer;

  static _InputModeTrackerState? _instance;

  @override
  State<InputModeTracker> createState() => _InputModeTrackerState();
}

class _InputModeTrackerState extends State<InputModeTracker> {
  late InputMode _mode;

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
      _setMode(InputMode.keyboard);
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    _setMode(InputMode.pointer);
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
      onPointerDown: _onPointer,
      onPointerHover: _onPointer,
      onPointerSignal: _onPointer,
      child: _InputModeProvider(mode: _mode, child: widget.child),
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
