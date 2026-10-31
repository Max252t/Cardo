import 'auth_tokens.dart';

abstract interface class TokenStore {
  Future<RefreshCredential?> read();

  Future<void> write(RefreshCredential credential);

  Future<void> clear();
}
