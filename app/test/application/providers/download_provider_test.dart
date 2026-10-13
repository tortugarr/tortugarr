import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/download_provider.dart';
import 'package:moonfin/data/services/jellyfin_refresh_service.dart';
import 'package:moonfin/domain/models/download_management.dart';
import 'package:moonfin/domain/repositories/download_manager_repository.dart';

class _MockDownloadRepository extends Mock
    implements DownloadManagerRepository {}

class _MockJellyfinRefreshService extends Mock
    implements JellyfinRefreshService {}

const String _magnet = 'magnet:?xt=urn:btih:C1A2B3D4E5F60718293A4B5C6D7E8F90';
const String _hashA = 'c1a2b3d4e5f60718293a4b5c6d7e8f90';
const String _hashB = 'ff11223344556677889900aabbccddee';

/// Wound right down so the polling tests finish in milliseconds.
const Duration _tick = Duration(milliseconds: 5);

const DownloadRequest _request = DownloadRequest(
  magnetUri: _magnet,
  category: 'radarr',
  savePath: '/downloads/radarr',
);

Download _download(String hash, {double progress = 0.25}) => Download(
      hash: hash,
      name: 'release-$hash',
      progress: progress,
      state: DownloadState.downloading,
      startedAt: DateTime.utc(2026, 9, 8, 10),
      eta: const Duration(minutes: 5),
    );

