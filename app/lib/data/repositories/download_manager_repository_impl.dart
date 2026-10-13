import '../../domain/models/download_management.dart';
import '../../domain/repositories/download_manager_repository.dart';
import '../models/dto/qbittorrent_dto.dart';
import '../services/qbittorrent_enhanced_service.dart';

/// [DownloadManagerRepository] backed by [QBittorrentEnhancedService].
///
/// Deliberately thin: it calls the service and translates DTOs into domain
/// models. A [QBittorrentServiceException] travels straight through to the
/// caller — and, for [watchDownloadProgress], straight through the stream.
///
/// The one piece of state it keeps is timestamps. `/api/v2/torrents/info`
/// carries `added_on`, but [TorrentProgressDto] does not surface it, so
/// [Download.startedAt] is stamped the first time a hash is seen and then held
/// stable; [Download.completedAt] is stamped the first time that hash reports
/// 100%. Both are per-process, so they reset on restart.
class DownloadManagerRepositoryImpl implements DownloadManagerRepository {
  final QBittorrentEnhancedService _qbittorrent;

  /// Injectable clock so tests get deterministic timestamps.
  final DateTime Function() _now;

  final Map<String, DateTime> _startedAt = {};
  final Map<String, DateTime> _completedAt = {};

  DownloadManagerRepositoryImpl({
    required QBittorrentEnhancedService qbittorrent,
    DateTime Function()? now,
  })  : _qbittorrent = qbittorrent,
        _now = now ?? DateTime.now;

  @override
  Future<String> startDownload(
    String magnetUri,
    String category,
    String savePath,
  ) async {
    final hash = await _qbittorrent.addTorrent(magnetUri, category, savePath);

    // Stamp the start now rather than on the first poll, which may be seconds
    // later or never arrive if the caller does not watch the hash.
    _startedAt.putIfAbsent(_key(hash), _now);
    return hash;
  }

  @override
  Stream<Download> watchDownloadProgress(String hash) {
    return _qbittorrent.monitorTorrent(hash).map(_toDownload);
  }

  @override
  Future<void> stopDownload(String hash) async {
    try {
      await _qbittorrent.stopSeeding(hash);
    } finally {
      // Whether or not qBittorrent accepted the removal, the caller asked to
      // stop: leaving the polling timer alive would keep hitting a torrent
      // nobody is watching any more.
      await _qbittorrent.cancelMonitor(hash);
      _forget(_key(hash));
    }
  }

  @override
  Future<List<Download>> listActiveDownloads() async {
    final dtos = await _qbittorrent.listTorrents();
    return dtos.map(_toListedDownload).toList(growable: false);
  }

  // --- mapping -----------------------------------------------------------

  Download _toDownload(TorrentProgressDto dto) {
    final key = _key(dto.hash);
    final startedAt = _startedAt.putIfAbsent(key, _now);

    final DateTime? completedAt;
    if (dto.isComplete) {
      completedAt = _completedAt.putIfAbsent(key, _now);
    } else {
      // A torrent that went back below 100% (a recheck, say) is running
      // again, so the old completion time must not linger.
      _completedAt.remove(key);
      completedAt = null;
    }

    return Download(
      hash: key,
      name: dto.name,
      progress: dto.progress,
      state: _parseDownloadState(dto.state, dto.progress),
      startedAt: startedAt,
      completedAt: completedAt,
      // Folds qBittorrent's "infinite ETA" sentinel to zero so the domain
      // model never has to know the magic number.
      eta: dto.hasEta ? dto.eta : Duration.zero,
    );
  }

  /// Maps a listing entry, which carries no progress or state fields.
  ///
  /// [QBittorrentTorrentDto] only has hash, name, category and save path, so
  /// these come back at 0.0 in [DownloadState.stopped]. Call
  /// [watchDownloadProgress] for live figures on a specific hash.
  Download _toListedDownload(QBittorrentTorrentDto dto) {
    final key = _key(dto.hash);
    return Download(
      hash: key,
      name: dto.name,
      progress: 0,
      state: DownloadState.stopped,
      startedAt: _startedAt.putIfAbsent(key, _now),
      completedAt: _completedAt[key],
    );
  }

  /// Collapses qBittorrent's ~20 state strings onto [DownloadState].
  ///
  /// [progress] disambiguates the paused/stopped pair: qBittorrent 4.x says
  /// `pausedUP` and 5.x says `stoppedUP` for the same "finished, not
  /// seeding" condition, and the suffix alone is not reliable across builds.
  DownloadState _parseDownloadState(String raw, double progress) {
    final state = raw.trim().toLowerCase();
    final isComplete = progress >= 1.0;

    switch (state) {
      case 'allocating':
        return DownloadState.allocating;

      case 'downloading':
      case 'metadl':
      case 'forceddl':
      case 'queueddl':
      case 'stalleddl':
      case 'checkingdl':
      case 'checkingresumedata':
      case 'moving':
        return DownloadState.downloading;

      case 'uploading':
      case 'forcedup':
      case 'queuedup':
      case 'stalledup':
      case 'checkingup':
        return DownloadState.seeding;

      case 'pauseddl':
      case 'stoppeddl':
        // A "paused" torrent that is actually at 100% has nothing left to
        // resume, so report it as finished rather than as suspended work.
        return isComplete ? DownloadState.completed : DownloadState.paused;

      case 'pausedup':
      case 'stoppedup':
        return DownloadState.completed;

      case 'error':
      case 'missingfiles':
      case 'unknown':
        return DownloadState.stopped;

      default:
        // An unrecognised state is not an excuse to claim progress. Trust the
        // percentage instead of the label.
        return isComplete ? DownloadState.completed : DownloadState.stopped;
    }
  }

  void _forget(String key) {
    _startedAt.remove(key);
    _completedAt.remove(key);
  }

  /// qBittorrent is case-insensitive about hashes; the domain is not.
  String _key(String hash) => hash.trim().toLowerCase();
}
