import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin/auth/models/user.dart';
import 'package:moonfin/auth/repositories/user_repository.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/download_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

PrivateUser _user({required bool canDownload}) => PrivateUser(
  id: 'u1',
  name: 'Test',
  serverId: 's1',
  accessToken: 'token',
  lastUsed: DateTime(2026),
  canDownload: canDownload,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserRepository users;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferenceStore();
    await store.init();
    users = UserRepository();
    GetIt.instance.registerSingleton<UserRepository>(users);
    GetIt.instance.registerSingleton<UserPreferences>(UserPreferences(store));
  });

  tearDown(() => GetIt.instance.reset());

  test('a user the server allows to download may download', () {
    users.setCurrentUser(_user(canDownload: true));
    expect(userCanDownload(), isTrue);
  });

  test('a user the server forbids may not, whatever the screen offers', () {
    users.setCurrentUser(_user(canDownload: false));
    expect(
      userCanDownload(),
      isFalse,
      reason: 'the track dialog offered downloads regardless of the policy',
    );
  });

  test('nobody signed in may not download', () {
    users.setCurrentUser(null);
    expect(userCanDownload(), isFalse);
  });
}
