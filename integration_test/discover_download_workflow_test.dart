/// End-to-end cover for the discover → download → Jellyfin refresh workflow.
///
/// Everything below the mocks is real: the router, the four screens, the
/// Riverpod providers and the merge/poll/dedup logic inside them. Only the
/// three edges of the system are doubled —
///
/// * [MediaDiscoveryRepository] stands in for Jellyseerr on
///   `http://localhost:5055`,
/// * [DownloadManagerRepository] for qBittorrent on `:8421`,
/// * [JellyfinRefreshService] for Jellyfin on `:8096`.
///
/// so no test in this file opens a socket. `defaults point at localhost` below
/// pins those three hosts, which is the only claim about the real network this
/// suite is entitled to make.
///
/// Runs under `flutter test integration_test/discover_download_workflow_test.dart`:
/// it drives widgets rather than a device, so it deliberately does not use the
/// `integration_test` package binding.
///
/// ## The gap this exercises
///
/// Submitting a Jellyseerr request does not produce an info hash. Jellyseerr
/// hands the request to Radarr/Sonarr, which hands a release to qBittorrent
/// seconds later, so the torrent the user is waiting for appears *after* the
/// screen they are waiting on. `downloadDiscoveryProvider` is what closes that
/// gap, and the workflow test drives exactly that sequence: submit against an
/// empty client, then let the poll find the torrent Radarr created.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/application/providers/discovery_provider.dart';
import 'package:moonfin/application/providers/download_provider.dart';
import 'package:moonfin/data/services/jellyfin_refresh_service.dart';
import 'package:moonfin/data/services/jellyseerr_service.dart';
import 'package:moonfin/data/services/qbittorrent_enhanced_service.dart';
import 'package:moonfin/domain/models/download_management.dart';
import 'package:moonfin/domain/models/media_discovery.dart';
import 'package:moonfin/domain/repositories/download_manager_repository.dart';
import 'package:moonfin/domain/repositories/media_discovery_repository.dart';
import 'package:moonfin/presentation/features/discover/discover_routes.dart';
import 'package:moonfin/presentation/features/discover/screens/discover_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/file_picker_screen.dart';
import 'package:moonfin/presentation/features/discover/screens/search_results_screen.dart';
import 'package:moonfin/presentation/features/downloads/screens/download_status_screen.dart';
import 'package:moonfin/presentation/features/downloads/widgets/download_progress_card.dart';

class _MockDiscoveryRepository extends Mock
    implements MediaDiscoveryRepository {}

class _MockDownloadRepository extends Mock
    implements DownloadManagerRepository {}

class _MockJellyfinRefreshService extends Mock
    implements JellyfinRefreshService {}

// --- canned backend data ---------------------------------------------------

/// Posters are empty on purpose: an empty [SearchResult.posterPath] renders the
/// local placeholder, so no test reaches out to TMDB.
const SearchResult _dune = SearchResult(
  id: 693134,
  title: 'Dune: Part Two',
  releaseYear: 2024,
  description: 'Paul Atreides unites with the Fremen.',
  posterPath: '',
  mediaType: MediaType.movie,
  rating: 8.2,
);

const SearchResult _severance = SearchResult(
  id: 95396,
  title: 'Severance',
  releaseYear: 2022,
  description: 'Work-life balance, surgically enforced.',
  posterPath: '',
  mediaType: MediaType.tv,
  rating: 8.4,
);

/// The 2160p release with the most seeders — what the workflow test picks.
const FileOption _uhdBestSeeded = FileOption(
  path: 'Dune.Part.Two.2024.2160p.WEB-DL',
  resolution: Resolution.p2160,
  sizeInMb: 22528,
  seeders: 91,
);

const FileOption _uhdPoorlySeeded = FileOption(
  path: 'Dune.Part.Two.2024.2160p.REMUX',
  resolution: Resolution.p2160,
  sizeInMb: 61440,
  seeders: 4,
);

const FileOption _hd = FileOption(
  path: 'Dune.Part.Two.2024.1080p.WEB-DL',
  resolution: Resolution.p1080,
  sizeInMb: 8192,
  seeders: 240,
);

