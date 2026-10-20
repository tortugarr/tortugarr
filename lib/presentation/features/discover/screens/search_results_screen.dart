/// Grid of titles matching the current [searchQueryProvider].
///
/// Reads [searchResultsProvider] and renders its three `AsyncValue` states.
/// Tapping a card records the choice in [selectedMediaProvider] and moves on
/// to the release picker.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/providers/discovery_provider.dart';
import '../../../../domain/models/media_discovery.dart';
import '../discover_routes.dart';

/// Three across at 1080p leaves ~600px per tile — a comfortable poster on a TV.
const int _gridColumns = 3;
const double _screenPadding = 48;
const double _gridSpacing = 32;

/// Poster (2:3) plus two lines of caption underneath.
const double _cardAspectRatio = 0.58;

/// TMDB serves [SearchResult.posterPath] relative to this. Same width the
/// existing Seerr screens use.
const String _tmdbPosterBase = 'https://image.tmdb.org/t/p/w342';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(query.isEmpty ? 'Search results' : 'Results for "$query"'),
        leading: BackButton(
          key: const Key('searchResultsBackButton'),
          onPressed: () => context.go(DiscoverRoutes.discover),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CenteredMessage(
          key: const Key('searchResultsError'),
          icon: Icons.error_outline,
          message: 'Error: $error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return _CenteredMessage(
              key: const Key('searchResultsEmpty'),
              icon: Icons.search_off,
              message: query.isEmpty
                  ? 'Nothing searched for yet.'
                  : 'No results for "$query".',
            );
          }

          return GridView.builder(
            key: const Key('searchResultsGrid'),
            padding: const EdgeInsets.all(_screenPadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridColumns,
              crossAxisSpacing: _gridSpacing,
              mainAxisSpacing: _gridSpacing,
              childAspectRatio: _cardAspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final result = items[index];
              return _ResultCard(
                result: result,
                // Autofocus the first tile so a remote lands somewhere useful.
                autofocus: index == 0,
                onTap: () => _onResultTapped(context, ref, result),
              );
            },
          );
        },
      ),
    );
  }

  void _onResultTapped(
    BuildContext context,
    WidgetRef ref,
    SearchResult result,
  ) {
    ref.read(selectedMediaProvider.notifier).state = result;
    // Ticks belong to the title they were made against — picking a different
    // one must not carry the previous title's releases into the request.
    ref.read(selectedFilesProvider.notifier).state = const <FileOption>[];
    context.go(DiscoverRoutes.files);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onTap,
    required this.autofocus,
  });

  final SearchResult result;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('searchResultCard-${result.id}'),
        onTap: onTap,
        autofocus: autofocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Poster(posterPath: result.posterPath)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _caption(result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// e.g. `2024 · Movie · ★ 8.2`, dropping the parts the source did not have.
  static String _caption(SearchResult result) {
    return <String>[
      if (result.hasReleaseYear) '${result.releaseYear}',
      result.mediaType.toDisplay(),
      if (result.rating > 0) '★ ${result.rating.toStringAsFixed(1)}',
    ].join(' · ');
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.posterPath});

  final String posterPath;

  @override
  Widget build(BuildContext context) {
    if (posterPath.isEmpty) {
      return const _PosterPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: '$_tmdbPosterBase$posterPath',
      fit: BoxFit.cover,
      placeholder: (context, _) => const _PosterPlaceholder(),
      errorWidget: (context, _, _) => const _PosterPlaceholder(),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.movie, size: 64)),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
