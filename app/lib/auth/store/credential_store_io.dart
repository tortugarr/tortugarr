import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credential_store_base.dart';

class CredentialStoreImpl implements CredentialStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _unavailable = false;

  @override
  bool get secureStorageUnavailable => _unavailable;

  @override
  bool consumeSecureStorageUnavailable() {
    final v = _unavailable;
    _unavailable = false;
    return v;
  }

  void _markUnavailable() => _unavailable = true;

  @override
  Future<void> saveToken(String serverId, String token) async {
    try {
      await _storage.write(
        key: '${CredentialStore.tokenKeyPrefix}$serverId',
        value: token,
      );
    } on PlatformException {
      _markUnavailable();
    }
  }

  @override
  Future<String?> getToken(String serverId) async {
    try {
      return await _storage.read(
        key: '${CredentialStore.tokenKeyPrefix}$serverId',
      );
    } on PlatformException {
      _markUnavailable();
      return null;
    }
  }

  @override
  Future<void> deleteToken(String serverId) async {
    try {
      await _storage.delete(
        key: '${CredentialStore.tokenKeyPrefix}$serverId',
      );
    } on PlatformException {
      _markUnavailable();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } on PlatformException {
      _markUnavailable();
    }
  }
}

CredentialStore createCredentialStore() => CredentialStoreImpl();
