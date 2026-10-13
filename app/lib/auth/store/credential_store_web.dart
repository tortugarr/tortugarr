import 'package:shared_preferences/shared_preferences.dart';

import 'credential_store_base.dart';

class CredentialStoreImpl implements CredentialStore {
  @override
  bool get secureStorageUnavailable => false;

  @override
  bool consumeSecureStorageUnavailable() => false;

  String _key(String serverId) =>
      '${CredentialStore.tokenKeyPrefix}$serverId';

  @override
  Future<void> saveToken(String serverId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(serverId), token);
  }

  @override
  Future<String?> getToken(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(serverId));
  }

  @override
  Future<void> deleteToken(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(serverId));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((k) => k.startsWith(CredentialStore.tokenKeyPrefix))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

CredentialStore createCredentialStore() => CredentialStoreImpl();
