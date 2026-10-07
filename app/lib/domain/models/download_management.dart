/// Domain models for the download side of the discovery flow.
///
/// Pure Dart — the qBittorrent DTOs and their wire quirks stay behind
/// `DownloadManagerRepositoryImpl`, which maps them into these.
library;

/// The lifecycle states the download UI distinguishes.
///
/// qBittorrent reports roughly twenty state strings; they collapse into these
/// six because the UI only ever needs to answer "is it moving, waiting,
/// finished, or dead?". [DownloadState.stopped] is the terminal bucket and
/// also absorbs qBittorrent's error states, which have no separate tier here.
enum DownloadState {
  /// Payload is being fetched (including stalled, queued and checking).
  downloading,

  /// qBittorrent is reserving disk space before the transfer starts.
  allocating,

  /// Payload is complete and is being uploaded back to peers.
  seeding,

  /// Transfer is suspended by the user, with the payload still incomplete.
  paused,

  /// Payload is complete and the torrent is no longer seeding.
  completed,

  /// Terminal and not running — removed, errored or unrecognised.
  stopped;

  /// True while the torrent is still doing work on the payload.
  bool get isActive =>
      this == DownloadState.downloading ||
      this == DownloadState.allocating ||
      this == DownloadState.seeding;

  /// True once the payload is finished, regardless of seeding.
  bool get isFinished =>
      this == DownloadState.completed || this == DownloadState.seeding;

  /// Label for the UI.
  String toDisplay() => switch (this) {
        DownloadState.downloading => 'Downloading',
        DownloadState.allocating => 'Allocating',
        DownloadState.seeding => 'Seeding',
        DownloadState.paused => 'Paused',
        DownloadState.completed => 'Completed',
        DownloadState.stopped => 'Stopped',
      };
}

/// One torrent as the app tracks it.
class Download {
  /// Info hash, lower-case hex — the handle every repository method takes.
  final String hash;

  final String name;

  /// Completion in the range 0.0–1.0.
  final double progress;

  final DownloadState state;

  /// When this app first observed the download.
  ///
  /// qBittorrent's `/torrents/info` payload is not carried through the DTO
  /// layer, so this is stamped by the repository the first time a hash is
  /// seen and then held stable for the rest of the session.
  final DateTime startedAt;

  /// When the payload first reached 100%, or null while it is still running.
  final DateTime? completedAt;

  /// Time remaining, or [Duration.zero] when it is not known yet.
  ///
  /// Not part of the plan's constructor signature, so it is optional: the
  /// plan asks for an [etaSeconds] getter and this is the only field that can
  /// honestly answer it. The repository folds qBittorrent's "infinite ETA"
  /// sentinel to zero before it gets here, so callers gate on [hasEta] rather
  /// than comparing against a magic number.
  final Duration eta;

  const Download({
    required this.hash,
    required this.name,
    required this.progress,
    required this.state,
    required this.startedAt,
    this.completedAt,
    this.eta = Duration.zero,
  });

  /// True once the payload is fully downloaded.
  bool get isCompleted => progress >= 1.0;

  /// Seconds remaining, or 0 when qBittorrent has no estimate — check
  /// [hasEta] before showing this to a user.
  int get etaSeconds => eta.inSeconds < 0 ? 0 : eta.inSeconds;

  /// False while there is no meaningful estimate to display.
  bool get hasEta => etaSeconds > 0 && !isCompleted;

  /// Completion as a 0–100 integer, for progress labels.
  int get progressPercent => (progress.clamp(0.0, 1.0) * 100).round();

  Download copyWith({
    String? hash,
    String? name,
    double? progress,
    DownloadState? state,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? eta,
  }) =>
      Download(
        hash: hash ?? this.hash,
        name: name ?? this.name,
        progress: progress ?? this.progress,
        state: state ?? this.state,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        eta: eta ?? this.eta,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Download &&
          other.hash == hash &&
          other.name == name &&
          other.progress == progress &&
          other.state == state &&
          other.startedAt == startedAt &&
          other.completedAt == completedAt &&
          other.eta == eta;

  @override
  int get hashCode =>
      Object.hash(hash, name, progress, state, startedAt, completedAt, eta);

  @override
  String toString() => 'Download(hash: $hash, name: $name, '
      'progress: $progress, state: ${state.name})';
}
