abstract class CredentialStore {
  static const tokenKeyPrefix = 'server_token_';

  bool get secureStorageUnavailable;
  bool consumeSecureStorageUnavailable();

  Future<void> saveToken(String serverId, String token);
  Future<String?> getToken(String serverId);
  Future<void> deleteToken(String serverId);
  Future<void> clear();
}
