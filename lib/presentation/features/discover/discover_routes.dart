/// Route paths for the discovery flow.
///
/// These live inside the feature rather than in `lib/ui/navigation/destinations.dart`
/// so that nothing under `lib/presentation/` has to import `lib/ui/`. The
/// router is the one place that reaches the other way round.
///
/// Both the absolute paths and the relative segments are here because
/// `GoRoute` wants a segment for a nested route (`'results'`) but
/// `context.go` wants the full path (`'/discover/results'`).
library;

abstract final class DiscoverRoutes {
  /// Search entry point.
  static const String discover = '/discover';

  /// Grid of search results.
  static const String results = '$discover/$resultsSegment';

  /// Release/resolution picker for the selected title.
  static const String files = '$discover/$filesSegment';

  /// Download progress. The screen behind this path is Task 7's; Task 6 only
  /// navigates to it.
  static const String downloading = '$discover/$downloadingSegment';

  static const String resultsSegment = 'results';
  static const String filesSegment = 'files';
  static const String downloadingSegment = 'downloading';
}
