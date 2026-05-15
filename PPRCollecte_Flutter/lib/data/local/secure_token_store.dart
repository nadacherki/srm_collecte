import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage securise des tokens JWT (Android Keystore / iOS Keychain).
///
/// Ne JAMAIS stocker les tokens en SharedPreferences ni en clair en
/// SQLite : ils donnent acces complet a l'API au nom de l'agent.
class SecureTokenStore {
  SecureTokenStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _kAccess = 'srm_jwt_access';
  static const _kRefresh = 'srm_jwt_refresh';

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  static Future<void> saveAccess(String access) async {
    await _storage.write(key: _kAccess, value: access);
  }

  static Future<String?> readAccess() => _storage.read(key: _kAccess);

  static Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  static Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
