/// Domain models for the media discovery flow.
///
/// These are the business-level shapes the UI and Riverpod state talk in:
/// pure Dart, no Dio, no JSON. The repositories under `lib/data/repositories/`
/// translate the Jellyseerr DTOs into these, so nothing above the data layer
/// has to know what the wire format looks like.
library;

import 'package:collection/collection.dart';

/// What kind of title a [SearchResult] describes.
enum MediaType {
  tv,
  movie;

  /// The value Jellyseerr expects on the wire (`'tv'` / `'movie'`).
  String get wireValue => name;

  /// Human-readable label for the UI.
  String toDisplay() => switch (this) {
        MediaType.tv => 'TV Series',
        MediaType.movie => 'Movie',
      };

  /// Parses a Jellyseerr media-type string, or returns null when unknown.
  ///
  /// Jellyseerr answers `'tv'`/`'movie'`, but some endpoints echo `'series'`
  /// or `'show'`, so those are accepted too. Anything else — including the
  /// `'person'` rows a search can return — yields null, letting the caller
  /// drop the row rather than inventing a type for it.
  static MediaType? tryParse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'tv':
      case 'series':
      case 'show':
        return MediaType.tv;
      case 'movie':
      case 'film':
        return MediaType.movie;
      default:
        return null;
    }
  }
}

/// The quality tiers the download picker offers.
///
/// There is deliberately no "unknown" tier: an unrecognised release is
/// classified as [Resolution.p720] by [tryParse]'s caller, which keeps the
/// quality selector total instead of needing an escape hatch in the UI.
enum Resolution {
  p720,
  p1080,
  p2160;

  /// Vertical pixel count — the number the tier is named after.
  int get heightInPixels => switch (this) {
        Resolution.p720 => 720,
        Resolution.p1080 => 1080,
        Resolution.p2160 => 2160,
      };

  /// Label for the UI, e.g. `2160p (4K)`.
  String toDisplay() => switch (this) {
        Resolution.p720 => '720p',
        Resolution.p1080 => '1080p',
        Resolution.p2160 => '2160p (4K)',
      };

  /// Parses a quality tag such as `1080p`, `2160P` or `4K`.
  ///
  /// Returns null when [raw] carries no recognisable tier, so the caller can
  /// decide between a fallback and dropping the release.
  static Resolution? tryParse(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper.isEmpty) return null;
    if (upper.contains('2160') || upper.contains('4K') || upper.contains('UHD')) {
      return Resolution.p2160;
    }
    if (upper.contains('1080')) return Resolution.p1080;
    if (upper.contains('720')) return Resolution.p720;
    return null;
  }
}

/// One title returned by a discovery search.
class SearchResult {
  /// TMDB id — the `mediaId` every follow-up call takes.
  final int id;

  final String title;

  /// Four-digit release year, or 0 when the source had no date.
  final int releaseYear;

  final String description;

  /// TMDB-relative poster path (e.g. `/abc123.jpg`), or `''`.
  final String posterPath;

  final MediaType mediaType;

  /// TMDB vote average on a 0–10 scale.
  final double rating;

  const SearchResult({
    required this.id,
    required this.title,
    required this.releaseYear,
    required this.description,
    required this.posterPath,
    required this.mediaType,
    required this.rating,
  });

  /// False when the source had no release date to report.
  bool get hasReleaseYear => releaseYear > 0;

  SearchResult copyWith({
    int? id,
    String? title,
    int? releaseYear,
    String? description,
    String? posterPath,
    MediaType? mediaType,
    double? rating,
  }) =>
      SearchResult(
        id: id ?? this.id,
        title: title ?? this.title,
        releaseYear: releaseYear ?? this.releaseYear,
        description: description ?? this.description,
        posterPath: posterPath ?? this.posterPath,
        mediaType: mediaType ?? this.mediaType,
        rating: rating ?? this.rating,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          other.id == id &&
          other.title == title &&
          other.releaseYear == releaseYear &&
          other.description == description &&
          other.posterPath == posterPath &&
          other.mediaType == mediaType &&
          other.rating == rating;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        releaseYear,
        description,
        posterPath,
        mediaType,
        rating,
      );

