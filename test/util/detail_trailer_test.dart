import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/detail_trailer.dart';
import 'package:shared_preferences/shared_preferences.dart';

AggregatedItem _item({
  String type = 'Movie',
  int? localTrailerCount,
  List<Map<String, dynamic>>? remoteTrailers,
  String? extraType,
}) {
  return AggregatedItem(
    id: 'id',
    serverId: 'server',
    rawData: <String, dynamic>{
      'Type': type,
      'LocalTrailerCount': ?localTrailerCount,
      'RemoteTrailers': ?remoteTrailers,
      'ExtraType': ?extraType,
    },
  );
}

void main() {
  group('localTrailerCount', () {
    test('reads the count the server sent', () {
      expect(_item(localTrailerCount: 2).localTrailerCount, 2);
    });

    test('an item with no count answers zero rather than throwing', () {
      expect(_item().localTrailerCount, 0);
    });

    test('a count sent as a string still parses', () {
      final item = AggregatedItem(
        id: 'id',
        serverId: 'server',
        rawData: const {'LocalTrailerCount': '3'},
      );
      expect(item.localTrailerCount, 3);
    });
  });

  group('hasTrailer', () {
    // The bug: a movie with a trailer on disk. The server counts it but keeps
    // it out of special features, so checking that list alone found nothing.
    test('a movie with only a local trailer has one', () {
      expect(hasTrailer(_item(localTrailerCount: 1), const []), isTrue);
    });

    test('a movie with only a remote trailer has one', () {
      expect(
        hasTrailer(
          _item(
            remoteTrailers: [
              {'Url': 'https://example.test/t', 'Name': 'Trailer'},
            ],
          ),
          const [],
        ),
        isTrue,
      );
    });

    test('a movie with neither has none', () {
      expect(hasTrailer(_item(localTrailerCount: 0), const []), isFalse);
      expect(hasTrailer(_item(), const []), isFalse);
    });

    test('a trailer filed as an ordinary extra still counts', () {
      final features = [_item(type: 'Video', extraType: 'Trailer')];
      expect(hasTrailer(_item(), features), isTrue);
    });

    test('other kinds of extra are not trailers', () {
      final features = [
        _item(type: 'Video', extraType: 'BehindTheScenes'),
        _item(type: 'Video', extraType: 'DeletedScene'),
        _item(type: 'Video', extraType: 'Featurette'),
      ];
      expect(hasTrailer(_item(), features), isFalse);
    });

    test('a series is judged the same way a movie is', () {
      expect(
        hasTrailer(_item(type: 'Series', localTrailerCount: 1), const []),
        isTrue,
      );
      expect(hasTrailer(_item(type: 'Series'), const []), isFalse);
    });

    test('a season carries its own count', () {
      expect(
        hasTrailer(_item(type: 'Season', localTrailerCount: 1), const []),
        isTrue,
      );
    });
  });

  group('isTrailerFeature', () {
    test('matches on the extra type', () {
      expect(
        isTrailerFeature(_item(type: 'Video', extraType: 'Trailer')),
        isTrue,
      );
    });

    test('matches a standalone trailer on its item type', () {
      expect(isTrailerFeature(_item(type: 'Trailer')), isTrue);
    });

    test('does not match another extra', () {
      expect(
        isTrailerFeature(_item(type: 'Video', extraType: 'Interview')),
        isFalse,
      );
    });
  });

  group('external trailers', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late UserPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferenceStore();
      await store.init();
      prefs = UserPreferences(store);
      GetIt.instance.registerSingleton<UserPreferences>(prefs);
    });

    tearDown(() => GetIt.instance.reset());

    test('trailers stay in-app unless the user opts out', () {
      expect(opensTrailersExternally(), isFalse);
    });

    test('the toggle hands trailers to the system', () async {
      await prefs.set(UserPreferences.detailTrailersExternal, true);
      expect(opensTrailersExternally(), isTrue);
    });

    test(
      'a launch nothing can handle reports false instead of throwing',
      () async {
        // No url_launcher platform exists in a test, so the call fails the way
        // it does on a device with no handler, and the caller falls back
        // in-app.
        expect(
          await launchTrailerExternally('https://youtube.com/watch?v=x'),
          isFalse,
        );
      },
    );

    test('a launch the system accepts reports true', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => true,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );

      expect(
        await launchTrailerExternally('https://youtube.com/watch?v=x'),
        isTrue,
      );
    });
  });
}
