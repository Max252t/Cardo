import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_tokens.dart';
import '../domain/token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String storageKey = 'cardo.refresh_credential';

  final FlutterSecureStorage _storage;

  @override
  Future<RefreshCredential?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final token = json['token'];
      final expires = DateTime.tryParse('${json['expires_at']}');
      if (token is! String || token.isEmpty || expires == null) {
        return null;
      }
      return RefreshCredential(token: token, expiresAt: expires.toUtc());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(RefreshCredential credential) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, String>{
        'token': credential.token,
        'expires_at': credential.expiresAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}