  @override
  String toString() => 'SearchResult(id: $id, title: $title, '
      'releaseYear: $releaseYear, mediaType: ${mediaType.name})';
}

/// One downloadable release candidate for a title.
class FileOption {
  /// Release name / file path as reported by the indexer.
  final String path;

  final Resolution resolution;

  /// Payload size in megabytes.
  final int sizeInMb;

  final int seeders;

  const FileOption({
    required this.path,
    required this.resolution,
    required this.sizeInMb,
    required this.seeders,
  });

  /// Size in gigabytes, for the "4.2 GB" label in the picker.
  double get sizeInGb => sizeInMb / 1024;

  /// True when at least one peer is advertising the full payload.
  bool get hasSeeders => seeders > 0;

  FileOption copyWith({
    String? path,
    Resolution? resolution,
    int? sizeInMb,
    int? seeders,
  }) =>
      FileOption(
        path: path ?? this.path,
        resolution: resolution ?? this.resolution,
        sizeInMb: sizeInMb ?? this.sizeInMb,
        seeders: seeders ?? this.seeders,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOption &&
          other.path == path &&
          other.resolution == resolution &&
          other.sizeInMb == sizeInMb &&
          other.seeders == seeders;

  @override
  int get hashCode => Object.hash(path, resolution, sizeInMb, seeders);

  @override
  String toString() => 'FileOption(path: $path, '
      'resolution: ${resolution.toDisplay()}, sizeInMb: $sizeInMb, '
      'seeders: $seeders)';
}

/// A submitted download request and the releases it covers.
class MediaRequest {
  /// Jellyseerr's own request id.
  final int id;

  /// TMDB id of the requested title.
  final int mediaId;

  /// Normalised lifecycle state: `pending`, `approved`, `declined`,
  /// `processing`, `completed`, or `unknown` when Jellyseerr sent something
  /// this app does not recognise. See [MediaRequestStatus].
  final String status;

  final DateTime requestedAt;

  /// The releases the user picked when submitting the request.
  final List<FileOption> selectedFiles;

  const MediaRequest({
    required this.id,
    required this.mediaId,
    required this.status,
    required this.requestedAt,
    required this.selectedFiles,
  });

  bool get isPending => status == MediaRequestStatus.pending;
  bool get isApproved => status == MediaRequestStatus.approved;
  bool get isCompleted => status == MediaRequestStatus.completed;

  MediaRequest copyWith({
    int? id,
    int? mediaId,
    String? status,
    DateTime? requestedAt,
    List<FileOption>? selectedFiles,
  }) =>
      MediaRequest(
        id: id ?? this.id,
        mediaId: mediaId ?? this.mediaId,
        status: status ?? this.status,
        requestedAt: requestedAt ?? this.requestedAt,
        selectedFiles: selectedFiles ?? this.selectedFiles,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRequest &&
          other.id == id &&
          other.mediaId == mediaId &&
          other.status == status &&
          other.requestedAt == requestedAt &&
          const ListEquality<FileOption>()
              .equals(other.selectedFiles, selectedFiles);

  @override
  int get hashCode => Object.hash(
        id,
        mediaId,
        status,
        requestedAt,
        const ListEquality<FileOption>().hash(selectedFiles),
      );

  @override
  String toString() => 'MediaRequest(id: $id, mediaId: $mediaId, '
      'status: $status, files: ${selectedFiles.length})';
}

/// The values [MediaRequest.status] can take.
///
/// Kept as constants rather than an enum because the plan pins the field to a
/// `String`; these exist so call sites compare against a name instead of a
/// bare literal.
abstract final class MediaRequestStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String declined = 'declined';
  static const String processing = 'processing';
  static const String completed = 'completed';

  /// Jellyseerr accepted the request but the grab failed downstream.
  static const String failed = 'failed';

  /// Jellyseerr reported a status this app has no mapping for.
  static const String unknown = 'unknown';
}
