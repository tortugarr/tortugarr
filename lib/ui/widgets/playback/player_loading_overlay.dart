import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/user_preferences.dart';

/// The loading logo's size factor for a stored percentage: 25–110 %, and
/// 100 % (today's size) when nothing is stored.
double loadingLogoScale(int? percent) => (percent ?? 100).clamp(25, 110) / 100;

double _storedLoadingLogoScale() {
  try {
    return loadingLogoScale(
      GetIt.instance<UserPreferences>().get(UserPreferences.loadingLogoScale),
    );
  } catch (_) {
    return 1.0;
  }
}

class PlayerLoadingOverlay extends StatefulWidget {
  const PlayerLoadingOverlay({
    super.key,
    this.label,
    this.logoSize = 180,
    this.labelSpacing = 60,
  });

  final String? label;
  final double logoSize;
  final double labelSpacing;

  @override
  State<PlayerLoadingOverlay> createState() => _PlayerLoadingOverlayState();
}

class _PlayerLoadingOverlayState extends State<PlayerLoadingOverlay>
    with TickerProviderStateMixin {
  static const _labelGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE50914), Color(0xFFFFC21A)], // red to yellow
  );

  late final AnimationController _logoController;
  late final AnimationController _labelController;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelScale;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _labelController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    final pulseCurve = CurvedAnimation(
      parent: _labelController,
      curve: Curves.easeInOut,
    );
    _labelOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(pulseCurve);
    _labelScale = Tween<double>(begin: 0.98, end: 1.0).animate(pulseCurve);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label?.trim();
    final hasLabel = label != null && label.isNotEmpty;
    final uppercaseLabel = hasLabel ? label.toUpperCase() : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _logoController,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_logoController.value * 2 * math.pi),
              child: child,
            );
          },
          child: Image.asset(
            'assets/icons/tortugarr_logo.png',
            // Round Tortugarr badge (about 1:1); a little larger than the old mark so the banner text reads.
            width: widget.logoSize * 1.15 * _storedLoadingLogoScale(),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        if (hasLabel) ...[
          SizedBox(height: widget.labelSpacing),
          FadeTransition(
            opacity: _labelOpacity,
            child: ScaleTransition(
              scale: _labelScale,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return _labelGradient.createShader(bounds);
                },
                child: Text(
                  uppercaseLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
