import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/database/offline_database.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/offline_repository.dart';
import 'package:moonfin/data/services/download_notification_service.dart';
import 'package:moonfin/data/services/download_service.dart';
import 'package:moonfin/data/services/storage_path_service.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No-op repository so the test doesn't need the sqlite3 native library.
/// The database is never opened because every method DownloadService uses
/// is overridden.
class _FakeOfflineRepository extends OfflineRepository {
  _FakeOfflineRepository(super.db);

  @override
  Future<void> upsertItem(DownloadedItemsCompanion item) async {}

  @override
  Future<void> updateDownloadStatus(
    String itemId,
    int status, {
    double? progress,
    String? error,
  }) async {}

  @override
  Future<void> setLocalFilePath(
    String itemId,
    String path, {
    int? fileSize,
  }) async {}

  @override
  Future<int> getTotalStorageUsed() async => 0;

  @override
  Future<List<DownloadedItem>> getItems({
    String? type,
    bool onlyCompleted = false,
  }) async => const [];

  @override
  Future<DownloadedItem?> getItem(String itemId) async => null;

  @override
  Future<void> deleteItem(String itemId) async {}
}

class _FakeStoragePathService extends StoragePathService {
  final Directory dir;
  _FakeStoragePathService(this.dir);

  @override
  Future<Directory> getOfflineRoot() async => dir;

  @override
  Future<Directory> getImageCacheDir() async {
    final imageDir = Directory('${dir.path}/images');
    if (!await imageDir.exists()) await imageDir.create(recursive: true);
    return imageDir;
  }
}

class _FakeItemsApi implements ItemsApi {
  final Map<String, dynamic> itemData;
  _FakeItemsApi(this.itemData);

  @override
  Future<Map<String, dynamic>> getItem(
    String itemId, {
    String? mediaSourceId,
    String? fields,
  }) async => itemData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClient implements MediaServerClient {
  _FakeClient(this._itemsApi);

  final _FakeItemsApi _itemsApi;

  @override
  ItemsApi get itemsApi => _itemsApi;

  @override
  String? get accessToken => 'test-token';

  // An unroutable local port: every download attempt fails immediately with a
  // connection error (no HTTP status), which exercises the plain error path.
  @override
  String get baseUrl => 'http://127.0.0.1:1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late OfflineDatabase db;
  late Directory tempDir;
  late DownloadService service;

  const itemId = 'movie-1';
  final itemData = <String, dynamic>{
    'Id': itemId,
    'Type': 'Movie',
    'Name': 'Test Movie',
    'MediaSources': [
      {'Id': 'source-1', 'Container': 'mkv', 'Size': 1024},
    ],
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);

    tempDir = await Directory.systemTemp.createTemp('moonfin_retry_test');
    db = OfflineDatabase(DatabaseConnection(NativeDatabase.memory()));
    final repo = _FakeOfflineRepository(db);

    final getIt = GetIt.instance;
    getIt.registerSingleton<UserPreferences>(prefs);
    getIt.registerSingleton<StoragePathService>(
      _FakeStoragePathService(tempDir),
    );
    getIt.registerSingleton<OfflineRepository>(repo);

    service = DownloadService(
      _FakeClient(_FakeItemsApi(itemData)),
      DownloadNotificationService(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('a failed download can be retried without an app restart', () async {
    final item = AggregatedItem(
      id: itemId,
      serverId: 'http://127.0.0.1:1',
      rawData: itemData,
    );

    final errors = <String>[];
    final sub = service.errors.listen(errors.add);

    await service.downloadItem(item);
    await pumpEventQueue();

    expect(
      service.activeDownloads[itemId]?.error,
      isNotNull,
      reason: 'first attempt should fail with a connection error',
    );
    expect(errors, hasLength(1));
    expect(
      service.isDownloading(itemId),
      isTrue,
      reason: 'the error entry is retained for the Retry UI',
    );

    // The regression: this second call used to no-op because the stale error
    // entry made the in-flight guard treat the item as still downloading.
    await service.downloadItem(item);
    await pumpEventQueue();

    expect(
      errors,
      hasLength(2),
      reason: 'retry must run (and fail again), not silently no-op',
    );
    expect(service.activeDownloads[itemId]?.error, isNotNull);

    await sub.cancel();
  });
}
