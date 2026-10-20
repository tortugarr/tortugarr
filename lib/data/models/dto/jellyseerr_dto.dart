/// Data transfer objects for the Jellyseerr discovery API.
///
/// These mirror the JSON shapes returned by the Jellyseerr instance running on
/// the Jellyseerr server. Every field is non-nullable and falls
/// back to a neutral default, so a partial or unexpected payload degrades into
/// an empty value instead of throwing at the parse site.
library;

/// Parsing helpers shared by the DTOs below.
///
/// Jellyseerr is loose about types — numbers arrive as `int`, `double` or
/// `String` depending on the endpoint — so every read goes through one of
/// these instead of a raw cast.
int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

/// Pulls the four-digit year out of an ISO-ish date such as `2024-05-01`.
String _yearOf(Object? value) {
  final raw = _asString(value);
  if (raw.length < 4) return '';
  final year = raw.substring(0, 4);
  return int.tryParse(year) == null ? '' : year;
}

/// One entry from `GET /api/v1/search`.
class JellyseerrSearchResultDto {
  /// TMDB id, used as the `mediaId` for every follow-up call.
  final int id;
  final String title;

  /// Four-digit release year, or `''` when Jellyseerr has no date.
  final String releaseYear;
  final String description;

  /// TMDB-relative poster path (e.g. `/abc123.jpg`), or `''`.
  final String posterPath;

  /// `'tv'` or `'movie'`.
  final String mediaType;
  final double voteAverage;

  const JellyseerrSearchResultDto({
    required this.id,
    required this.title,
    required this.releaseYear,
    required this.description,
    required this.posterPath,
    required this.mediaType,
    required this.voteAverage,
  });

  factory JellyseerrSearchResultDto.fromJson(Map<String, dynamic> json) {
    // Movies carry `title`/`releaseDate`; series carry `name`/`firstAirDate`.
    final title = json['title'] ?? json['name'] ?? json['originalTitle'];
    final date = json['releaseDate'] ?? json['firstAirDate'];

    return JellyseerrSearchResultDto(
      id: _asInt(json['id']),
      title: _asString(title),
      releaseYear: _yearOf(date),
      description: _asString(json['overview'] ?? json['description']),
      posterPath: _asString(json['posterPath'] ?? json['poster_path']),
      mediaType: _asString(json['mediaType'] ?? json['media_type']),
      voteAverage: _asDouble(json['voteAverage'] ?? json['vote_average']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'releaseYear': releaseYear,
        'description': description,
        'posterPath': posterPath,
        'mediaType': mediaType,
        'voteAverage': voteAverage,
      };

  @override
  String toString() =>
      'JellyseerrSearchResultDto(id: $id, title: $title, mediaType: $mediaType)';
}

/// A downloadable release candidate for a title.
class JellyseerrFileOptionDto {
  /// Release name / file path as reported by the indexer.
  final String path;

  /// One of `2160p`, `1080p` or `720p` — see [resolutionFromPath].
  final String resolution;
  final int sizeInMb;
  final int seeders;
  final int leechers;

  const JellyseerrFileOptionDto({
    required this.path,
    required this.resolution,
    required this.sizeInMb,
    required this.seeders,
    required this.leechers,
  });

  /// Classifies a release by the quality tag in its filename.
  ///
  /// `2160p`/`4K` win over `1080p`; anything else is treated as `720p`, which
  /// keeps the UI's quality selector total rather than needing an "unknown"
  /// bucket.
  static String resolutionFromPath(String path) {
    final upper = path.toUpperCase();
    if (upper.contains('2160P') || upper.contains('4K')) return '2160p';
    if (upper.contains('1080P')) return '1080p';
    return '720p';
  }

  factory JellyseerrFileOptionDto.fromJson(Map<String, dynamic> json) {
    final path = _asString(
      json['path'] ?? json['title'] ?? json['name'] ?? json['fileName'],
    );

    // Trust an explicit resolution when the indexer supplies one; otherwise
    // fall back to reading the quality tag out of the release name.
    final reported = _asString(json['resolution'] ?? json['quality']);
    final resolution =
        reported.isEmpty ? resolutionFromPath(path) : reported;

    return JellyseerrFileOptionDto(
      path: path,
      resolution: resolution,
      sizeInMb: _sizeInMb(json),
      seeders: _asInt(json['seeders'] ?? json['seeds']),
      leechers: _asInt(json['leechers'] ?? json['peers']),
    );
  }

  /// Prefers an explicit `sizeInMb`, else converts a byte-valued `size`.
  static int _sizeInMb(Map<String, dynamic> json) {
    final explicit = json['sizeInMb'] ?? json['sizeMb'];
    if (explicit != null) return _asInt(explicit);

    final bytes = _asInt(json['size']);
    return bytes == 0 ? 0 : (bytes / (1024 * 1024)).round();
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'resolution': resolution,
        'sizeInMb': sizeInMb,
        'seeders': seeders,
        'leechers': leechers,
      };

  @override
  String toString() =>
      'JellyseerrFileOptionDto(path: $path, resolution: $resolution, '
      'sizeInMb: $sizeInMb, seeders: $seeders, leechers: $leechers)';
}

/// Confirmation returned by `POST /api/v1/request`.
class JellyseerrMediaRequestDto {
  final int requestId;
  final int mediaId;

  /// Jellyseerr request status, normalised to a string (`'1'`/`pending`/...).
  final String status;

  /// When Jellyseerr accepted the request; epoch zero when it sends no date.
  final DateTime requestedAt;

  const JellyseerrMediaRequestDto({
    required this.requestId,
    required this.mediaId,
    required this.status,
    required this.requestedAt,
  });

  factory JellyseerrMediaRequestDto.fromJson(Map<String, dynamic> json) {
    // The media id lives on the nested `media` object on a real response, but
    // is echoed at the top level by some proxies.
    final media = json['media'];
    final nestedMediaId = media is Map<String, dynamic>
        ? (media['tmdbId'] ?? media['id'])
        : null;

    return JellyseerrMediaRequestDto(
      requestId: _asInt(json['requestId'] ?? json['id']),
      mediaId: _asInt(json['mediaId'] ?? nestedMediaId),
      status: _asString(json['status']),
      requestedAt:
          DateTime.tryParse(_asString(json['createdAt'] ?? json['requestedAt']))
                  ?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'mediaId': mediaId,
        'status': status,
        'requestedAt': requestedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'JellyseerrMediaRequestDto(requestId: $requestId, mediaId: $mediaId, '
      'status: $status)';
}
