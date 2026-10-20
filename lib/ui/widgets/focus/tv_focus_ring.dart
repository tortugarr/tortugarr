import 'package:flutter/material.dart';

/// Draws a clear ring around whatever has focus inside [child].
///
/// Screens built for touch (the admin pages) rely on Material's focus
/// overlays, which are close to invisible on a dark TV theme. Instead of
/// restyling every widget, this follows [FocusManager.primaryFocus] and
/// outlines it, so any focusable widget is visible from the couch.
class TvFocusRing extends StatefulWidget {
  final Widget child;

  const TvFocusRing({super.key, required this.child});

  /// Strong focus overlays for Material buttons, for dialogs opened from
  /// inside a [TvFocusRing] (they render outside it but inherit the theme).
  static ThemeData theme(ThemeData base) {
    final overlay = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.focused)
          ? Colors.white.withValues(alpha: 0.3)
          : null,
    );
    ButtonStyle withFocus(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(overlayColor: overlay);
    return base.copyWith(
      focusColor: Colors.white.withValues(alpha: 0.3),
      textButtonTheme:
          TextButtonThemeData(style: withFocus(base.textButtonTheme.style)),
      filledButtonTheme:
          FilledButtonThemeData(style: withFocus(base.filledButtonTheme.style)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: withFocus(base.elevatedButtonTheme.style)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: withFocus(base.outlinedButtonTheme.style)),
      iconButtonTheme:
          IconButtonThemeData(style: withFocus(base.iconButtonTheme.style)),
    );
  }

  @override
  State<TvFocusRing> createState() => _TvFocusRingState();
}

class _TvFocusRingState extends State<TvFocusRing> {
  final _stackKey = GlobalKey();
  Rect? _rect;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleUpdate);
    _scheduleUpdate();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleUpdate);
    super.dispose();
  }

  /// Measure after layout: focus changes and scrolling both move the target.
  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _update();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _update() {
    Rect? next;
    final ctx = FocusManager.instance.primaryFocus?.context;
    final stackBox = _stackKey.currentContext?.findRenderObject();
    if (ctx != null &&
        ctx.mounted &&
        stackBox is RenderBox &&
        ctx.findAncestorStateOfType<_TvFocusRingState>() == this) {
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final topLeft = box.localToGlobal(Offset.zero, ancestor: stackBox);
        final rect = topLeft & box.size;
        // A focused page or scroll view would just frame the whole screen.
        final covers = rect.width >= stackBox.size.width * 0.9 &&
            rect.height >= stackBox.size.height * 0.6;
        if (!covers) next = rect;
      }
    }
    if (next != _rect) setState(() => _rect = next);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleUpdate();
        return false;
      },
      child: Stack(
        key: _stackKey,
        children: [
          widget.child,
          if (rect != null)
            Positioned.fromRect(
              rect: rect.inflate(3),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
