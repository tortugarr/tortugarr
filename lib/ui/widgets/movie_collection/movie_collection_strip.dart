import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/seerr/movie_collection.dart';
import '../focus/focusable_wrapper.dart';
import '../missing_episodes/missing_episode_card.dart' show norwegianShortDate;
import 'package:moonfin/util/app_l10n.dart';

/// What the badge on a collection part says; empty for owned movies.
String collectionPartBadge(CollectionPart p, {DateTime? now}) =>
    switch (p.state) {
      CollectionPartState.owned => '',
      CollectionPartState.missing => appL10n().tgMissing,
      CollectionPartState.requested => appL10n().tgRequested,
      CollectionPartState.downloading => appL10n().tgDownloading,
      CollectionPartState.unreleased => p.releaseDate == null
          ? appL10n().tgComing
          : appL10n().tgComingOn(norwegianShortDate(p.releaseDate!, now: now)),
    };

Color _badgeColor(CollectionPartState state) => switch (state) {
      CollectionPartState.owned => Colors.transparent,
      CollectionPartState.missing => const Color(0xFFD32F2F),
      CollectionPartState.requested => const Color(0xFFEF6C00),
      CollectionPartState.downloading => const Color(0xFF1E88E5),
      CollectionPartState.unreleased => Colors.white24,
    };

/// "Del av filmserien …" on a movie's detail screen: the other movies of its
/// collection in release order. Owned ones open the movie; missing ones are
/// greyed with a red "Mangler" badge and open Download Now.
class MovieCollectionStripView extends StatelessWidget {
  final MovieCollectionStrip strip;
  final ValueChanged<CollectionPart> onSelect;
  final FocusNode? firstFocusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  /// Width cap in landscape, matching the action row above.
  final double? maxWidth;

  const MovieCollectionStripView({
    super.key,
    required this.strip,
    required this.onSelect,
    this.firstFocusNode,
    this.onNavigateUp,
    this.onNavigateDown,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final cardWidth = compact ? 200.0 : 236.0;
    final cardHeight = compact ? 78.0 : 84.0;
    final current = strip.currentNumber;
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.hasBoundedWidth ? constraints.maxWidth : 900.0;
        if (maxWidth != null && maxWidth! < width) width = maxWidth!;
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.movie_filter_outlined,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: appL10n().tgPartOfCollectionPrefix),
                          TextSpan(
                            text: strip.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (current != null)
                            TextSpan(
                              text: appL10n().tgViewingPartOf(current, strip.total),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: strip.others.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => CollectionPartCard(
                    part: strip.others[i],
                    width: cardWidth,
                    height: cardHeight,
                    focusNode: i == 0 ? firstFocusNode : null,
                    onNavigateUp: onNavigateUp,
                    onNavigateDown: onNavigateDown,
                    onSelect: () => onSelect(strip.others[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CollectionPartCard extends StatelessWidget {
  final CollectionPart part;
  final double width;
  final double height;
  final VoidCallback onSelect;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const CollectionPartCard({
    super.key,
    required this.part,
    required this.width,
    required this.height,
    required this.onSelect,
    this.focusNode,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    final owned = part.state == CollectionPartState.owned;
    final badge = collectionPartBadge(part);
    final poster = part.posterPath;
    final dim = owned ? 1.0 : 0.5;
    return Builder(
      builder: (cardContext) => FocusableWrapper(
        focusNode: focusNode,
        onSelect: onSelect,
        onNavigateUp: onNavigateUp,
        onNavigateDown: onNavigateDown,
        autoScroll: false,
        borderRadius: 8,
        disableScale: true,
        semanticLabel: '${part.partLabel}: ${part.title}'
            '${badge.isEmpty ? '' : ', $badge'}',
        onFocusChange: (focused) {
          if (focused) {
            Scrollable.ensureVisible(
              cardContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
            );
          }
        },
        child: GestureDetector(
          onTap: onSelect,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: owned ? 0.10 : 0.03),
              borderRadius: AppRadius.circular(8),
              border: Border.all(
                color: switch (part.state) {
                  CollectionPartState.owned => Colors.white24,
                  CollectionPartState.missing ||
                  CollectionPartState.requested =>
                    const Color(0xFFD32F2F).withValues(alpha: 0.55),
                  _ => Colors.white10,
                },
              ),
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: dim,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                    child: SizedBox(
                      width: height * 2 / 3,
                      height: height,
                      child: poster == null || poster.isEmpty
                          ? const ColoredBox(
                              color: Colors.black26,
                              child: Icon(Icons.movie_outlined,
                                  color: Colors.white38),
                            )
                          : Image.network(
                              'https://image.tmdb.org/t/p/w154$poster',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Colors.black26,
                                child: Icon(Icons.movie_outlined,
                                    color: Colors.white38),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.partLabel,
                        style: TextStyle(
                          color: owned ? Colors.white70 : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        part.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: owned ? Colors.white : Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (part.year != null)
                            Text(
                              '${part.year}',
                              style: TextStyle(
                                color: owned ? Colors.white60 : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          if (badge.isNotEmpty) ...[
                            if (part.year != null) const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _badgeColor(part.state),
                                  borderRadius: AppRadius.circular(5),
                                ),
                                child: Text(
                                  badge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (part.canDownload)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.download_for_offline_outlined,
                        color: Colors.white54, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
