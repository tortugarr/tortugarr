import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/database/offline_database.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/repositories/offline_repository.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';
import 'package:moonfin/util/platform_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Android TV Dolby Vision gate on a device that renders HDR10 but not
/// Dolby Vision, with the fallback pinned to transcode. What each layout
/// needs is pinned in hdr_stream_capability_test, this is the gate honouring
/// it ahead of the pinned preference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineDatabase db;

  AggregatedItem itemWith({required String videoRangeType}) => AggregatedItem(
    id: 'movie',
    serverId: 'http://server',
    rawData: {
      'Id': 'movie',
      'Type': 'Movie',
      'MediaSources': [
        {
          'Id': 'source-1',
          'MediaStreams': [
            {
              'Type': 'Video',
              'Codec': 'hevc',
              'VideoRangeType': videoRangeType,
            },
          ],
        },
      ],
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);
    await prefs.set(
      UserPreferences.dolbyVisionFallbackBehavior,
      DolbyVisionFallbackBehavior.transcode,
    );

    db = OfflineDatabase(DatabaseConnection(NativeDatabase.memory()));
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
    GetIt.instance.registerSingleton<OfflineRepository>(OfflineRepository(db));

    PlatformDetection.setTvMode(true);
    PlatformDetection.setDisplayHdrTypes(const ['HDR10']);
    PlatformDetection.setMediaCodecCapabilities(const {
      'supportsHevcHdr10': true,
    });
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await db.close();
    PlatformDetection.setTvMode(false);
    PlatformDetection.setDisplayHdrTypes(null);
    PlatformDetection.setMediaCodecCapabilities(null);
  });

  // The platform override is checked by the test binding before tearDown
  // runs, so it has to go back inside the test body.
  Future<bool> gate(WidgetTester tester, AggregatedItem item) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final context = tester.element(find.byType(Scaffold));
      return await shouldForceTranscodeForDolbyVisionQueue(context, [item]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('a profile 8.1 stream direct plays on an HDR10 device', (
    tester,
  ) async {
    expect(
      await gate(tester, itemWith(videoRangeType: 'DOVIWithHDR10')),
      isFalse,
      reason: 'the base layer is HDR10, there is nothing to fall back from',
    );
  });

  testWidgets('a profile 5 stream still takes the pinned fallback', (
    tester,
  ) async {
    expect(await gate(tester, itemWith(videoRangeType: 'DOVI')), isTrue);
  });
}
