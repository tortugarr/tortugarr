/// Riverpod state for the download side of the discovery flow.
///
/// Mirrors `discovery_provider.dart`: [DownloadManagerRepository] is resolved
/// once, the set of tracked torrents is plain state, and live progress is a
/// stream computed from that state. Nothing here knows qBittorrent exists.
///
/// The one exception is [jellyfinRefreshServiceProvider], which resolves the
/// concrete [JellyfinRefreshService] out of the data layer. Triggering a
/// library scan has no domain repository behind it — the service is a one-call
/// trigger, not a client — so there is nothing to abstract over yet. Give it a
/// `domain/repositories/` interface the moment a second implementation or a
/// second caller appears.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../data/services/jellyfin_refresh_service.dart';
import '../../domain/models/download_management.dart';
import '../../domain/repositories/download_manager_repository.dart';

/// The download repository, resolved from GetIt.
///
/// `registerDiscoveryServices()` must have run during app startup before this
/// is first read. Tests override it with
/// `downloadRepositoryProvider.overrideWithValue(fake)`.
///
/// Resolved off `GetIt.instance` for the same reason as
/// `discoveryRepositoryProvider`: same container as `lib/di/injection.dart`'s
/// `getIt`, without pulling the app graph into this layer.
final downloadRepositoryProvider = Provider<DownloadManagerRepository>(
  (_) => GetIt.instance<DownloadManagerRepository>(),
);

/// Info hashes of the torrents this session is following.
///
/// [startDownloadProvider] appends to it, [stopDownloadProvider] removes from
/// it, and [allDownloadsProvider] turns it into live progress. Replaced
/// wholesale rather than mutated, because `StateProvider` compares by identity.
final activeDownloadHashesProvider =
    StateProvider<List<String>>((_) => const <String>[]);

/// Live progress for every hash in [activeDownloadHashesProvider], merged.
///
/// Each hash gets its own repository stream; this keeps the latest [Download]
/// per hash and emits the combined snapshot whenever any of them ticks. The
/// snapshot is ordered by [activeDownloadHashesProvider] so the list does not
/// reshuffle as updates arrive out of order, and hashes that have not reported
/// yet are simply absent rather than represented by a placeholder.
///
/// Changing the hash list tears the whole thing down and rebuilds it — that is
/// what `ref.watch` buys, and it is cheap because the per-hash streams are
/// polling loops, not sockets. Errors from any one stream are forwarded as a
/// stream error so the UI can surface them through `AsyncValue.error`; the
/// merged stream closes once every source has closed.
///
/// `autoDispose` because the download screen is transient and these streams
/// poll: dropping the last listener must stop the polling.
final allDownloadsProvider =
    StreamProvider.autoDispose<List<Download>>((ref) {
  final hashes = ref.watch(activeDownloadHashesProvider);
  if (hashes.isEmpty) return Stream.value(const <Download>[]);

  final repository = ref.watch(downloadRepositoryProvider);
  return _mergeDownloadStreams(repository, List<String>.unmodifiable(hashes));
});

/// Hands [DownloadRequest] to the download client and starts tracking it.
///
/// On success the returned hash is appended to
/// [activeDownloadHashesProvider], which is what makes the new torrent show up
/// in [allDownloadsProvider]. A hash already being tracked is not added twice.
///
/// This is an *action*: the result is cached under its [DownloadRequest] key
/// (which has value equality), so retrying the same request needs an explicit
/// invalidate:
///
/// ```dart
/// ref.invalidate(startDownloadProvider(request));
/// final hash = await ref.read(startDownloadProvider(request).future);
/// ```
///
/// Repository failures (`QBittorrentServiceException`) propagate untouched and
/// leave [activeDownloadHashesProvider] alone.
final startDownloadProvider =
    FutureProvider.family<String, DownloadRequest>((ref, request) async {
  final repository = ref.watch(downloadRepositoryProvider);

  final hash = await repository.startDownload(
    request.magnetUri,
    request.category,
    request.savePath,
  );

  final tracked = ref.read(activeDownloadHashesProvider);
  if (!tracked.contains(hash)) {
    ref.read(activeDownloadHashesProvider.notifier).state = <String>[
      ...tracked,
      hash,
    ];
  }

  return hash;
});

/// Stops the torrent behind [String] (an info hash) and stops tracking it.
///
/// The hash is dropped from [activeDownloadHashesProvider] only after the
/// repository call succeeds, so a failed stop leaves the download visible
/// rather than silently vanishing from the list.
///
/// Like [startDownloadProvider] this is a cached action — invalidate the family
/// entry to retry the same hash.
final stopDownloadProvider =
    FutureProvider.family<void, String>((ref, hash) async {
  final repository = ref.watch(downloadRepositoryProvider);
  await repository.stopDownload(hash);

  ref.read(activeDownloadHashesProvider.notifier).state = ref
      .read(activeDownloadHashesProvider)
      .where((tracked) => tracked != hash)
      .toList(growable: false);
});

