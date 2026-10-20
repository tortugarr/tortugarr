import '../../domain/models/media_discovery.dart';
import '../../domain/repositories/media_discovery_repository.dart';
import '../models/dto/jellyseerr_dto.dart';
import '../services/jellyseerr_service.dart';

/// [MediaDiscoveryRepository] backed by [JellyseerrService].
///
/// Deliberately thin: it calls the service and translates DTOs into domain
/// models. There is no caching, retrying or error rewriting here — a
/// [JellyseerrServiceException] travels straight through to the caller so the
/// UI can show the reason the service already worked out.
class MediaDiscoveryRepositoryImpl implements MediaDiscoveryRepository {
  final JellyseerrService _jellyseerr;

  MediaDiscoveryRepositoryImpl({required JellyseerrService jellyseerr})
      : _jellyseerr = jellyseerr;

  @override
  Future<List<SearchResult>> searchMedia(String query) async {
    final dtos = await _jellyseerr.search(query);

    // A Jellyseerr search mixes in `person` rows, which have no media type and
    // nothing for the grid to show. Dropping them here keeps MediaType total
    // instead of adding an "other" member the UI would have to handle.
    return dtos
        .map(_toSearchResult)
        .whereType<SearchResult>()
        .toList(growable: false);
  }

  @override
  Future<List<FileOption>> getAvailableFiles(
    int mediaId,
    MediaType type,
  ) async {
    final dtos = await _jellyseerr.getAvailableFiles(mediaId, type.wireValue);
    return dtos.map(_toFileOption).toList(growable: false);
  }

  @override
  Future<MediaRequest> requestMedia(
    int mediaId,
    MediaType type,
    List<FileOption> files,
  ) async {
    final dto = await _jellyseerr.submitRequest(
      mediaId,
      type.wireValue,
      files.map((file) => file.path).toList(growable: false),
    );

    return MediaRequest(
      id: dto.requestId,
      // Jellyseerr echoes the media id, but a proxy that omits it would leave
      // the request unlinkable — fall back to what the caller asked for.
      mediaId: dto.mediaId == 0 ? mediaId : dto.mediaId,
      status: _parseStatus(dto.status),
      requestedAt: dto.requestedAt,
      // The confirmation carries only ids and a status, so the selection the
      // caller made is the only record of which releases this request covers.
      selectedFiles: List<FileOption>.unmodifiable(files),
    );
  }

  // --- mapping -----------------------------------------------------------

  /// Returns null when the row is not a title this app can present.
  SearchResult? _toSearchResult(JellyseerrSearchResultDto dto) {
    final mediaType = MediaType.tryParse(dto.mediaType);
    if (mediaType == null) return null;

    return SearchResult(
      id: dto.id,
      title: dto.title,
      // The DTO keeps the year as a string because Jellyseerr may send none;
      // 0 is the domain's "no release date" value.
      releaseYear: int.tryParse(dto.releaseYear) ?? 0,
      description: dto.description,
      posterPath: dto.posterPath,
      mediaType: mediaType,
      rating: dto.voteAverage,
    );
  }

  FileOption _toFileOption(JellyseerrFileOptionDto dto) => FileOption(
        path: dto.path,
        resolution: _parseResolution(dto.resolution, dto.path),
        sizeInMb: dto.sizeInMb,
        seeders: dto.seeders,
      );

  /// Classifies a release, reading the quality tag out of [path] when the
  /// indexer's own [reported] value is missing or unrecognised.
  ///
  /// Falls back to [Resolution.p720] rather than dropping the release: a
  /// playable file the app mislabels is more useful than one it hides.
  Resolution _parseResolution(String reported, String path) =>
      Resolution.tryParse(reported) ??
      Resolution.tryParse(path) ??
      Resolution.p720;

  /// Normalises Jellyseerr's request status onto [MediaRequestStatus].
  ///
  /// Jellyseerr sends the numeric `MediaRequestStatus` enum (1 = pending,
  /// 2 = approved, 3 = declined, 4 = failed) on a real response, but proxies
  /// and older builds send the word instead, so both are accepted.
  String _parseStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'pending':
        return MediaRequestStatus.pending;
      case '2':
      case 'approved':
        return MediaRequestStatus.approved;
      case '3':
      case 'declined':
        return MediaRequestStatus.declined;
      case '4':
      case 'failed':
        return MediaRequestStatus.failed;
      case 'processing':
      case 'partially_available':
        return MediaRequestStatus.processing;
      case 'completed':
      case 'available':
        return MediaRequestStatus.completed;
      default:
        return MediaRequestStatus.unknown;
    }
  }
}