void main() {
  late _MockDownloadRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _MockDownloadRepository();
    container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  void keepAlive<T>(ProviderListenable<T> provider) {
    final subscription = container.listen<T>(provider, (_, _) {});
    addTearDown(subscription.close);
  }

  group('startDownloadProvider', () {
    test('starts the torrent and tracks the returned hash', () async {
      when(() => repository.startDownload(any(), any(), any()))
          .thenAnswer((_) async => _hashA);

      final hash = await container.read(startDownloadProvider(_request).future);

      expect(hash, _hashA);
      expect(container.read(activeDownloadHashesProvider), <String>[_hashA]);
      verify(
        () => repository.startDownload(_magnet, 'radarr', '/downloads/radarr'),
      ).called(1);
    });

    test('does not track the same hash twice', () async {
      when(() => repository.startDownload(any(), any(), any()))
          .thenAnswer((_) async => _hashA);
      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA];

      await container.read(startDownloadProvider(_request).future);

      expect(container.read(activeDownloadHashesProvider), <String>[_hashA]);
    });

    test('leaves the tracked hashes alone when the client rejects the magnet',
        () async {
      when(() => repository.startDownload(any(), any(), any()))
          .thenThrow(Exception('qBittorrent refused the magnet'));

      await expectLater(
        container.read(startDownloadProvider(_request).future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(activeDownloadHashesProvider), isEmpty);
    });
  });

  group('stopDownloadProvider', () {
    test('stops the torrent and drops it from the tracked hashes', () async {
      when(() => repository.stopDownload(any())).thenAnswer((_) async {});
      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA, _hashB];

      await container.read(stopDownloadProvider(_hashA).future);

      expect(container.read(activeDownloadHashesProvider), <String>[_hashB]);
      verify(() => repository.stopDownload(_hashA)).called(1);
    });

    test('keeps the hash tracked when the client fails to stop it', () async {
      when(() => repository.stopDownload(any()))
          .thenThrow(Exception('qBittorrent unreachable'));
      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA];

      await expectLater(
        container.read(stopDownloadProvider(_hashA).future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(activeDownloadHashesProvider), <String>[_hashA]);
    });
  });

  group('allDownloadsProvider', () {
    test('yields an empty list and watches nothing when no hash is tracked',
        () async {
      keepAlive(allDownloadsProvider);

      final downloads = await container.read(allDownloadsProvider.future);

      expect(downloads, isEmpty);
      verifyNever(() => repository.watchDownloadProgress(any()));
    });

    test('merges every tracked hash into one ordered snapshot', () async {
      final a = StreamController<Download>();
      final b = StreamController<Download>();
      addTearDown(a.close);
      addTearDown(b.close);

      when(() => repository.watchDownloadProgress(_hashA))
          .thenAnswer((_) => a.stream);
      when(() => repository.watchDownloadProgress(_hashB))
          .thenAnswer((_) => b.stream);

      final snapshots = <List<Download>>[];
      final subscription = container.listen<AsyncValue<List<Download>>>(
        allDownloadsProvider,
        (_, next) {
          final value = next.valueOrNull;
          if (value != null) snapshots.add(value);
        },
      );
      addTearDown(subscription.close);

      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA, _hashB];
      // Force the provider to rebuild against the new hash list.
      container.read(allDownloadsProvider);

      b.add(_download(_hashB, progress: 0.9));
      await Future<void>.delayed(Duration.zero);
      a.add(_download(_hashA, progress: 0.1));
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.last.map((d) => d.hash).toList(), <String>[
        _hashA,
        _hashB,
      ]);
      expect(snapshots.last.map((d) => d.progress).toList(), <double>[
        0.1,
        0.9,
      ]);
      verify(() => repository.watchDownloadProgress(_hashA)).called(1);
      verify(() => repository.watchDownloadProgress(_hashB)).called(1);
    });

    test('forwards a stream failure so the UI can render AsyncError', () async {
      final a = StreamController<Download>();
      addTearDown(a.close);
      when(() => repository.watchDownloadProgress(_hashA))
          .thenAnswer((_) => a.stream);

      final subscription = container.listen<AsyncValue<List<Download>>>(
        allDownloadsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA];
      container.read(allDownloadsProvider);

      a.addError(Exception('polling failed'));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(allDownloadsProvider).hasError, isTrue);
    });

    test('stops watching a hash that is no longer tracked', () async {
      final a = StreamController<Download>();
      addTearDown(a.close);
      when(() => repository.watchDownloadProgress(_hashA))
          .thenAnswer((_) => a.stream);

      final subscription = container.listen<AsyncValue<List<Download>>>(
        allDownloadsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA];
      container.read(allDownloadsProvider);
      expect(a.hasListener, isTrue);

      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[];
      container.read(allDownloadsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(a.hasListener, isFalse);
      expect(container.read(allDownloadsProvider).valueOrNull, isEmpty);
    });

    test('closes once every source stream has closed', () async {
      final a = StreamController<Download>();
      final b = StreamController<Download>();
      when(() => repository.watchDownloadProgress(_hashA))
          .thenAnswer((_) => a.stream);
      when(() => repository.watchDownloadProgress(_hashB))
          .thenAnswer((_) => b.stream);

      final subscription = container.listen<AsyncValue<List<Download>>>(
        allDownloadsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      container.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA, _hashB];
      container.read(allDownloadsProvider);

      a.add(_download(_hashA, progress: 1.0));
      await Future<void>.delayed(Duration.zero);
      await a.close();
      await Future<void>.delayed(Duration.zero);

      // One source is done, the other is not: the merged snapshot survives.
      expect(container.read(allDownloadsProvider).valueOrNull, hasLength(1));

      await b.close();
      await Future<void>.delayed(Duration.zero);

      // Closing does not clear the last snapshot, it just stops updating it.
      expect(container.read(allDownloadsProvider).valueOrNull, hasLength(1));
      expect(container.read(allDownloadsProvider).hasError, isFalse);
    });
  });

  group('downloadDiscoveryProvider', () {
    /// A fresh container whose polling loop runs at [_tick].
    ProviderContainer fastPolling() {
      final fast = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          downloadDiscoveryIntervalProvider.overrideWithValue(_tick),
        ],
      );
      addTearDown(fast.dispose);
      return fast;
    }

    test('adopts torrents the client is already running', () async {
      when(() => repository.listActiveDownloads())
          .thenAnswer((_) async => <Download>[_download(_hashA)]);

      final fast = fastPolling();
      final subscription = fast.listen<AsyncValue<List<String>>>(
        downloadDiscoveryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final firstTick = await fast.read(downloadDiscoveryProvider.future);

      expect(firstTick, <String>[_hashA]);
      expect(fast.read(activeDownloadHashesProvider), <String>[_hashA]);
    });

    test('reports a hash on the tick it appears and never again', () async {
      var poll = 0;
      when(() => repository.listActiveDownloads()).thenAnswer((_) async {
        poll += 1;
        // Torrent B is what Radarr handed qBittorrent after the request went
        // in — it did not exist when the first poll ran.
        return poll == 1
            ? <Download>[_download(_hashA)]
            : <Download>[_download(_hashA), _download(_hashB)];
      });

      final fast = fastPolling();
      final ticks = <List<String>>[];
      final subscription = fast.listen<AsyncValue<List<String>>>(
        downloadDiscoveryProvider,
        (_, next) {
          final value = next.valueOrNull;
          if (value != null) ticks.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      // Long enough for several polls at _tick, without pinning an exact count.
      await Future<void>.delayed(_tick * 12);

      expect(ticks.length, greaterThanOrEqualTo(3));
      expect(ticks[0], <String>[_hashA]);
      expect(ticks[1], <String>[_hashB]);
      expect(
        ticks.skip(2),
        everyElement(isEmpty),
        reason: 'a hash already seen must not be reported a second time',
      );
      expect(fast.read(activeDownloadHashesProvider), <String>[_hashA, _hashB]);
    });

    test('keeps polling after the client fails to answer', () async {
      var poll = 0;
      when(() => repository.listActiveDownloads()).thenAnswer((_) async {
        poll += 1;
        if (poll == 1) throw Exception('qBittorrent unreachable');
        return <Download>[_download(_hashA)];
      });

      final fast = fastPolling();
      final subscription = fast.listen<AsyncValue<List<String>>>(
        downloadDiscoveryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final firstTick = await fast.read(downloadDiscoveryProvider.future);

      expect(
        firstTick,
        <String>[_hashA],
        reason: 'the failed poll is skipped, not fatal',
      );
      expect(fast.read(activeDownloadHashesProvider), <String>[_hashA]);
      expect(fast.read(downloadDiscoveryProvider).hasError, isFalse);
    });

    test('does not re-add a hash that startDownloadProvider already tracks',
        () async {
      when(() => repository.listActiveDownloads())
          .thenAnswer((_) async => <Download>[_download(_hashA)]);

      final fast = fastPolling();
      fast.read(activeDownloadHashesProvider.notifier).state =
          const <String>[_hashA];

      final subscription = fast.listen<AsyncValue<List<String>>>(
        downloadDiscoveryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await fast.read(downloadDiscoveryProvider.future);

      expect(fast.read(activeDownloadHashesProvider), <String>[_hashA]);
    });
  });

  group('downloadWithRefreshProvider', () {
    late _MockJellyfinRefreshService jellyfin;
    late StreamController<List<Download>> downloads;
    late ProviderContainer refreshing;

    setUp(() {
      jellyfin = _MockJellyfinRefreshService();
      when(() => jellyfin.refreshLibrary()).thenAnswer((_) async {});

      downloads = StreamController<List<Download>>.broadcast();
      addTearDown(downloads.close);

      refreshing = ProviderContainer(
        overrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          jellyfinRefreshServiceProvider.overrideWithValue(jellyfin),
          allDownloadsProvider.overrideWith((ref) => downloads.stream),
        ],
      );
      addTearDown(refreshing.dispose);

      // autoDispose: without a listener the notifier is torn down the instant
      // it is built and never sees a snapshot.
      final subscription = refreshing.listen<Set<String>>(
        downloadWithRefreshProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
    });

    /// Pushes [snapshot] and lets the notifier's async work drain.
    Future<void> emit(List<Download> snapshot) async {
      downloads.add(snapshot);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('asks Jellyfin to rescan once a download reaches 100%', () async {
      await emit(<Download>[_download(_hashA, progress: 0.4)]);
      verifyNever(() => jellyfin.refreshLibrary());

      await emit(<Download>[_download(_hashA, progress: 1.0)]);

      verify(() => jellyfin.refreshLibrary()).called(1);
      expect(refreshing.read(downloadWithRefreshProvider), <String>{_hashA});
    });

    test('refreshes once per hash however many snapshots repeat it', () async {
      await emit(<Download>[_download(_hashA, progress: 1.0)]);
      await emit(<Download>[_download(_hashA, progress: 1.0)]);
      await emit(<Download>[_download(_hashA, progress: 1.0)]);

      verify(() => jellyfin.refreshLibrary()).called(1);
    });

    test('refreshes exactly once for each of several completions', () async {
      await emit(<Download>[
        _download(_hashA, progress: 1.0),
        _download(_hashB, progress: 0.6),
      ]);
      verify(() => jellyfin.refreshLibrary()).called(1);

      await emit(<Download>[
        _download(_hashA, progress: 1.0),
        _download(_hashB, progress: 1.0),
      ]);

      verify(() => jellyfin.refreshLibrary()).called(1);
      expect(
        refreshing.read(downloadWithRefreshProvider),
        <String>{_hashA, _hashB},
      );
    });

    test('swallows a Jellyfin failure instead of failing the download',
        () async {
      when(() => jellyfin.refreshLibrary())
          .thenThrow(const JellyfinRefreshException('Jellyfin is down'));

      await emit(<Download>[_download(_hashA, progress: 1.0)]);

      verify(() => jellyfin.refreshLibrary()).called(1);
      expect(refreshing.read(downloadWithRefreshProvider), <String>{_hashA});
    });
  });

  group('DownloadRequest', () {
    test('has value equality so family entries are not duplicated', () {
      const other = DownloadRequest(
        magnetUri: _magnet,
        category: 'radarr',
        savePath: '/downloads/radarr',
      );

      expect(other, _request);
      expect(other.hashCode, _request.hashCode);
    });
  });
}
