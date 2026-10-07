import '../models/media_discovery.dart';

/// Discovery operations the UI and Riverpod state depend on.
///
/// The abstraction exists so state can be tested against a fake without a
/// Jellyseerr instance, and so a future backend swap is a data-layer change
/// only. The implementation lives in
/// `lib/data/repositories/media_discovery_repository_impl.dart`.
///
/// Failures are not swallowed: every method rethrows whatever the underlying
/// service raised (a `JellyseerrServiceException` today) rather than returning
/// an empty result that the UI would mistake for "nothing found".
abstract class MediaDiscoveryRepository {
  /// Searches the discovery backend for [query].
  ///
  /// Returns an empty list for a blank query. Rows the app cannot classify —
  /// Jellyseerr's `person` results, for instance — are dropped rather than
  /// forced into a [MediaType].
  Future<List<SearchResult>> searchMedia(String query);

  /// Lists the downloadable releases known for [mediaId].
  Future<List<FileOption>> getAvailableFiles(int mediaId, MediaType type);

  /// Submits a download request for [mediaId] covering [files].
  ///
  /// The returned [MediaRequest] carries [files] back on
  /// [MediaRequest.selectedFiles]; the backend confirmation only echoes ids
  /// and a status.
  Future<MediaRequest> requestMedia(
    int mediaId,
    MediaType type,
    List<FileOption> files,
  );
}
