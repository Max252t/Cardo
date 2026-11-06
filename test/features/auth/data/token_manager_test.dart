import 'dart:async';

import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/features/auth/data/token_manager.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../helpers/auth_harness.dart';
import '../helpers/fake_auth_api.dart';

void main() {
  group('refresh outcomes', () {
    test('without memory and store there is no credential', () async {
      final h = AuthHarness();

      expect(await h.manager.refresh(), isA<NoCredential>());
      expect(h.adapter.requests, isEmpty);
    });

    test('a stored credential is used when memory is empty', () async {
      final h = AuthHarness();
      h.store.current = RefreshCredential(
        token: 'stored-refresh',
        expiresAt: h.clock.add(const Duration(days: 1)),
      );

      final outcome = await h.manager.refresh();

      expect(outcome, isA<Refreshed>());
      expect(h.adapter.to(ApiPaths.refresh).single.body, <String, Object?>{
        'refresh_token': 'stored-refresh',
      });
      expect(h.store.current?.token, 'refresh-1');
      expect(await h.manager.accessToken(), 'access-1');
    });

    test(
      'a locally expired stored credential is still sent to the server',
      () async {
        final h = AuthHarness();
        h.store.current = RefreshCredential(
          token: 'stored-refresh',
          expiresAt: h.clock.subtract(const Duration(seconds: 1)),
        );

        final outcome = await h.manager.refresh();

        expect(outcome, isA<Refreshed>());
        expect(h.adapter.count(ApiPaths.refresh), 1);
        expect(h.endings, isEmpty);
      },
    );

    test('an unreadable store is treated as no credential', () async {
      final h = AuthHarness();
      h.store.failOnRead = true;

      expect(await h.manager.refresh(), isA<NoCredential>());
    });

    test('a stale access token short-circuits to the current pair', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(access: 'new'));

      final outcome = await h.manager.refresh(staleAccess: 'old');

      expect(outcome, isA<Refreshed>());
      expect((outcome as Refreshed).tokens.access, 'new');
      expect(h.adapter.requests, isEmpty);
    });

    test('a matching stale access token does refresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(access: 'old'));

      await h.manager.refresh(staleAccess: 'old');

      expect(h.adapter.count(ApiPaths.refresh), 1);
    });

    test('concurrent refresh calls share one request', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.refreshGate = Completer<void>();

      final first = h.manager.refresh();
      final second = h.manager.refresh();
      await h.settle();
      h.refreshGate!.complete();

      expect(await first, same(await second));
      expect(h.adapter.count(ApiPaths.refresh), 1);
    });

    test('a finished refresh does not block the next one', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());

      await h.manager.refresh();
      await h.manager.refresh();

      expect(h.adapter.count(ApiPaths.refresh), 2);
      expect(h.adapter.to(ApiPaths.refresh).last.body, <String, Object?>{
        'refresh_token': 'refresh-1',
      });
    });
  });

  group('persistence order', () {
    test(
      'the rotated credential is stored before the outcome is returned',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        final gate = Completer<void>();
        h.store.writeGate = gate.future;
        var done = false;

        final pending = h.manager.refresh().then((outcome) {
          done = true;
          return outcome;
        });
        await h.settle();

        expect(h.adapter.count(ApiPaths.refresh), 1);
        expect(done, isFalse);
        expect(h.store.current?.token, 'refresh-0');

        gate.complete();
        await pending;

        expect(done, isTrue);
        expect(h.store.current?.token, 'refresh-1');
      },
    );

    test('adopt writes the credential and replaces memory', () async {
      final h = AuthHarness();

      await h.signIn(h.tokens(refresh: 'fresh'));

      expect(h.store.current?.token, 'fresh');
      expect(h.manager.currentRefreshToken, 'fresh');
    });

    test('store write failures do not break the refresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.store.failOnWrite = true;

      final outcome = await h.manager.refresh();

      expect(outcome, isA<Refreshed>());
      expect(h.manager.currentRefreshToken, 'refresh-1');
    });

    test('store clear failures still drop the in-memory tokens', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.store.failOnClear = true;

      await h.manager.clear();

      expect(h.manager.currentRefreshToken, isNull);
      expect(await h.manager.accessToken(), isNull);
    });
  });

  group('races with clear and adopt', () {
    test('clear during an in-flight refresh discards the result', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.refreshGate = Completer<void>();

      final pending = h.manager.refresh();
      await h.settle();
      await h.manager.clear();
      h.refreshGate!.complete();
      final outcome = await pending;

      expect(outcome, isA<NoCredential>());
      expect(h.manager.currentRefreshToken, isNull);
      expect(await h.manager.accessToken(), isNull);
      expect(h.store.current, isNull);
      expect(h.store.writes, 1);
      expect(h.endings, isEmpty);
    });

    test('clear during a failing refresh does not emit a sign-out', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.refreshGate = Completer<void>();
      h.refreshOverride = (options) => FakeResponse.error(401, 'token_reused');

      final pending = h.manager.refresh();
      await h.settle();
      await h.manager.clear();
      h.refreshGate!.complete();
      final outcome = await pending;
      await h.settle();

      expect(outcome, isA<NoCredential>());
      expect(h.endings, isEmpty);
    });

    test('adopt during an in-flight refresh keeps the new login', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.refreshGate = Completer<void>();

      final pending = h.manager.refresh();
      await h.settle();
      await h.signIn(
        h.tokens(access: 'login-access', refresh: 'login-refresh'),
      );
      h.refreshGate!.complete();
      await pending;

      expect(h.manager.currentRefreshToken, 'login-refresh');
      expect(h.store.current?.token, 'login-refresh');
    });

    test(
      'a refresh requested after adopt does not join a stale in-flight one',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshGate = Completer<void>();

        final stale = h.manager.refresh();
        await h.settle();
        await h.manager.clear();
        await h.signIn(
          h.tokens(access: 'login-access', refresh: 'login-refresh'),
        );
        final fresh = h.manager.refresh(staleAccess: 'login-access');
        h.refreshGate!.complete();

        expect(await stale, isA<NoCredential>());
        expect(await fresh, isA<Refreshed>());
        expect(h.manager.currentRefreshToken, 'refresh-2');
      },
    );

    test('endSession clears and notifies once', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());

      await h.manager.endSession(SignOutReason.reused);
      await h.settle();

      expect(h.endings, <SignOutReason>[SignOutReason.reused]);
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test('endSession after dispose does not throw', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      await h.manager.dispose();

      await h.manager.endSession(SignOutReason.expired);

      expect(h.store.current, isNull);
    });
  });

  group('accessToken', () {
    test('is null without credentials', () async {
      expect(await AuthHarness().manager.accessToken(), isNull);
    });

    test('returns the in-memory access token when fresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(access: 'abc'));

      expect(await h.manager.accessToken(), 'abc');
      expect(h.adapter.requests, isEmpty);
    });

    test('custom leeway is honoured', () async {
      final h = AuthHarness();
      final manager = TokenManager(
        store: h.store,
        api: FakeAuthApi(),
        now: () => h.clock,
        leeway: Duration.zero,
      );
      await manager.adopt(h.tokens(accessLeft: const Duration(seconds: 1)));

      expect(await manager.accessToken(), 'old');
    });
  });

  group('AuthTokens', () {
    test('accessNeedsRefresh is strict about the leeway', () {
      final tokens = AuthTokens(
        access: 'a',
        accessExpiresAt: t0.add(const Duration(seconds: 60)),
        refresh: 'r',
        refreshExpiresAt: t0.add(const Duration(days: 1)),
      );

      expect(
        tokens.accessNeedsRefresh(t0, const Duration(seconds: 60)),
        isFalse,
      );
      expect(
        tokens.accessNeedsRefresh(
          t0.add(const Duration(milliseconds: 1)),
          const Duration(seconds: 60),
        ),
        isTrue,
      );
      expect(
        tokens.accessNeedsRefresh(
          t0.add(const Duration(minutes: 2)),
          const Duration(seconds: 60),
        ),
        isTrue,
      );
    });

    test('toString never leaks token values', () {
      final tokens = AuthTokens(
        access: 'SECRET-ACCESS',
        accessExpiresAt: t0,
        refresh: 'SECRET-REFRESH',
        refreshExpiresAt: t0,
      );

      expect(tokens.toString(), isNot(contains('SECRET')));
      expect(tokens.refreshCredential.toString(), isNot(contains('SECRET')));
      expect(
        AuthGrant(tokens: tokens, user: sampleUser()).toString(),
        isNot(contains('SECRET')),
      );
    });

    test('value equality', () {
      AuthTokens make() => AuthTokens(
        access: 'a',
        accessExpiresAt: t0,
        refresh: 'r',
        refreshExpiresAt: t0,
      );

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make().refreshCredential, make().refreshCredential);
    });
  });
}
