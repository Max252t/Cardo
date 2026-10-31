import 'package:cardo/core/config/app_config.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/features/auth/data/auth_interceptor.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/boards/presentation/boards_providers.dart';
import 'package:cardo/shared/providers/app_config_provider.dart';
import 'package:cardo/shared/time/now_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/memory_token_store.dart';

Future<void> pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer build(
  FakeServer server,
  MemoryTokenStore store, {
  String url = 'http://api.test',
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig.parse(url)),
      dioAdapterProvider.overrideWithValue(server.adapter),
      tokenStoreProvider.overrideWithValue(store),
      nowProvider.overrideWithValue(() => server.now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the authorized client has the auth interceptor and never logs', () {
    final container = build(FakeServer(), MemoryTokenStore());

    final dio = container.read(dioProvider);

    expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(dio.options.baseUrl, 'http://api.test');
  });

  test('the raw client used for refresh has no auth interceptor', () {
    final container = build(FakeServer(), MemoryTokenStore());

    final raw = container.read(rawDioProvider);

    expect(raw.interceptors.whereType<AuthInterceptor>(), isEmpty);
    expect(raw.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(identical(raw, container.read(dioProvider)), isFalse);
  });

  test('an invalid config makes the clients refuse to exist', () {
    final container = build(FakeServer(), MemoryTokenStore(), url: '');

    expect(() => container.read(dioProvider), throwsA(anything));
  });

  test(
    'full stack: sign in, authorized call, refresh on expiry, sign out',
    () async {
      final server = FakeServer();
      final store = MemoryTokenStore();
      final container = build(server, store);
      container.listen(sessionProvider, (_, _) {});
      await pump();
      expect(container.read(sessionProvider), const SessionSignedOut());

      final result = await container
          .read(sessionProvider.notifier)
          .signIn(email: 'anna@example.com', password: 'secret-pass');
      expect(result.isSuccess, isTrue);
      expect(store.current?.token, 'refresh-1');

      final boards = await container.read(boardsApiProvider).listBoards();
      expect(boards.isSuccess, isTrue);
      expect(
        server.requests('GET ${ApiPaths.boards}').single.authorization,
        'Bearer access-1',
      );

      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(sessionProvider), const SessionSignedOut());
      expect(store.current, isNull);
      expect(server.count('POST ${ApiPaths.logout}'), 1);
    },
  );

  test(
    'a forced sign-out from an expired refresh reaches the session',
    () async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_reused'),
        );
      final store = MemoryTokenStore();
      final container = build(server, store);
      container.listen(sessionProvider, (_, _) {});
      await container
          .read(sessionProvider.notifier)
          .signIn(email: 'a@b.co', password: 'password1');
      server.on(
        'GET ${ApiPaths.boards}',
        FakeResponse.error(401, 'token_expired'),
      );

      final result = await container.read(boardsApiProvider).listBoards();

      expect(result.isSuccess, isFalse);
      await pump();
      expect(
        container.read(sessionProvider),
        const SessionSignedOut(reason: SignOutReason.reused),
      );
      expect(store.current, isNull);
    },
  );
}
