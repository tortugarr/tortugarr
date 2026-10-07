import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Navbar colour and opacity are stored per server and user. A migration used to seed them
// from the media bar overlay settings, and because a scoped value is missing for every
// server the app hasn't seen yet, it re-ran on each new one. That stamped the media bar's
// look onto an already styled navbar and pushed the result to the plugin, which handed it
// to every other client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverKey = 'pref_last_server_id';
  const userKey = 'pref_last_user_id';

  Future<PreferenceStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final store = PreferenceStore();
    await store.init();
    return store;
  }

  group('navbar keeps its own values', () {
    test('a new server scope does not inherit the media bar look', () async {
      final store = await storeWith(<String, Object>{
        serverKey: 'srv1',
        userKey: 'usr1',
        // A media bar look was chosen on this server, the navbar was never touched.
        'mediaBarOverlayColor_srv1_usr1': 'red',
        'mediaBarOverlayOpacity_srv1_usr1': 10,
      });

      UserPreferences(store);

      expect(store.containsKey('navbarColor_srv1_usr1'), isFalse,
          reason: 'navbar colour was overwritten with the media bar colour');
      expect(store.containsKey('navbarOpacity_srv1_usr1'), isFalse,
          reason: 'navbar opacity was overwritten with the media bar opacity');
    });

    test('an already styled navbar survives construction', () async {
      final store = await storeWith(<String, Object>{
        serverKey: 'srv2',
        userKey: 'usr2',
        'mediaBarOverlayColor_srv2_usr2': 'blue',
        'mediaBarOverlayOpacity_srv2_usr2': 10,
        'navbarColor_srv2_usr2': 'gray',
        'navbarOpacity_srv2_usr2': 90,
      });

      UserPreferences(store);

      expect(store.getString('navbarColor_srv2_usr2'), 'gray');
      expect(store.getInt('navbarOpacity_srv2_usr2'), 90);
    });

    test('bare overlay keys are left where they are', () async {
      final store = await storeWith(<String, Object>{
        'mediaBarOverlayColor': 'red',
        'mediaBarOverlayOpacity': 10,
      });

      UserPreferences(store);

      expect(store.containsKey('navbarColor'), isFalse);
      expect(store.containsKey('navbarOpacity'), isFalse);
    });
  });

  group('clock format seeding', () {
    // The seed wrote the bare key while reads go through the scoped one, so it landed
    // somewhere nothing looks at and the system format was never picked up.
    test('writes the scoped key when a server and user are active', () async {
      final store = await storeWith(<String, Object>{
        serverKey: 'srv3',
        userKey: 'usr3',
      });

      UserPreferences(store);

      // Only assert when the test platform actually reports a 24 hour locale, otherwise
      // there is nothing to seed.
      final binding = TestWidgetsFlutterBinding.instance;
      if (binding.platformDispatcher.alwaysUse24HourFormat) {
        expect(store.containsKey('pref_use_24_hour_clock_srv3_usr3'), isTrue,
            reason: 'the seed wrote a key that reads never consult');
      }
    });
  });

  mediaBarContentTypeTests();
}

// Media bar item types and media bar source shared a wire key with the other clients, whose
// source values are "library" and "collection". Those words arrived here as item types and
// stuck, leaving the Content Type picker showing a value it never offered.
void mediaBarContentTypeTests() {
  group('media bar content type', () {
    test('a source value stored for a server is put back to a real one', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_last_server_id': 'srv1',
        'pref_last_user_id': 'usr1',
        'mediaBarContentType_srv1_usr1': 'library',
      });
      final store = PreferenceStore();
      await store.init();

      UserPreferences(store);

      expect(store.getString('mediaBarContentType_srv1_usr1'), 'both');
    });

    test('a real selection is left alone', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_last_server_id': 'srv1',
        'pref_last_user_id': 'usr1',
        'mediaBarContentType_srv1_usr1': 'movies',
      });
      final store = PreferenceStore();
      await store.init();

      UserPreferences(store);

      expect(store.getString('mediaBarContentType_srv1_usr1'), 'movies');
    });

    test('normalising keeps known values and rejects the rest', () {
      expect(UserPreferences.normalizeMediaBarContentType('movies'), 'movies');
      expect(UserPreferences.normalizeMediaBarContentType('tvshows'), 'tvshows');
      expect(UserPreferences.normalizeMediaBarContentType('both'), 'both');
      expect(UserPreferences.normalizeMediaBarContentType('library'), 'both');
      expect(UserPreferences.normalizeMediaBarContentType('collection'), 'both');
      expect(UserPreferences.normalizeMediaBarContentType(null), 'both');
    });
  });
}