/// Info hash Radarr's grab ends up under in qBittorrent.
const String _duneHash = 'c1a2b3d4e5f60718293a4b5c6d7e8f90';
const String _severanceHash = 'ff11223344556677889900aabbccddee';

const String _duneRelease = 'Dune.Part.Two.2024.2160p.WEB-DL';
const String _severanceRelease = 'Severance.S02E01.1080p.WEB-DL';

/// Short enough that a couple of `pump`s cover several polls.
const Duration _pollInterval = Duration(milliseconds: 20);

final DateTime _startedAt = DateTime.utc(2026, 9, 8, 10);

Download _progress(
  String hash,
  String name, {
  required double progress,
  DownloadState state = DownloadState.downloading,
  Duration eta = const Duration(minutes: 12),
}) =>
    Download(
      hash: hash,
      name: name,
      progress: progress,
      state: state,
      startedAt: _startedAt,
      completedAt: progress >= 1.0 ? _startedAt : null,
      eta: eta,
    );

/// What `/torrents/info` reports: identity only, no progress or state.
Download _listed(String hash, String name) => Download(
      hash: hash,
      name: name,
      progress: 0,
      state: DownloadState.stopped,
      startedAt: _startedAt,
    );

// --- harness ---------------------------------------------------------------

/// The three mocked backends plus the levers a test pulls on them.
class _Pipeline {
  final _MockDiscoveryRepository jellyseerr = _MockDiscoveryRepository();
  final _MockDownloadRepository qbittorrent = _MockDownloadRepository();
  final _MockJellyfinRefreshService jellyfin = _MockJellyfinRefreshService();

  /// What qBittorrent currently reports from `/torrents/info`. Starts empty:
  /// nothing exists until Radarr has grabbed a release.
  final List<Download> running = <Download>[];

  /// Live progress feeds, one per info hash, opened on demand.
  final Map<String, StreamController<Download>> _feeds =
      <String, StreamController<Download>>{};

  int requestsSubmitted = 0;

  _Pipeline() {
    // Jellyseerr.
    when(() => jellyseerr.searchMedia(any()))
        .thenAnswer((_) async => <SearchResult>[_dune, _severance]);
    when(() => jellyseerr.getAvailableFiles(any(), any())).thenAnswer(
      (_) async => <FileOption>[_uhdBestSeeded, _uhdPoorlySeeded, _hd],
    );
    when(() => jellyseerr.requestMedia(any(), any(), any())).thenAnswer(
      (invocation) async {
        requestsSubmitted += 1;
        return MediaRequest(
          id: 4021,
          mediaId: invocation.positionalArguments[0] as int,
          status: MediaRequestStatus.approved,
          requestedAt: _startedAt,
          selectedFiles:
              invocation.positionalArguments[2] as List<FileOption>,
        );
      },
    );

    // qBittorrent.
    when(() => qbittorrent.listActiveDownloads())
        .thenAnswer((_) async => List<Download>.of(running));
    when(() => qbittorrent.watchDownloadProgress(any()))
        .thenAnswer((invocation) {
      final hash = invocation.positionalArguments[0] as String;
      return feed(hash).stream;
    });
    when(() => qbittorrent.stopDownload(any())).thenAnswer((_) async {});

    // Jellyfin.
    when(() => jellyfin.refreshLibrary()).thenAnswer((_) async {});
  }

  /// The progress feed for [hash], created on first use.
  StreamController<Download> feed(String hash) => _feeds.putIfAbsent(
        hash,
        () => StreamController<Download>.broadcast(),
      );

  /// Simulates Radarr/Sonarr handing a release to qBittorrent.
  void radarrGrabs(String hash, String name) =>
      running.add(_listed(hash, name));

  Future<void> dispose() async {
    for (final controller in _feeds.values) {
      await controller.close();
    }
  }

  List<Override> get overrides => <Override>[
        discoveryRepositoryProvider.overrideWithValue(jellyseerr),
        downloadRepositoryProvider.overrideWithValue(qbittorrent),
        jellyfinRefreshServiceProvider.overrideWithValue(jellyfin),
        downloadDiscoveryIntervalProvider.overrideWithValue(_pollInterval),
      ];
}

