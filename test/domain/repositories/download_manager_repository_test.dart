import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/models/dto/qbittorrent_dto.dart';
import 'package:moonfin/data/repositories/download_manager_repository_impl.dart';
import 'package:moonfin/data/services/qbittorrent_enhanced_service.dart';
import 'package:moonfin/domain/models/download_management.dart';
import 'package:moonfin/domain/repositories/download_manager_repository.dart';

class _MockQBittorrentService extends Mock
    implements QBittorrentEnhancedService {}

const String _magnet = 'magnet:?xt=urn:btih:C1A2B3D4E5F60718293A4B5C6D7E8F90'
    '&dn=Dune.Part.Two.2024.2160p';
const String _hash = 'c1a2b3d4e5f60718293a4b5c6d7e8f90';

TorrentProgressDto _progress({
  String hash = _hash,
  String name = 'Dune.Part.Two.2024.2160p',
  double progress = 0.5,
  String state = 'downloading',
  double seedRatio = 0.0,
  Duration eta = const Duration(minutes: 10),
}) =>
    TorrentProgressDto(
      hash: hash,
      name: name,
      progress: progress,
      uploadedBytes: 512,
      totalBytes: 4096,
      state: state,
      seedRatio: seedRatio,
      eta: eta,
    );

void main() {
  late _MockQBittorrentService qbittorrent;
  late DownloadManagerRepository repository;
  late DateTime clock;

  setUp(() {
    qbittorrent = _MockQBittorrentService();
    clock = DateTime.utc(2026, 9, 8, 10, 0);
    repository = DownloadManagerRepositoryImpl(
      qbittorrent: qbittorrent,
      now: () => clock,
    );
  });

  group('startDownload', () {
    test('forwards the magnet, category and path and returns the hash',
        () async {
      when(() => qbittorrent.addTorrent(any(), any(), any()))
          .thenAnswer((_) async => _hash);

      final hash = await repository.startDownload(
        _magnet,
        'radarr',
        '/downloads/radarr',
      );

      expect(hash, _hash);
      verify(
        () => qbittorrent.addTorrent(_magnet, 'radarr', '/downloads/radarr'),
      ).called(1);
    });

    test('lets a QBittorrentServiceException through unchanged', () async {
      const failure = QBittorrentServiceException(
        "Unsupported category 'lidarr'",
      );
      when(() => qbittorrent.addTorrent(any(), any(), any()))
          .thenThrow(failure);

      await expectLater(
        repository.startDownload(_magnet, 'lidarr', '/downloads'),
        throwsA(same(failure)),
      );
    });

    test('stamps startedAt at add time, not at the first poll', () async {
      when(() => qbittorrent.addTorrent(any(), any(), any()))
          .thenAnswer((_) async => _hash);
      when(() => qbittorrent.monitorTorrent(any()))
          .thenAnswer((_) => Stream.value(_progress()));

      final addedAt = clock;
      await repository.startDownload(_magnet, 'radarr', '/downloads/radarr');

      // Two minutes pass before anything watches the hash.
      clock = clock.add(const Duration(minutes: 2));
      final download = await repository.watchDownloadProgress(_hash).first;

      expect(download.startedAt, addedAt);
    });
  });

  group('watchDownloadProgress', () {
    test('maps a progress DTO onto Download', () async {
      when(() => qbittorrent.monitorTorrent(any()))
          .thenAnswer((_) => Stream.value(_progress()));

      final download = await repository.watchDownloadProgress(_hash).first;

      expect(download.hash, _hash);
      expect(download.name, 'Dune.Part.Two.2024.2160p');
      expect(download.progress, 0.5);
      expect(download.progressPercent, 50);
      expect(download.state, DownloadState.downloading);
      expect(download.state.isActive, isTrue);
      expect(download.startedAt, clock);
      expect(download.completedAt, isNull);
      expect(download.isCompleted, isFalse);
      expect(download.etaSeconds, 600);
      expect(download.hasEta, isTrue);
    });

    test('lower-cases the hash it reports', () async {
      when(() => qbittorrent.monitorTorrent(any())).thenAnswer(
        (_) => Stream.value(_progress(hash: _hash.toUpperCase())),
      );

      final download =
          await repository.watchDownloadProgress(_hash.toUpperCase()).first;

      expect(download.hash, _hash);
    });

    test('collapses the qBittorrent state strings onto DownloadState',
        () async {
      Future<DownloadState> stateFor(String raw, {double progress = 0.5}) async {
        when(() => qbittorrent.monitorTorrent(any())).thenAnswer(
          (_) => Stream.value(_progress(state: raw, progress: progress)),
        );
        final download = await repository.watchDownloadProgress(_hash).first;
        return download.state;
      }

      expect(await stateFor('downloading'), DownloadState.downloading);
      expect(await stateFor('metaDL'), DownloadState.downloading);
      expect(await stateFor('stalledDL'), DownloadState.downloading);
      expect(await stateFor('allocating'), DownloadState.allocating);
      expect(await stateFor('uploading', progress: 1.0),
          DownloadState.seeding);
      expect(await stateFor('stalledUP', progress: 1.0),
          DownloadState.seeding);
      expect(await stateFor('pausedDL'), DownloadState.paused);
      expect(await stateFor('stoppedDL'), DownloadState.paused);
      expect(await stateFor('pausedUP', progress: 1.0),
          DownloadState.completed);
      expect(await stateFor('stoppedUP', progress: 1.0),
          DownloadState.completed);
      expect(await stateFor('error'), DownloadState.stopped);
      expect(await stateFor('missingFiles'), DownloadState.stopped);
      // A paused torrent already at 100% has nothing left to resume.
      expect(await stateFor('pausedDL', progress: 1.0),
          DownloadState.completed);
      // An unrecognised label must not invent progress.
      expect(await stateFor('teleporting'), DownloadState.stopped);
      expect(await stateFor('teleporting', progress: 1.0),
          DownloadState.completed);
    });

    test("folds qBittorrent's infinite-ETA sentinel to no ETA", () async {
      when(() => qbittorrent.monitorTorrent(any())).thenAnswer(
        (_) => Stream.value(
          _progress(eta: const Duration(seconds: unknownEtaSeconds)),
        ),
      );

      final download = await repository.watchDownloadProgress(_hash).first;

      expect(download.etaSeconds, 0);
      expect(download.hasEta, isFalse);
    });

    test('holds startedAt stable and stamps completedAt once', () async {
      final controller = StreamController<TorrentProgressDto>();
      when(() => qbittorrent.monitorTorrent(any()))
          .thenAnswer((_) => controller.stream);

      final downloads = <Download>[];
      final subscription =
          repository.watchDownloadProgress(_hash).listen(downloads.add);

      final firstSeen = clock;
      controller.add(_progress(progress: 0.25));
      await Future<void>.delayed(Duration.zero);

      clock = clock.add(const Duration(minutes: 5));
      controller.add(_progress(progress: 0.75));
      await Future<void>.delayed(Duration.zero);

      final completedAt = clock = clock.add(const Duration(minutes: 5));
      controller.add(
        _progress(progress: 1.0, state: 'uploading', eta: Duration.zero),
      );
      await Future<void>.delayed(Duration.zero);

      // A later tick must not move the completion timestamp.
      clock = clock.add(const Duration(minutes: 5));
      controller.add(
        _progress(progress: 1.0, state: 'uploading', eta: Duration.zero),
      );
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      await controller.close();

      expect(downloads, hasLength(4));
      expect(downloads.map((d) => d.startedAt), everyElement(firstSeen));
      expect(downloads[0].completedAt, isNull);
      expect(downloads[1].completedAt, isNull);
      expect(downloads[2].completedAt, completedAt);
      expect(downloads[3].completedAt, completedAt);
      expect(downloads.last.isCompleted, isTrue);
      expect(downloads.last.hasEta, isFalse);
    });

    test('clears completedAt when a torrent drops back below 100%', () async {
      final controller = StreamController<TorrentProgressDto>();
      when(() => qbittorrent.monitorTorrent(any()))
          .thenAnswer((_) => controller.stream);

      final downloads = <Download>[];
      final subscription =
          repository.watchDownloadProgress(_hash).listen(downloads.add);

      controller.add(_progress(progress: 1.0, state: 'pausedUP'));
      await Future<void>.delayed(Duration.zero);
      // A recheck put the torrent back to work.
      controller.add(_progress(progress: 0.9, state: 'checkingDL'));
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      await controller.close();

      expect(downloads.first.completedAt, isNotNull);
      expect(downloads.last.completedAt, isNull);
      expect(downloads.last.state, DownloadState.downloading);
    });

    test('forwards a service error as a stream error', () async {
      const failure = QBittorrentServiceException(
        'qBittorrent progress poll failed: could not reach host',
      );
      when(() => qbittorrent.monitorTorrent(any()))
          .thenAnswer((_) => Stream.error(failure));

      await expectLater(
        repository.watchDownloadProgress(_hash),
        emitsError(same(failure)),
      );
    });
  });

  group('stopDownload', () {
    test('removes the torrent and cancels its monitor', () async {
      when(() => qbittorrent.stopSeeding(any())).thenAnswer((_) async {});
      when(() => qbittorrent.cancelMonitor(any())).thenAnswer((_) async {});

      await repository.stopDownload(_hash);

      verifyInOrder([
        () => qbittorrent.stopSeeding(_hash),
        () => qbittorrent.cancelMonitor(_hash),
      ]);
    });

    test('cancels the monitor even when the removal fails, and rethrows',
        () async {
      const failure = QBittorrentServiceException(
        'qBittorrent seeding stop failed: server responded 403',
        statusCode: 403,
      );
      when(() => qbittorrent.stopSeeding(any())).thenThrow(failure);
      when(() => qbittorrent.cancelMonitor(any())).thenAnswer((_) async {});

      await expectLater(
        repository.stopDownload(_hash),
        throwsA(same(failure)),
      );
      verify(() => qbittorrent.cancelMonitor(_hash)).called(1);
    });
  });

  group('listActiveDownloads', () {
    test('maps the listing DTOs onto Download', () async {
      when(() => qbittorrent.listTorrents()).thenAnswer(
        (_) async => const [
          QBittorrentTorrentDto(
            hash: _hash,
            name: 'Dune.Part.Two.2024.2160p',
            category: 'radarr',
            savePath: '/downloads/radarr',
          ),
          QBittorrentTorrentDto(
            hash: 'ffee0011',
            name: 'Shogun.S01E01.1080p',
            category: 'sonarr',
            savePath: '/downloads/sonarr',
          ),
        ],
      );

      final downloads = await repository.listActiveDownloads();

      expect(downloads.map((d) => d.hash), [_hash, 'ffee0011']);
      expect(downloads.first.name, 'Dune.Part.Two.2024.2160p');
      // The listing endpoint carries no progress fields — callers wanting
      // live figures watch the hash instead.
      expect(downloads.every((d) => d.progress == 0), isTrue);
      expect(
        downloads.every((d) => d.state == DownloadState.stopped),
        isTrue,
      );
      expect(downloads.first.startedAt, clock);
    });

    test('reuses a startedAt already stamped by startDownload', () async {
      when(() => qbittorrent.addTorrent(any(), any(), any()))
          .thenAnswer((_) async => _hash);
      when(() => qbittorrent.listTorrents()).thenAnswer(
        (_) async => const [
          QBittorrentTorrentDto(
            hash: _hash,
            name: 'Dune.Part.Two.2024.2160p',
            category: 'radarr',
            savePath: '/downloads/radarr',
          ),
        ],
      );

      final addedAt = clock;
      await repository.startDownload(_magnet, 'radarr', '/downloads/radarr');
      clock = clock.add(const Duration(hours: 1));

      final downloads = await repository.listActiveDownloads();

      expect(downloads.single.startedAt, addedAt);
    });

    test('lets a QBittorrentServiceException through unchanged', () async {
      const failure = QBittorrentServiceException(
        'qBittorrent torrent listing failed: could not reach host',
      );
      when(() => qbittorrent.listTorrents()).thenThrow(failure);

      await expectLater(
        repository.listActiveDownloads(),
        throwsA(same(failure)),
      );
    });
  });

  group('domain model behaviour', () {
    test('Download compares by value', () {
      final download = Download(
        hash: _hash,
        name: 'Dune',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.utc(2026),
      );

      expect(download, equals(download.copyWith()));
      expect(download.hashCode, download.copyWith().hashCode);
      expect(download, isNot(equals(download.copyWith(progress: 0.6))));
    });

    test('DownloadState answers the questions the UI asks', () {
      expect(DownloadState.seeding.isActive, isTrue);
      expect(DownloadState.seeding.isFinished, isTrue);
      expect(DownloadState.completed.isActive, isFalse);
      expect(DownloadState.completed.isFinished, isTrue);
      expect(DownloadState.paused.isActive, isFalse);
      expect(DownloadState.paused.isFinished, isFalse);
      expect(DownloadState.allocating.toDisplay(), 'Allocating');
    });
  });
}
