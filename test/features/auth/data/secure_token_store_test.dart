import 'dart:convert';

import 'package:cardo/features/auth/data/secure_token_store.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('read returns null when nothing is stored', () async {
    expect(await SecureTokenStore(storage).read(), isNull);
  });

  test('write then read round-trips in UTC', () async {
    final store = SecureTokenStore(storage);
    final credential = RefreshCredential(
      token: 'refresh-token',
      expiresAt: DateTime.utc(2026, 4, 1, 8, 30),
    );

    await store.write(credential);
    final restored = await store.read();

    expect(restored, credential);
    expect(restored?.expiresAt.isUtc, isTrue);
  });

  test('write converts a local timestamp to UTC', () async {
    final store = SecureTokenStore(storage);
    final local = DateTime.utc(2026, 4, 1, 8, 30).toLocal();

    await store.write(RefreshCredential(token: 't', expiresAt: local));

    expect((await store.read())?.expiresAt, DateTime.utc(2026, 4, 1, 8, 30));
  });

  test('only the refresh credential is persisted', () async {
    final store = SecureTokenStore(storage);

    await store.write(RefreshCredential(token: 'r-1', expiresAt: t0));
    final raw = await storage.read(key: SecureTokenStore.storageKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;

    expect(json.keys.toSet(), <String>{'token', 'expires_at'});
    expect(json['token'], 'r-1');
  });

  test('clear removes the credential', () async {
    final store = SecureTokenStore(storage);
    await store.write(RefreshCredential(token: 't', expiresAt: t0));

    await store.clear();

    expect(await store.read(), isNull);
    expect(await storage.read(key: SecureTokenStore.storageKey), isNull);
  });

  test('clear without a stored value is harmless', () async {
    await SecureTokenStore(storage).clear();
  });

  group('corrupted payloads are treated as no credential', () {
    final payloads = <String, String>{
      'not json': '{{{',
      'json array': '[1,2]',
      'json string': '"x"',
      'empty object': '{}',
      'missing expiry': '{"token":"t"}',
      'missing token': '{"expires_at":"2026-04-01T08:30:00Z"}',
      'empty token': '{"token":"","expires_at":"2026-04-01T08:30:00Z"}',
      'numeric token': '{"token":5,"expires_at":"2026-04-01T08:30:00Z"}',
      'bad expiry': '{"token":"t","expires_at":"soon"}',
      'null expiry': '{"token":"t","expires_at":null}',
    };
    for (final entry in payloads.entries) {
      test(entry.key, () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureTokenStore.storageKey: entry.value,
        });

        expect(await SecureTokenStore(storage).read(), isNull);
      });
    }
  });
}
