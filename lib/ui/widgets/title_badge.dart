import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/services/tortugarr/title_badges.dart';
import '../../data/viewmodels/seerr_discover_view_model.dart';
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
        final icon = info.network == null
            ? null
            : providerIconUrl(info.network!);
        final curated = info.network == null
            ? null
            : curatedLogoUrl(info.network!);
        if (prefs.get(UserPreferences.tgNetworkLogos) &&
            prefs.get(UserPreferences.tgLogoStyle) == 'icon' &&
            icon != null) {
          // A streaming service's own square app icon in the corner.
          children.add(
            Align(
              alignment: _corner(prefs.get(UserPreferences.tgNetworkCorner)),
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: Opacity(
                  opacity: (prefs.get(UserPreferences.tgNetworkOpacity) / 100)
                      .clamp(0.3, 1.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5 * s),
                    child: Image.network(
                      icon,
                      width: 22 * s,
                      height: 22 * s,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else if (curated != null &&
            prefs.get(UserPreferences.tgNetworkLogos)) {
          // The white logo from the app's Networks / Studios rows, small, in
          // its own proportions, on a dark box.
          children.add(
            Align(
              alignment: _corner(prefs.get(UserPreferences.tgNetworkCorner)),
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha:
                          (prefs.get(UserPreferences.tgNetworkOpacity) / 100) *
                          0.7,
                    ),
                    borderRadius: BorderRadius.circular(5 * s),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5 * s,
                      vertical: 4 * s,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 56 * s,
                        maxHeight: 14 * s,
                      ),
                      child: Image.network(
                        curated,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else if (logo != null && prefs.get(UserPreferences.tgNetworkLogos)) {
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

/// The streaming service's real app icon (TMDB watch-provider logos, square)
/// for a studio or network that is one of them, or null. Used as the small
/// mark on cards: Netflix's N, Disney+, Apple TV+, Prime Video, HBO Max,
/// SkyShowtime.
String? providerIconUrl(String name) {
  const base = 'https://image.tmdb.org/t/p/w92';
  final n = name.trim().toLowerCase();
  if (n.startsWith('netflix')) return '$base/rK1KljqmbvO9HQa1PBFLILWah72.png';
  if (n.startsWith('disney') || n.startsWith('walt disney'))
    return '$base/5eZ872CghnHFLB1j8grszbrx0dx.png';
  if (n.startsWith('apple')) return '$base/9icYBfYFcwgCbky5VdGUIKJ4C5i.png';
  if (n.startsWith('amazon') || n.startsWith('prime video'))
    return '$base/gMZdpavHmxFNnLpMHwVxfqeux2g.png';
  if (n.startsWith('hbo') || n == 'max')
    return '$base/skypuy7SXuugIQeYg0IglmzoKaS.png';
  if (n.startsWith('skyshowtime'))
    return '$base/ube1pVpP3FklRkeyQjlDkkC3tL2.png';
  return null;
}

const _curatedAliases = <String, String>{
  'walt disney': 'disney',
  'disney plus': 'disney+',
  'columbia': 'sony pictures',
  'sony': 'sony pictures',
  'tristar': 'sony pictures',
  'warner bros': 'warner bros. pictures',
  'universal': 'universal',
  'paramount+': 'paramount+',
  'paramount': 'paramount',
  'amazon': 'prime video',
  'prime video': 'prime video',
  'apple': 'apple tv+',
  'hbo max': 'hbo max',
  'hbo': 'hbo',
  '20th century': '20th century studios',
  'twentieth century': '20th century studios',
  'marvel': 'marvel studios',
  'dc comics': 'dc',
  'dreamworks': 'dreamworks',
  'pixar': 'pixar',
  'a24': 'a24',
  'netflix': 'netflix',
};

/// The clean white logo the app already shows in its Networks and Studios
/// rows, for a studio or network that is one of them, or null. [width] is
/// the TMDB size asked for (small on cards).
String? curatedLogoUrl(String name, {int width = 300}) {
  final n = name.trim().toLowerCase();
  final all = [
    for (final x in SeerrDiscoverViewModel.popularNetworks)
      (x.name.toLowerCase(), x.logoPath),
    for (final x in SeerrDiscoverViewModel.popularStudios)
      (x.name.toLowerCase(), x.logoPath),
  ];
  String? find(String key) {
    for (final (k, path) in all) {
      if (k == key) return path;
    }
    return null;
  }

  var path = find(n);
  if (path == null) {
    for (final e in _curatedAliases.entries) {
      if (n.startsWith(e.key)) {
        path = find(e.value);
        if (path != null) break;
      }
    }
  }
  return path?.replaceFirst('/w780_', '/w${width}_');
}

/// A Seerr result (TMDB id + media type) as the item the badges look up.
AggregatedItem badgeItemForTmdb(int tmdbId, String? mediaType) => AggregatedItem(
      id: '$tmdbId',
      serverId: 'seerr',
      rawData: {
        'Type': mediaType == 'tv' ? 'Series' : 'Movie',
        'ProviderIds': {'Tmdb': '$tmdbId'},
      },
    );