// --- download discovery ----------------------------------------------------

/// How often [downloadDiscoveryProvider] asks the client what it is running.
///
/// Its own provider purely so tests can wind it down to milliseconds; nothing
/// in the app overrides it.
final downloadDiscoveryIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 5),
);

/// Polls the download client and adopts torrents this session did not start.
///
/// The request→download pipeline is asynchronous: Jellyseerr hands the request
/// to Radarr/Sonarr, which hands a release to qBittorrent some seconds later.
/// The info hash therefore does not exist at the moment the user submits, so
/// [startDownloadProvider] never sees it and [activeDownloadHashesProvider]
/// would stay empty. This closes that gap by listing the client every
/// [downloadDiscoveryIntervalProvider] and appending anything new to the
/// tracked hashes, which is what puts it on screen through
/// [allDownloadsProvider].
///
/// Each tick emits *only the hashes first seen on that tick*, so a listener can
/// react to arrivals rather than diffing the full list itself. The first tick
/// therefore reports everything the client is already running, which is the
/// wanted behaviour after an app restart.
///
/// "First seen" is remembered for the life of the provider, which also settles
/// what happens after [stopDownloadProvider]: the hash is gone from the tracked
/// list but still remembered here, so the next poll does not drag a torrent the
/// user just dismissed back onto the screen.
///
/// A failed poll is swallowed and retried on the next tick rather than killing
/// the stream: qBittorrent going away for a moment is normal, and the genuine
/// error the user needs to see is already surfaced by [allDownloadsProvider]
/// for the hashes being watched.
///
/// `autoDispose` because this is a timer: dropping the last listener must stop
/// the polling.
final downloadDiscoveryProvider =
    StreamProvider.autoDispose<List<String>>((ref) async* {
  final repository = ref.watch(downloadRepositoryProvider);
  final interval = ref.watch(downloadDiscoveryIntervalProvider);

  // `ref` is unusable once the provider is torn down, and an in-flight poll can
  // outlive it, so every resumption point below is gated on this.
  var disposed = false;

  // The gap between polls is a real [Timer] rather than `Future.delayed` so
  // that teardown can cancel it *synchronously*. A bare delay would keep the
  // loop's closure — and the repository behind it — alive for up to a full
  // interval after the last listener went away.
  Timer? pendingTick;
  Completer<void>? pendingWake;

  ref.onDispose(() {
    disposed = true;
    pendingTick?.cancel();
    pendingTick = null;
    final wake = pendingWake;
    if (wake != null && !wake.isCompleted) wake.complete();
  });

  /// Waits one [interval], or returns early if the provider is disposed.
  Future<void> waitForNextTick() {
    final wake = Completer<void>();
    pendingWake = wake;
    pendingTick = Timer(interval, () {
      pendingTick = null;
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future;
  }

  final seen = <String>{};
  var firstTick = true;

  while (!disposed) {
    // Poll immediately on the first pass — waiting a full interval before the
    // first listing would leave the screen blank for five seconds.
    if (!firstTick) await waitForNextTick();
    firstTick = false;
    if (disposed) return;

    final List<Download> listed;
    try {
      listed = await repository.listActiveDownloads();
    } catch (_) {
      continue;
    }
    if (disposed) return;

    final discovered = <String>[];
    for (final download in listed) {
      if (seen.add(download.hash)) discovered.add(download.hash);
    }

    if (discovered.isNotEmpty) {
      final tracked = ref.read(activeDownloadHashesProvider);
      final additions = discovered
          .where((hash) => !tracked.contains(hash))
          .toList(growable: false);
      if (additions.isNotEmpty) {
        ref.read(activeDownloadHashesProvider.notifier).state = <String>[
          ...tracked,
          ...additions,
        ];
      }
    }

    yield List<String>.unmodifiable(discovered);
  }
});

// --- Jellyfin refresh ------------------------------------------------------

/// The Jellyfin library-scan trigger, resolved from GetIt.
///
/// `registerDiscoveryServices()` must have run during app startup before this
/// is first read. Tests override it with
/// `jellyfinRefreshServiceProvider.overrideWithValue(fake)`.
final jellyfinRefreshServiceProvider = Provider<JellyfinRefreshService>(
  (_) => GetIt.instance<JellyfinRefreshService>(),
);

/// Tells Jellyfin to rescan whenever a tracked download reaches 100%.
///
/// Reads as state: the value is the set of info hashes whose completion has
/// already been reported to Jellyfin. That set *is* the deduplication — a hash
/// in it never triggers a second scan, however many further snapshots
/// [allDownloadsProvider] emits for it.
///
/// Nothing consumes the value except tests; the provider is watched for its
/// effect. Watch it wherever downloads are on screen (see
/// `DownloadStatusScreen`), and remember that `autoDispose` means completions
/// that land while no screen is watching are simply missed — the next scan
/// picks the files up anyway, so that is a delay rather than a loss.
final downloadWithRefreshProvider =
    NotifierProvider.autoDispose<DownloadRefreshNotifier, Set<String>>(
  DownloadRefreshNotifier.new,
);

/// Backs [downloadWithRefreshProvider]; see it for the contract.
class DownloadRefreshNotifier extends AutoDisposeNotifier<Set<String>> {
  bool _disposed = false;

  @override
  Set<String> build() {
    ref.onDispose(() => _disposed = true);

    // `fireImmediately` so a completion already present in the current snapshot
    // is not missed just because this provider started listening late.
    ref.listen<AsyncValue<List<Download>>>(
      allDownloadsProvider,
      (_, next) => _onSnapshot(next.valueOrNull),
      fireImmediately: true,
    );

    return const <String>{};
  }

  Future<void> _onSnapshot(List<Download>? downloads) async {
    if (_disposed || downloads == null || downloads.isEmpty) return;

    final alreadyRefreshed = state;
    final pending = <String>[
      for (final download in downloads)
        if (download.isCompleted && !alreadyRefreshed.contains(download.hash))
          download.hash,
    ];
    if (pending.isEmpty) return;

    // Marked *before* the first await. Progress snapshots arrive faster than
    // Jellyfin answers, so leaving the bookkeeping until afterwards would let
    // the next snapshot queue a second scan for the same torrent.
    state = <String>{...alreadyRefreshed, ...pending};

    for (var i = 0; i < pending.length; i++) {
      if (_disposed) return;
      await _refreshLibrary();
    }
  }

  /// One scan request, with every failure swallowed.
  ///
  /// A refresh is a hint, not part of the download: Jellyfin being down, the
  /// token being stale, or the service not being registered at all must not
  /// turn a finished download into an error on screen. Jellyfin's own periodic
  /// scan picks the files up regardless — this only makes it prompt.
  Future<void> _refreshLibrary() async {
    try {
      await ref.read(jellyfinRefreshServiceProvider).refreshLibrary();
    } catch (_) {
      // Intentionally ignored — see above.
    }
  }
}

/// Everything the download client needs to accept a new torrent.
///
/// Carries value equality because it is a `family` key: without it every
/// rebuilt request object would open a fresh, never-collected cache entry in
/// [startDownloadProvider].
class DownloadRequest {
  /// `magnet:?xt=urn:btih:...` link for the release.
  final String magnetUri;

  /// qBittorrent category, e.g. `radarr` or `sonarr`.
  final String category;

  /// Absolute path the client should write into.
  final String savePath;

  const DownloadRequest({
    required this.magnetUri,
    required this.category,
    required this.savePath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadRequest &&
          other.magnetUri == magnetUri &&
          other.category == category &&
          other.savePath == savePath;

  @override
  int get hashCode => Object.hash(magnetUri, category, savePath);

  @override
  String toString() =>
      'DownloadRequest(category: $category, savePath: $savePath)';
}

/// Merges the per-hash progress streams into one snapshot stream.
///
/// Written by hand rather than with `package:async`'s `StreamGroup` because
/// that package is only a transitive dependency here, and because a group
/// would emit bare [Download]s — the UI wants the whole list on every tick.
///
/// Subscriptions are opened on first listen and cancelled on the last, which
/// is what lets `autoDispose` on [allDownloadsProvider] actually stop the
/// repository's polling.
Stream<List<Download>> _mergeDownloadStreams(
  DownloadManagerRepository repository,
  List<String> hashes,
) {
  final latest = <String, Download>{};
  final subscriptions = <StreamSubscription<Download>>[];
  var openStreams = hashes.length;

  late final StreamController<List<Download>> controller;

  List<Download> snapshot() {
    final combined = <Download>[];
    for (final hash in hashes) {
      final download = latest[hash];
      if (download != null) combined.add(download);
    }
    return List<Download>.unmodifiable(combined);
  }

  void subscribe() {
    for (final hash in hashes) {
      subscriptions.add(
        repository.watchDownloadProgress(hash).listen(
          (download) {
            latest[hash] = download;
            if (!controller.isClosed) controller.add(snapshot());
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) controller.addError(error, stackTrace);
          },
          onDone: () {
            openStreams -= 1;
            if (openStreams <= 0 && !controller.isClosed) controller.close();
          },
        ),
      );
    }
  }

  Future<void> unsubscribe() async {
    final pending = List<StreamSubscription<Download>>.of(subscriptions);
    subscriptions.clear();
    for (final subscription in pending) {
      await subscription.cancel();
    }
  }

  controller = StreamController<List<Download>>(
    onListen: subscribe,
    onCancel: unsubscribe,
  );

  return controller.stream;
}
