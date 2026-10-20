import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../preference/preference_constants.dart';
import '../../../preference/user_preferences.dart';
import 'loading_animation_widget.dart';

/// The loading logo's size factor for a stored percentage: 25-100 %, and
/// 45 % when nothing is stored. 100 % was the size before 2026-10-21, which
/// was too large on the TV.
double loadingLogoScale(int? percent) =>
    (percent ?? UserPreferences.loadingLogoScale.defaultValue).clamp(25, 100) / 100;

class PlayerLoadingOverlay extends StatefulWidget {
  const PlayerLoadingOverlay({
    super.key,
    this.label,
    this.labelSpacing,
    this.customImage,
    this.customSize,
    this.customPosition,
    this.customShowText,
    this.customSpeed,
    this.flipHorizontal,
  });

  final String? label;
  final double? labelSpacing;
  final LoadingAnimationImage? customImage;
  final double? customSize;
  final LoadingAnimationPosition? customPosition;
  final bool? customShowText;
  final LoadingAnimationSpeed? customSpeed;
  final bool? flipHorizontal;

  @override
  State<PlayerLoadingOverlay> createState() => _PlayerLoadingOverlayState();
}

class _PlayerLoadingOverlayState extends State<PlayerLoadingOverlay>
    with SingleTickerProviderStateMixin {
  static const _labelGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE50914), Color(0xFFFFC21A)], // red to yellow
  );

  late final AnimationController _labelController;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelScale;

  @override
  void initState() {
    super.initState();
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
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = GetIt.instance.isRegistered<UserPreferences>()
        ? GetIt.instance<UserPreferences>()
        : null;

    final image = widget.customImage ??
        prefs?.get(UserPreferences.loadingAnimationImage) ??
        LoadingAnimationImage.moonfinLogo;

    // One size setting, Tortugarr's Loading logo size, in percent of the
    // medium size; the small/medium/large choice is not offered.
    const sizePref = LoadingAnimationSize.medium;

    final effectiveSize = widget.customSize ??
        sizePref.pixelSize * loadingLogoScale(prefs?.get(UserPreferences.loadingLogoScale));

    final effectivePosition = widget.customPosition ??
        prefs?.get(UserPreferences.loadingAnimationPosition) ??
        LoadingAnimationPosition.middle;

    final showText = widget.customShowText ??
        prefs?.get(UserPreferences.showLoadingAnimationText) ??
        true;

    final effectiveSpeed = widget.customSpeed ??
        prefs?.get(UserPreferences.loadingAnimationSpeed) ??
        LoadingAnimationSpeed.fast;

    final label = widget.label?.trim();
    final hasLabel = showText && label != null && label.isNotEmpty;
    final uppercaseLabel = hasLabel ? label.toUpperCase() : null;

    if (image == LoadingAnimationImage.none && !hasLabel) {
      return const SizedBox.shrink();
    }

    final spacing = widget.labelSpacing ?? sizePref.labelSpacing;
    final fontSize = sizePref.labelFontSize;
    final letterSpacing = sizePref.labelLetterSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (image != LoadingAnimationImage.none)
          // Repaints every frame, so it gets a layer of its own.
          RepaintBoundary(
            child: LoadingAnimationWidget(
              image: image,
              size: effectiveSize,
              position: effectivePosition,
              flipHorizontal: widget.flipHorizontal,
              speed: effectiveSpeed,
            ),
          ),
        if (hasLabel) ...[
          if (image != LoadingAnimationImage.none) SizedBox(height: spacing),
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
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: letterSpacing,
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
