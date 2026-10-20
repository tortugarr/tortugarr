import '../models/download_management.dart';

/// Download operations the UI and Riverpod state depend on.
///
/// The abstraction exists so state can be tested against a fake without a
/// running qBittorrent, and so swapping the download client is a data-layer
/// change only. The implementation lives in
/// `lib/data/repositories/download_manager_repository_impl.dart`.
///
/// Failures are not swallowed: every method surfaces whatever the underlying
/// service raised (a `QBittorrentServiceException` today), and
/// [watchDownloadProgress] forwards such a failure as a stream error.
abstract class DownloadManagerRepository {
  /// Hands [magnetUri] to the download client under [category], written into
  /// [savePath]. Returns the info hash, which is the handle every other
  /// method takes.
  Future<String> startDownload(
    String magnetUri,
    String category,
    String savePath,
  );

  /// Streams progress for [hash] until the download finishes or fails.
  ///
  /// The stream closes when the client stops reporting the torrent — which
  /// includes the auto-stop that fires once the seed obligation is met.
  Stream<Download> watchDownloadProgress(String hash);

  /// Stops [hash] and removes it from the client, leaving the files on disk.
  Future<void> stopDownload(String hash);

  /// Lists everything the client is currently tracking.
  ///
  /// The listing endpoint carries no progress fields, so entries come back at
  /// [Download.progress] 0.0 in state [DownloadState.stopped]; call
  /// [watchDownloadProgress] for live figures on a specific hash.
  Future<List<Download>> listActiveDownloads();
}
