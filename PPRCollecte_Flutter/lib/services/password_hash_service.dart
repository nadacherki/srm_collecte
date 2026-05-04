import 'package:dargon2_flutter/dargon2_flutter.dart';

class PasswordHashService {
  static Future<String> hashPassword(String password) async {
    final result = await argon2.hashPasswordString(
      password,
      salt: Salt.newSalt(),
      iterations: 3,
      memory: 65536,
      parallelism: 2,
      length: 32,
      type: Argon2Type.id,
    );
    return result.encodedString;
  }

  static Future<bool> verifyPassword(
    String password,
    String encodedHash,
  ) async {
    if (encodedHash.isEmpty) return false;
    return argon2.verifyHashString(
      password,
      encodedHash,
      type: Argon2Type.id,
    );
  }

  static bool looksLikePasswordHash(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith(r'$argon2') || normalized.startsWith('argon2');
  }
}
