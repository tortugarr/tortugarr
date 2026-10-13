import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferenceStore> _store([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final store = PreferenceStore();
  await store.init();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const signedIn = {
    'pref_last_server_id': 'server1',
    'pref_last_user_id': 'user1',
  };
  const scopedKey = 'mediaBarCollectionIds_server1_user1';

  group('media bar sources', () {
    test('a saved selection lands where the media bar reads it', () async {
      final store = await _store(signedIn);
      final prefs = UserPreferences(store);

      await prefs.set(UserPreferences.mediaBarCollectionIds, 'c1,c2');

      expect(store.getString(scopedKey), 'c1,c2');
      expect(prefs.get(UserPreferences.mediaBarCollectionIds), 'c1,c2');
    });

    test('a selection written to the bare key is dropped on the next run',
        () async {
      // What a write straight to the store leaves behind, alongside the
      // scoped key the server profile fills in.
      final store = await _store({
        ...signedIn,
        'mediaBarCollectionIds': 'c1,c2',
        scopedKey: '',
      });

      final prefs = UserPreferences(store);

      expect(prefs.get(UserPreferences.mediaBarCollectionIds), '');
      expect(store.containsKey('mediaBarCollectionIds'), isFalse);
    });

    test('a saved selection survives a restart', () async {
      final store = await _store(signedIn);
      await UserPreferences(store).set(
        UserPreferences.mediaBarCollectionIds,
        'c1,c2',
      );

      final reopened = UserPreferences(store);

      expect(reopened.get(UserPreferences.mediaBarCollectionIds), 'c1,c2');
    });
  });
}
