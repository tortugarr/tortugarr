import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/services/media_segment_service.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:server_core/server_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves one list of raw media segments; everything else is unimplemented.
class FakeItemsApi implements ItemsApi {
  List<Map<String, dynamic>> segments = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getMediaSegments) {
      return Future<List<Map<String, dynamic>>>.value(segments);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeClient implements MediaServerClient {
  final FakeItemsApi items = FakeItemsApi();

  @override
  ItemsApi get itemsApi => items;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// A segment as the server sends it. [endTicks] overrides [endMs] for the
/// rare case that needs a sub-millisecond end.
Map<String, dynamic> segmentJson({
  required String id,
  required String type,
  required int startMs,
  int endMs = 0,
  int? endTicks,
}) {
  return {
    'Id': id,
    'ItemId': 'ep1',
    'Type': type,
    'StartTicks': startMs * 10000,
    'EndTicks': endTicks ?? endMs * 10000,
  };
}

Future<UserPreferences> testPrefs() async {
  SharedPreferences.setMockInitialValues(const {});
  final store = PreferenceStore();
  await store.init();
  return UserPreferences(store);
}

Future<MediaSegmentService> segmentServiceWith(
  UserPreferences prefs,
  List<Map<String, dynamic>> segments,
) async {
  final client = FakeClient();
  client.items.segments = segments;
  final service = MediaSegmentService(
    client,
    FeatureDetector(serverType: ServerType.jellyfin, serverVersion: ''),
    prefs,
  );
  await service.loadSegments('ep1');
  return service;
}
