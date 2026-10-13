import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/database/offline_database.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/offline_repository.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the completed-download early return in the Android TV
/// Dolby Vision transcode gate: a finished local copy must play as-is instead
/// of being swapped for a server transcode, which used to stream from the
/// server even in offline playback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineDatabase db;
  late OfflineRepository repo;
  late UserPreferences prefs;

  const serverId = 'http://server';
  const itemId = 'episode-dv';

  // A 4K Dolby Vision episode as the server reports it: the original media
  // source carries a DOVI video stream, regardless of what was downloaded.
  AggregatedItem dvItem() => AggregatedItem(
    id: itemId,
    serverId: serverId,
    rawData: {
      'Id': itemId,
      'Type': 'Episode',
      'Name': 'DV Episode',
      'MediaSources': [
        {
          'Id': 'source-1',
          'MediaStreams': [
            {'Type': 'Video', 'Codec': 'hevc', 'VideoRangeType': 'DOVI'},
          ],
        },
      ],
    },
  );

  Future<void> seedDownloadRow({
    required int status,
    String? localFilePath,
  }) async {
    await repo.upsertItem(
      DownloadedItemsCompanion(
        itemId: const Value(itemId),
        serverId: const Value(serverId),
        type: const Value('Episode'),
        name: const Value('DV Episode'),
        localFilePath: Value(localFilePath),
        metadataJson: Value(jsonEncode(dvItem().rawData)),
        downloadStatus: Value(status),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    final store = PreferenceStore();
    await store.init();
    prefs = UserPreferences(store);

    db = OfflineDatabase(DatabaseConnection(NativeDatabase.memory()));
    repo = OfflineRepository(db);

    final getIt = GetIt.instance;
    getIt.registerSingleton<UserPreferences>(prefs);
    getIt.registerSingleton<OfflineRepository>(repo);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await db.close();
    PlatformDetection.setDisplayHdrTypes(null);
    PlatformDetection.setTvMode(false);
    PlatformDetection.setInterfaceLayout(InterfaceLayout.automatic);
  });

  // The TV the bug was seen on: Android, TV mode, display reports no HDR at
  // all, so the gate's HDR checks would otherwise force a transcode.
  void setUpNoHdrAndroidTv() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PlatformDetection.setTvMode(true);
    PlatformDetection.setDisplayHdrTypes(null);
  }

  Future<BuildContext> mountContext(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    return tester.element(find.byType(Scaffold));
  }

  testWidgets(
    'a completed download keeps the Dolby Vision gate open for direct play',
    (tester) async {
      setUpNoHdrAndroidTv();
      await seedDownloadRow(status: 2, localFilePath: '/tv/downloads/ep.mkv');

      final context = await mountContext(tester);
      final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
        context,
        [dvItem()],
      );

      expect(forceTranscode, isFalse);

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'the same episode without a download still forces the transcode',
    (tester) async {
      setUpNoHdrAndroidTv();

      final context = await mountContext(tester);
      final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
        context,
        [dvItem()],
      );

      expect(
        forceTranscode,
        isTrue,
        reason: 'no local copy, so the no-HDR display needs the transcode',
      );

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a partial download without a file does not keep the gate open',
    (tester) async {
      setUpNoHdrAndroidTv();
      await seedDownloadRow(status: 1);

      final context = await mountContext(tester);
      final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
        context,
        [dvItem()],
      );

      expect(forceTranscode, isTrue);

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a non-TV platform never forces the transcode', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    PlatformDetection.setTvMode(false);
    PlatformDetection.setDisplayHdrTypes(null);

    final context = await mountContext(tester);
    final forceTranscode = await shouldForceTranscodeForDolbyVisionQueue(
      context,
      [dvItem()],
    );

    expect(forceTranscode, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });
}