/// The real four-screen flow behind a router.
///
/// A stand-in for `lib/ui/navigation/app_router.dart` rather than the thing
/// itself, for the reason `test/presentation/features/discover/discover_test_app.dart`
/// records: the real router's import graph reaches screens outside this
/// feature. The routes and the screens behind them are the production ones.
GoRouter _buildRouter() => GoRouter(
      initialLocation: DiscoverRoutes.discover,
      routes: <RouteBase>[
        GoRoute(
          path: DiscoverRoutes.discover,
          builder: (_, _) => const DiscoverScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: DiscoverRoutes.resultsSegment,
              builder: (_, _) => const SearchResultsScreen(),
            ),
            GoRoute(
              path: DiscoverRoutes.filesSegment,
              builder: (_, _) => const FilePickerScreen(),
            ),
            GoRoute(
              path: DiscoverRoutes.downloadingSegment,
              builder: (_, _) => const DownloadStatusScreen(),
            ),
          ],
        ),
      ],
    );

class _Harness {
  _Harness(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Harness> _pumpApp(WidgetTester tester, _Pipeline pipeline) async {
  final router = _buildRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: pipeline.overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    router,
    ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    ),
  );
}

/// Lets the discovery poll fire a few times and the UI catch up.
///
/// Advances the clock by hand rather than calling `pumpAndSettle`, for two
/// reasons: the poll is a timer, and a timer that changes no widget schedules
/// no frame, so settling would never run it; and a torrent adopted mid-flight
/// can leave a [CircularProgressIndicator] on screen, which animates forever
/// and would make `pumpAndSettle` time out rather than settle.
Future<void> _letDiscoveryRun(WidgetTester tester, {int ticks = 4}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(_pollInterval);
    // Drains the microtasks the poll queued (the listing future, the yield,
    // the provider notification) before the clock moves on again.
    await tester.pump();
  }
}

