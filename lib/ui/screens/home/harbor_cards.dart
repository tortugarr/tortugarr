import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

/// Harbor home: a ranked card (top lists) with its big outlined number in the
/// gutter left of the poster, tucked under the poster's edge.
class HarborRankedCard extends StatelessWidget {
  const HarborRankedCard({
    super.key,
    required this.rank,
    required this.gutter,
    required this.imageHeight,
    required this.child,
  });

  final int rank;
  final double gutter;
  final double imageHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final digits = '$rank'.length;
    // Two-digit ranks are drawn smaller so they still fit the gutter.
    final size = imageHeight * (digits > 1 ? 0.62 : 0.86);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          width: gutter + imageHeight * 0.18,
          top: imageHeight - size * 0.95,
          child: IgnorePointer(
            child: Text(
              '$rank',
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: size,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -size * 0.06,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = (imageHeight / 70).clamp(2.0, 4.0)
                  ..color = AppColorScheme.accent.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        Padding(padding: EdgeInsets.only(left: gutter), child: child),
      ],
    );
  }
}

/// Harbor home: a collection (BoxSet) drawn as a small stack, two plain
/// plates fanned out behind its poster. Plates only, no extra images.
class HarborStackedCard extends StatelessWidget {
  const HarborStackedCard({
    super.key,
    required this.width,
    required this.imageHeight,
    required this.child,
  });

  final double width;
  final double imageHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = ThemeRegistry.active.borders.cardRadius;
    Widget plate(double angle, double alpha) => Positioned(
          left: 0,
          top: 0,
          width: width,
          height: imageHeight,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColorScheme.accent.withValues(alpha: 0.10),
                    AppColorScheme.surfaceVariant,
                  ).withValues(alpha: alpha),
                  borderRadius: radius,
                  border: Border.all(
                    color: AppColorScheme.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        plate(0.10, 0.55),
        plate(0.05, 0.85),
        child,
      ],
    );
  }
}
