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
        final mark = info.network == null ? null : studioMark(info.network!);
        if (prefs.get(UserPreferences.tgNetworkLogos) &&
            prefs.get(UserPreferences.tgLogoStyle) != 'full' &&
            mark != null) {
          // Short mark (N, D+, WB …) in the corner.
          children.add(
            Align(
              alignment: _corner(prefs.get(UserPreferences.tgNetworkCorner)),
              child: Padding(
                padding: EdgeInsets.all(6 * s),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: mark.background.withValues(
                      alpha: prefs.get(UserPreferences.tgNetworkOpacity) / 100,
                    ),
                    borderRadius: BorderRadius.circular(4 * s),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * s,
                      vertical: 2 * s,
                    ),
                    child: Text(
                      mark.text,
                      style: TextStyle(
                        color: mark.foreground,
                        fontSize: 12 * s,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
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

/// A short mark for a studio or network: brand letters on a brand-like
/// colour (not the brand's logo), for small cards. Unknown names get their
/// initials on a neutral box.
class StudioMark {
  const StudioMark(this.text, this.background, this.foreground);
  final String text;
  final Color background;
  final Color foreground;
}

final _marks = <(RegExp, StudioMark)>[
  (
    RegExp(r'^netflix', caseSensitive: false),
    const StudioMark('N', Color(0xFFE50914), Colors.white),
  ),
  (
    RegExp(r'^(disney\+|disney plus)', caseSensitive: false),
    const StudioMark('D+', Color(0xFF113CCF), Colors.white),
  ),
  (
    RegExp(r'^(walt disney|disney)', caseSensitive: false),
    const StudioMark('D', Color(0xFF113CCF), Colors.white),
  ),
  (
    RegExp(r'^pixar', caseSensitive: false),
    const StudioMark('PX', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^marvel', caseSensitive: false),
    const StudioMark('M', Color(0xFFEC1D24), Colors.white),
  ),
  (
    RegExp(r'^lucasfilm', caseSensitive: false),
    const StudioMark('LF', Color(0xFF1B1B1B), Color(0xFFFFE81F)),
  ),
  (
    RegExp(r'^(hbo|max\b|hbo max)', caseSensitive: false),
    const StudioMark('HBO', Color(0xFF5822B4), Colors.white),
  ),
  (
    RegExp(r'^warner', caseSensitive: false),
    const StudioMark('WB', Color(0xFF0057B8), Color(0xFFFFD700)),
  ),
  (
    RegExp(r'^new line', caseSensitive: false),
    const StudioMark('NL', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^(apple|apple tv)', caseSensitive: false),
    const StudioMark('tv+', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^(amazon|prime video)', caseSensitive: false),
    const StudioMark('prime', Color(0xFF00A8E1), Colors.white),
  ),
  (
    RegExp(r'^(metro-goldwyn|mgm)', caseSensitive: false),
    const StudioMark('MGM', Color(0xFFB8860B), Colors.black),
  ),
  (
    RegExp(r'^universal', caseSensitive: false),
    const StudioMark('U', Color(0xFF1C3F94), Colors.white),
  ),
  (
    RegExp(r'^illumination', caseSensitive: false),
    const StudioMark('IL', Color(0xFFFFD100), Colors.black),
  ),
  (
    RegExp(r'^dreamworks', caseSensitive: false),
    const StudioMark('DW', Color(0xFF0E6BB8), Colors.white),
  ),
  (
    RegExp(r'^paramount', caseSensitive: false),
    const StudioMark('P', Color(0xFF0064FF), Colors.white),
  ),
  (
    RegExp(r'^(20th century|twentieth century)', caseSensitive: false),
    const StudioMark('20', Color(0xFF1B1B1B), Color(0xFFFFC72C)),
  ),
  (
    RegExp(r'^searchlight', caseSensitive: false),
    const StudioMark('SL', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^(columbia|sony|tristar)', caseSensitive: false),
    const StudioMark('S', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^(lionsgate|lions gate)', caseSensitive: false),
    const StudioMark('L', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^summit', caseSensitive: false),
    const StudioMark('SE', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^a24', caseSensitive: false),
    const StudioMark('A24', Colors.white, Colors.black),
  ),
  (
    RegExp(r'^neon', caseSensitive: false),
    const StudioMark('NEON', Color(0xFF111111), Color(0xFFFF2BD6)),
  ),
  (
    RegExp(r'^legendary', caseSensitive: false),
    const StudioMark('LG', Color(0xFF1B1B1B), Colors.white),
  ),
  (
    RegExp(r'^blumhouse', caseSensitive: false),
    const StudioMark('BH', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^skyshowtime', caseSensitive: false),
    const StudioMark('SST', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^(nrk)', caseSensitive: false),
    const StudioMark('NRK', Color(0xFF0B2350), Colors.white),
  ),
  (
    RegExp(r'^(bbc)', caseSensitive: false),
    const StudioMark('BBC', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^(fx)', caseSensitive: false),
    const StudioMark('FX', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^(amc)', caseSensitive: false),
    const StudioMark('AMC', Color(0xFF111111), Colors.white),
  ),
  (
    RegExp(r'^(showtime)', caseSensitive: false),
    const StudioMark('SHO', Color(0xFFB10000), Colors.white),
  ),
];

StudioMark studioMark(String name) {
  for (final (re, m) in _marks) {
    if (re.hasMatch(name.trim())) return m;
  }
  final words = name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w[0]))
      .toList();
  final text = words.take(2).map((w) => w[0].toUpperCase()).join();
  return StudioMark(
    text.isEmpty ? '?' : text,
    const Color(0xFF2A2A2A),
    Colors.white,
  );
}
