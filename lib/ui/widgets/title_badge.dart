import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/services/tortugarr/title_badges.dart';
import '../../preference/user_preferences.dart';

Color _hex(String v, Color fallback) {
  final h = v.replaceAll('#', '').trim();
  final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return n == null ? fallback : Color(n);
}

Alignment _corner(String v) => switch (v) {
  'topRight' => Alignment.topRight,
  'bottomLeft' => Alignment.bottomLeft,
  'bottomRight' => Alignment.bottomRight,
  _ => Alignment.topLeft,
};

double _scale(String v) => switch (v) {
  'small' => 0.8,
  'large' => 1.3,
  _ => 1.0,
};

/// The BB / MB chip and, for series, the network logo box, laid over a
/// poster. Follows Settings > Appearance > Poster badges. Rebuilds when the
/// badge facts arrive.
class TitleBadgeOverlay extends StatelessWidget {
  const TitleBadgeOverlay({super.key, required this.item, this.size = 1.0});

  final AggregatedItem item;

  /// Extra scale, e.g. smaller on small cards.
  final double size;

  @override
  Widget build(BuildContext context) {
    final prefs = GetIt.instance<UserPreferences>();
    return ListenableBuilder(
      listenable: Listenable.merge([TitleBadges.instance, prefs]),
      builder: (context, _) {
        if (!prefs.get(UserPreferences.tgBadgesEnabled))
          return const SizedBox.shrink();
        final info = TitleBadges.instance.infoFor(item);
        if (info == null) return const SizedBox.shrink();
        final s = _scale(prefs.get(UserPreferences.tgBadgeSize)) * size;
        final children = <Widget>[];
        if (info.kind != TitleClass.plain) {
          final mb = info.kind == TitleClass.mockbuster;
          final base = _hex(
            prefs.get(
              mb ? UserPreferences.tgMbColor : UserPreferences.tgBbColor,
            ),
            mb ? const Color(0xFFE0703A) : const Color(0xFFD9B44A),
          );
          final bg = base.withValues(
            alpha: prefs.get(UserPreferences.tgBadgeOpacity) / 100,
          );
          final fg = base.computeLuminance() > 0.45
              ? const Color(0xFF14100C)
              : Colors.white;
          children.add(
            Align(
              alignment: _corner(prefs.get(UserPreferences.tgBadgeCorner)),
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4 * s),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * s,
                      vertical: 2 * s,
                    ),
                    child: Text(
                      mb ? 'MB' : 'BB',
                      style: TextStyle(
                        color: fg,
                        fontSize: 12 * s,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        final logo = info.networkLogo;
        if (logo != null && prefs.get(UserPreferences.tgNetworkLogos)) {
          final box =
              _hex(
                prefs.get(UserPreferences.tgNetworkBoxColor),
                Colors.black,
              ).withValues(
                alpha: prefs.get(UserPreferences.tgNetworkOpacity) / 100,
              );
          children.add(
            Align(
              alignment: _corner(prefs.get(UserPreferences.tgNetworkCorner)),
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: box,
                    borderRadius: BorderRadius.circular(6 * s),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * s,
                      vertical: 4 * s,
                    ),
                    // Wide logos (Broken Lizard) are capped in width, so no logo
                    // covers more than a corner of the poster.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 58 * s,
                        maxHeight: 16 * s,
                      ),
                      child: Image.network(
                        logo,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => Text(
                          info.network ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (children.isEmpty) return const SizedBox.shrink();
        return IgnorePointer(
          child: Stack(fit: StackFit.expand, children: children),
        );
      },
    );
  }
}

/// Whether [item] should be hidden because it is a mockbuster and the user
/// switched mockbusters off. Unknown titles stay.
bool hideAsMockbuster(AggregatedItem item) {
  final prefs = GetIt.instance<UserPreferences>();
  if (prefs.get(UserPreferences.tgShowMockbusters)) return false;
  return TitleBadges.instance.infoFor(item)?.kind == TitleClass.mockbuster;
}
