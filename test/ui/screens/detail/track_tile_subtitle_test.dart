import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

AggregatedItem _track({
  required String name,
  String? artist,
  int? year,
  int? runtimeSeconds,
}) => AggregatedItem(
  id: 'track-1',
  serverId: 'server-1',
  rawData: {
    'Id': 'track-1',
    'Name': name,
    'Type': 'Audio',
    'MediaType': 'Audio',
    'IndexNumber': 1,
    if (artist != null) 'Artists': [artist],
    if (year != null) 'ProductionYear': year,
    if (runtimeSeconds != null) 'RunTimeTicks': runtimeSeconds * 10000000,
  },
);

Future<void> _pump(
  WidgetTester tester,
  AggregatedItem track, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TrackTile(
          track: track,
          index: 1,
          currentIndex: 0,
          totalCount: 1,
          reorderable: false,
          reorderIndex: 0,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('the runtime sits on the artist line', (tester) async {
    await _pump(
      tester,
      _track(
        name: 'Just The Way You Are',
        artist: 'Billy Joel',
        runtimeSeconds: 290,
      ),
    );

    expect(find.text('Billy Joel • 4:50'), findsOneWidget);
  });

  testWidgets('the year never reaches the row', (tester) async {
    await _pump(
      tester,
      _track(
        name: 'My Life',
        artist: 'Billy Joel',
        year: 2003,
        runtimeSeconds: 283,
      ),
    );

    expect(
      find.textContaining('2003'),
      findsNothing,
      reason: 'every track on an album repeats the same year',
    );
  });

  testWidgets('a track with no artist still shows its runtime', (tester) async {
    await _pump(tester, _track(name: 'Untitled', runtimeSeconds: 125));

    expect(find.text('2:05'), findsOneWidget);
  });

  testWidgets('the row plays without a separate play button', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      _track(name: 'My Life', artist: 'Billy Joel'),
      onTap: () => taps++,
    );

    expect(find.byIcon(Icons.play_arrow), findsNothing);
    await tester.tap(find.text('My Life'));
    expect(taps, 1);
  });
}
