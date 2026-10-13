/// Data transfer objects for the qBittorrent Web API (v2).
///
/// These mirror the JSON returned by `GET /api/v2/torrents/info` on the
/// qBittorrent instance and
/// is fronted by Caddy on port 8421. Every field is non-nullable and falls back
/// to a neutral default, so a partial payload degrades into an empty value
/// instead of throwing at the parse site.
library;

/// Parsing helpers shared by the DTOs below.
///
/// qBittorrent is loose about types — `progress` and `ratio` arrive as `int`
/// when they land exactly on a whole number, and byte counts can exceed the
/// JS-safe integer range and come back as `double` — so every read goes
/// through one of these instead of a raw cast.
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

/// qBittorrent's sentinel for "no meaningful ETA" — 100 days, in seconds.
const int unknownEtaSeconds = 8640000;

/// A single progress reading for one torrent.
///
/// Produced on every poll of `/api/v2/torrents/info` by
/// `QBittorrentEnhancedService.monitorTorrent`.
class TorrentProgressDto {
  /// Info hash, lower-case hex — the key every qBittorrent endpoint takes.
  final String hash;

  final String name;

  /// Download completion in the range 0.0–1.0.
  final double progress;

  /// Bytes uploaded to peers so far.
  final int uploadedBytes;

  /// Total size of the torrent's selected files, in bytes.
  final int totalBytes;

  /// qBittorrent state string: `downloading`, `allocating`, `stalledUP`,
  /// `uploading`, `pausedUP`, `queuedDL`, `error`, ...
  final String state;

  /// Share ratio (uploaded / downloaded). Never negative.
  final double seedRatio;

  /// Estimated time remaining. See [hasEta] before showing this to a user.
  final Duration eta;

  const TorrentProgressDto({
    required this.hash,
    required this.name,
    required this.progress,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.state,
    required this.seedRatio,
    required this.eta,
  });

  /// True once the download is finished *and* the seed obligation is met.
  ///
  /// This is the trigger the service uses to remove the torrent (keeping the
  /// files) so a completed download stops consuming upload bandwidth.
  bool get shouldStopSeeding => progress >= 1.0 && seedRatio >= 1.0;

  /// True when the payload is fully downloaded, regardless of seeding.
  bool get isComplete => progress >= 1.0;

  /// False while qBittorrent is reporting its "infinite" ETA sentinel.
  bool get hasEta => eta.inSeconds > 0 && eta.inSeconds < unknownEtaSeconds;

  factory TorrentProgressDto.fromJson(Map<String, dynamic> json) {
    // A negative ratio means "not computed yet" on some qBittorrent builds;
    // folding it to 0 keeps shouldStopSeeding from tripping on a sentinel.
    final ratio = _asDouble(json['ratio']);

    return TorrentProgressDto(
      hash: _asString(json['hash']).toLowerCase(),
      name: _asString(json['name']),
      progress: _asDouble(json['progress']).clamp(0.0, 1.0).toDouble(),
      uploadedBytes: _asInt(json['uploaded']),
      totalBytes: _asInt(json['size'] ?? json['total_size']),
      state: _asString(json['state']),
      seedRatio: ratio < 0 ? 0.0 : ratio,
      eta: Duration(seconds: _asInt(json['eta'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'name': name,
        'progress': progress,
        'uploadedBytes': uploadedBytes,
        'totalBytes': totalBytes,
        'state': state,
        'seedRatio': seedRatio,
        'eta': eta.inSeconds,
      };

  @override
  String toString() =>
      'TorrentProgressDto(hash: $hash, name: $name, progress: $progress, '
      'state: $state, seedRatio: $seedRatio)';
}

/// One entry from a torrent listing, without the volatile progress fields.
class QBittorrentTorrentDto {
  /// Info hash, lower-case hex.
  final String hash;

  final String name;

  /// `radarr`, `sonarr` or `prowlarr` for torrents this app added.
  final String category;

  /// Absolute directory the payload is written to, e.g. `/downloads/radarr`.
  final String savePath;

  const QBittorrentTorrentDto({
    required this.hash,
    required this.name,
    required this.category,
    required this.savePath,
  });

  factory QBittorrentTorrentDto.fromJson(Map<String, dynamic> json) =>
      QBittorrentTorrentDto(
        hash: _asString(json['hash']).toLowerCase(),
        name: _asString(json['name']),
        category: _asString(json['category']),
        savePath: _asString(json['save_path'] ?? json['savePath']),
      );

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'name': name,
        'category': category,
        'savePath': savePath,
      };

  @override
  String toString() =>
      'QBittorrentTorrentDto(hash: $hash, name: $name, category: $category, '
      'savePath: $savePath)';
}
