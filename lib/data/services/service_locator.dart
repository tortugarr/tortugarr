import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../domain/repositories/download_manager_repository.dart';
import '../../domain/repositories/media_discovery_repository.dart';
import '../repositories/download_manager_repository_impl.dart';
import '../repositories/media_discovery_repository_impl.dart';
import 'jellyfin_refresh_service.dart';
import 'jellyseerr_service.dart';
import 'qbittorrent_enhanced_service.dart';

/// GetIt registrations for the discovery + download service stack.
///
/// These services talk to the *arr services directly rather than to the
/// Jellyfin/Emby media server, so they are registered here instead of in the
/// server-scoped modules under `lib/di/modules/`.
///
/// Call [registerDiscoveryServices] once during app startup, then await
/// [initializeDiscoveryServices] to load credentials out of secure storage.
final GetIt _getIt = GetIt.instance;

/// Registers every discovery service as a lazy singleton.
///
/// Safe to call more than once — existing registrations are left alone.
void registerDiscoveryServices() {
  if (!_getIt.isRegistered<JellyseerrService>()) {
    _getIt.registerLazySingleton<JellyseerrService>(
      // A dedicated Dio: JellyseerrService.initialize() sets baseUrl, timeouts
      // and the API-key header on it, which would otherwise leak onto every
      // other consumer of a shared client.
      () => JellyseerrService(Dio(), const FlutterSecureStorage()),
    );
  }

  if (!_getIt.isRegistered<QBittorrentEnhancedService>()) {
    _getIt.registerLazySingleton<QBittorrentEnhancedService>(
      // Its own Dio again: initialize() pins the qBittorrent session cookie
      // onto the client's default headers, which must not leak onto Jellyseerr
      // or the media-server clients.
      () => QBittorrentEnhancedService(Dio(), const FlutterSecureStorage()),
      // The service owns polling timers and open progress streams; GetIt runs
      // this on unregister so resetDiscoveryServices can stay synchronous.
      dispose: (service) => service.dispose(),
    );
  }

  if (!_getIt.isRegistered<JellyfinRefreshService>()) {
    _getIt.registerLazySingleton<JellyfinRefreshService>(
      // Its own Dio once more: initialize() pins the Jellyfin base URL and
      // timeouts onto the client, which must not follow requests aimed at
      // Jellyseerr or qBittorrent.
      () => JellyfinRefreshService(Dio(), const FlutterSecureStorage()),
    );
  }

  // Repositories are registered against their domain interfaces, so state and
  // UI resolve the abstraction and never the concrete implementation. They
  // are lazy like the services below them: resolving one here would build the
  // service eagerly and defeat the lazy registration above.
  if (!_getIt.isRegistered<MediaDiscoveryRepository>()) {
    _getIt.registerLazySingleton<MediaDiscoveryRepository>(
      () => MediaDiscoveryRepositoryImpl(
        jellyseerr: _getIt<JellyseerrService>(),
      ),
    );
  }

  if (!_getIt.isRegistered<DownloadManagerRepository>()) {
    _getIt.registerLazySingleton<DownloadManagerRepository>(
      () => DownloadManagerRepositoryImpl(
        qbittorrent: _getIt<QBittorrentEnhancedService>(),
      ),
    );
  }
}

/// Resolves and initializes the discovery services.
///
/// Separate from [registerDiscoveryServices] because initialization is async
/// (it reads secure storage) while GetIt registration is not.
Future<void> initializeDiscoveryServices({
  String jellyseerrBaseUrl = JellyseerrService.defaultBaseUrl,
  String qbittorrentBaseUrl = QBittorrentEnhancedService.defaultBaseUrl,
  String jellyfinBaseUrl = JellyfinRefreshService.defaultBaseUrl,
}) async {
  registerDiscoveryServices();
  await _getIt<JellyseerrService>().initialize(jellyseerrBaseUrl);

  // Like Jellyseerr, this only reads secure storage and configures Dio — no
  // network call — so a failure here would be a genuine local fault.
  await _getIt<JellyfinRefreshService>().initialize(jellyfinBaseUrl);

  // Unlike Jellyseerr, qBittorrent authenticates over the network during
  // initialize(). A downloader that is offline or holding stale credentials
  // must not take app startup with it, so the failure is swallowed here: the
  // service stays registered but unauthenticated, and the first addTorrent or
  // listTorrents call surfaces the real error to the caller that needs it.
  try {
    await _getIt<QBittorrentEnhancedService>().initialize(qbittorrentBaseUrl);
  } on QBittorrentServiceException {
    // Intentionally ignored — see above.
  }
}

/// Drops the discovery registrations, e.g. when switching users.
void resetDiscoveryServices() {
  // Repositories first: they hold references to the services below, so
  // dropping them in this order never leaves a live repository pointing at an
  // unregistered (and, for qBittorrent, already disposed) service.
  if (_getIt.isRegistered<MediaDiscoveryRepository>()) {
    _getIt.unregister<MediaDiscoveryRepository>();
  }
  if (_getIt.isRegistered<DownloadManagerRepository>()) {
    _getIt.unregister<DownloadManagerRepository>();
  }

  if (_getIt.isRegistered<JellyseerrService>()) {
    _getIt.unregister<JellyseerrService>();
  }
  if (_getIt.isRegistered<QBittorrentEnhancedService>()) {
    // Runs the dispose callback above, cancelling any live polling timers.
    _getIt.unregister<QBittorrentEnhancedService>();
  }
  if (_getIt.isRegistered<JellyfinRefreshService>()) {
    // No timers or streams to tear down — it holds only a token and a Dio.
    _getIt.unregister<JellyfinRefreshService>();
  }
}
