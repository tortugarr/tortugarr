import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../util/platform_detection.dart';

/// The item's name drawn in place of its logo, for items that have no logo
/// image or whose logo fails to load. Each layout passes its own [shadows] so
/// the text sits against its backdrop the same way the rest of that layout does.
class MediaBarTitle extends StatelessWidget {
  const MediaBarTitle({super.key, required this.title, required this.shadows});

  final String title;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = PlatformDetection.useMobileUi
        ? theme.textTheme.titleLarge
        : theme.textTheme.headlineMedium;
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(
        color: AppColorScheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.05,
        shadows: shadows,
      ),
    );
  }
}