/// Drives search → results → picker → request, leaving the app on
/// `/discover/downloading` with nothing yet running in qBittorrent.
Future<_Harness> _submitRequestFor(
  WidgetTester tester,
  _Pipeline pipeline, {
  String query = 'Dune',
  FileOption release = _uhdBestSeeded,
}) async {
  final harness = await _pumpApp(tester, pipeline);

  await tester.enterText(find.byKey(const Key('discoverSearchField')), query);
  await tester.tap(find.byKey(const Key('discoverSearchButton')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(Key('searchResultCard-${_dune.id}')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(Key('fileOption-${release.path}')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('filePickerSubmitButton')));
  await tester.pumpAndSettle();

  return harness;
}

void main() {
  setUpAll(() {
    registerFallbackValue(MediaType.movie);
    registerFallbackValue(const <FileOption>[]);
  });

  group('Discover → Download → Refresh workflow', () {
    late _Pipeline pipeline;

    setUp(() {
      pipeline = _Pipeline();
      addTearDown(pipeline.dispose);
    });

    testWidgets(
        'search → select → request → download → refresh, end to end',
        (tester) async {
      // --- 1. search -------------------------------------------------------
      final harness = await _pumpApp(tester, pipeline);
      expect(harness.location, DiscoverRoutes.discover);

      await tester.enterText(
        find.byKey(const Key('discoverSearchField')),
        'Dune',
      );
      await tester.tap(find.byKey(const Key('discoverSearchButton')));
      await tester.pumpAndSettle();

      expect(harness.location, DiscoverRoutes.results);
      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.text('Severance'), findsOneWidget);
      verify(() => pipeline.jellyseerr.searchMedia('Dune')).called(1);

      // --- 2. pick the title ----------------------------------------------
      await tester.tap(find.byKey(Key('searchResultCard-${_dune.id}')));
      await tester.pumpAndSettle();

      expect(harness.location, DiscoverRoutes.files);
      verify(
        () => pipeline.jellyseerr.getAvailableFiles(_dune.id, MediaType.movie),
      ).called(1);

      // 2160p comes first and, inside the tier, the best-seeded release does.
      final tiers = tester
          .widgetList<ExpansionTile>(find.byType(ExpansionTile))
          .toList(growable: false);
      expect(tiers, hasLength(2));
      expect((tiers.first.title as Text).data, Resolution.p2160.toDisplay());

      // --- 3. tick the 2160p release with the most seeders -----------------
      await tester.tap(find.byKey(Key('fileOption-${_uhdBestSeeded.path}')));
      await tester.pumpAndSettle();

      expect(
        harness.container.read(selectedFilesProvider),
        <FileOption>[_uhdBestSeeded],
      );
      expect(find.text('Request 1 release'), findsOneWidget);

      // --- 4. submit the request ------------------------------------------
      await tester.tap(find.byKey(const Key('filePickerSubmitButton')));
      await tester.pumpAndSettle();

      expect(harness.location, DiscoverRoutes.downloading);
      verify(
        () => pipeline.jellyseerr.requestMedia(
          _dune.id,
          MediaType.movie,
          <FileOption>[_uhdBestSeeded],
        ),
      ).called(1);
      expect(pipeline.requestsSubmitted, 1);

      // The hash does not exist yet — Radarr has not grabbed anything. The
      // screen must say so rather than inventing a placeholder row.
      expect(find.text('No active downloads'), findsOneWidget);
      expect(harness.container.read(activeDownloadHashesProvider), isEmpty);

      // --- 5. Radarr grabs a release; the poll adopts it -------------------
      pipeline.radarrGrabs(_duneHash, _duneRelease);
      await _letDiscoveryRun(tester);

      expect(
        harness.container.read(activeDownloadHashesProvider),
        <String>[_duneHash],
        reason: 'discovery polling must adopt the torrent Radarr created',
      );

      // --- 6. progress arrives ---------------------------------------------
      pipeline.feed(_duneHash).add(
            _progress(_duneHash, _duneRelease, progress: 0.42),
          );
      await tester.pumpAndSettle();

      expect(find.byType(DownloadProgressCard), findsOneWidget);
      expect(find.text(_duneRelease), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('12m'), findsOneWidget);
      verifyNever(() => pipeline.jellyfin.refreshLibrary());

      // --- 7. it finishes; Jellyfin is told exactly once --------------------
      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.seeding,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Seeding (will stop at 100%)'), findsOneWidget);
      verify(() => pipeline.jellyfin.refreshLibrary()).called(1);

      // Further snapshots of the same finished torrent must not re-scan.
      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await _letDiscoveryRun(tester);

      verifyNoMoreInteractions(pipeline.jellyfin);
      expect(
        harness.container.read(downloadWithRefreshProvider),
        <String>{_duneHash},
      );

      // --- 8. back out; nothing throws on the way -------------------------
      harness.router.go(DiscoverRoutes.discover);
      await tester.pumpAndSettle();

      expect(harness.location, DiscoverRoutes.discover);
      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing qBittorrent poll does not stop the refresh firing',
        (tester) async {
      // The listing endpoint is down, so discovery never adopts anything. The
      // hash still reaches the tracked list the other way — through
      // startDownloadProvider — and completion must still reach Jellyfin.
      when(() => pipeline.qbittorrent.listActiveDownloads())
          .thenThrow(const QBittorrentServiceException('listing unavailable'));
      when(() => pipeline.qbittorrent.startDownload(any(), any(), any()))
          .thenAnswer((_) async => _duneHash);

      final harness = await _submitRequestFor(tester, pipeline);
      await _letDiscoveryRun(tester);

      expect(
        harness.container.read(activeDownloadHashesProvider),
        isEmpty,
        reason: 'a failing listing adopts nothing',
      );
      expect(
        find.text('No active downloads'),
        findsOneWidget,
        reason: 'the poll failure must not be rendered as a screen error',
      );

      await harness.container.read(
        startDownloadProvider(
          const DownloadRequest(
            magnetUri: 'magnet:?xt=urn:btih:$_duneHash',
            category: 'radarr',
            savePath: '/downloads/radarr',
          ),
        ).future,
      );
      await tester.pumpAndSettle();

      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();

      expect(find.byType(DownloadProgressCard), findsOneWidget);
      verify(() => pipeline.jellyfin.refreshLibrary()).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing Jellyfin refresh leaves the download intact',
        (tester) async {
      when(() => pipeline.jellyfin.refreshLibrary())
          .thenThrow(const JellyfinRefreshException('Jellyfin is down'));

      final harness = await _submitRequestFor(tester, pipeline);
      pipeline.radarrGrabs(_duneHash, _duneRelease);
      await _letDiscoveryRun(tester);

      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();

      verify(() => pipeline.jellyfin.refreshLibrary()).called(1);
      // The card is still there, still at 100%, and the screen is not in an
      // error state: a refresh is a hint, not part of the download.
      expect(find.byType(DownloadProgressCard), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.textContaining('Error:'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        harness.container.read(downloadWithRefreshProvider),
        <String>{_duneHash},
        reason: 'a failed scan is still recorded, so it is not retried in a '
            'loop on every subsequent snapshot',
      );
    });

    testWidgets('two downloads complete; each triggers exactly one refresh',
        (tester) async {
      final harness = await _submitRequestFor(tester, pipeline);

      pipeline.radarrGrabs(_duneHash, _duneRelease);
      pipeline.radarrGrabs(_severanceHash, _severanceRelease);
      await _letDiscoveryRun(tester);

      expect(
        harness.container.read(activeDownloadHashesProvider),
        <String>[_duneHash, _severanceHash],
      );

      // Both still running.
      pipeline.feed(_duneHash).add(
            _progress(_duneHash, _duneRelease, progress: 0.8),
          );
      pipeline.feed(_severanceHash).add(
            _progress(_severanceHash, _severanceRelease, progress: 0.3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(DownloadProgressCard), findsNWidgets(2));
      verifyNever(() => pipeline.jellyfin.refreshLibrary());

      // First one lands.
      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();
      verify(() => pipeline.jellyfin.refreshLibrary()).called(1);

      // Repeated snapshots of the finished one, then the second lands.
      pipeline.feed(_duneHash).add(
            _progress(
              _duneHash,
              _duneRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();
      verifyNever(() => pipeline.jellyfin.refreshLibrary());

      pipeline.feed(_severanceHash).add(
            _progress(
              _severanceHash,
              _severanceRelease,
              progress: 1.0,
              state: DownloadState.completed,
              eta: Duration.zero,
            ),
          );
      await tester.pumpAndSettle();

      verify(() => pipeline.jellyfin.refreshLibrary()).called(1);
      expect(
        harness.container.read(downloadWithRefreshProvider),
        <String>{_duneHash, _severanceHash},
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rejected Jellyseerr request keeps the user on the picker',
        (tester) async {
      when(() => pipeline.jellyseerr.requestMedia(any(), any(), any()))
          .thenThrow(const JellyseerrServiceException('no quota left'));

      final harness = await _pumpApp(tester, pipeline);

      await tester.enterText(
        find.byKey(const Key('discoverSearchField')),
        'Dune',
      );
      await tester.tap(find.byKey(const Key('discoverSearchButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('searchResultCard-${_dune.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('fileOption-${_uhdBestSeeded.path}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filePickerSubmitButton')));
      await tester.pumpAndSettle();

      expect(harness.location, DiscoverRoutes.files);
      expect(find.textContaining('Request failed'), findsOneWidget);
      expect(harness.container.read(activeDownloadHashesProvider), isEmpty);
      verifyNever(() => pipeline.jellyfin.refreshLibrary());
      expect(tester.takeException(), isNull);
    });
  });

  group('service configuration', () {
    test('defaults point at localhost', () {
      // The mocks above stand in for these three hosts. If a default moves, the
      // workflow this file covers is no longer the one that ships.
      expect(JellyseerrService.defaultBaseUrl, 'http://localhost:5055');
      expect(
        QBittorrentEnhancedService.defaultBaseUrl,
        'http://localhost:8421',
      );
      expect(JellyfinRefreshService.defaultBaseUrl, 'http://localhost:8096');
    });
  });
}
