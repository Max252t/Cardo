import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/auth/data/auth_repository_impl.dart';
import 'package:cardo/features/auth/data/dio_auth_api.dart';
import 'package:cardo/features/auth/data/token_manager.dart';
import 'package:cardo/features/auth/domain/auth_repository.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/domain/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/memory_token_store.dart';
import '../helpers/auth_harness.dart';
import '../helpers/fake_auth_api.dart';

class Unit {
  Unit({RefreshCredential? stored, DateTime? now}) : clock = now ?? t0 {
    store = MemoryTokenStore(stored);
    api = FakeAuthApi();
    manager = TokenManager(store: store, api: api, now: () => clock);
    repository = AuthRepositoryImpl(api: api, tokens: manager);
    endings = <SignOutReason>[];
    repository.forcedSignOuts.listen(endings.add);
  }

  DateTime clock;
  late final MemoryTokenStore store;
  late final FakeAuthApi api;
  late final TokenManager manager;
  late final AuthRepositoryImpl repository;
  late final List<SignOutReason> endings;

  RefreshCredential get validCredential => RefreshCredential(
    token: 'stored',
    expiresAt: clock.add(const Duration(days: 5)),
  );

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

Unit unitWithStored() {
  final unit = Unit();
  unit.store.current = unit.validCredential;
  return unit;
}

void main() {
  group('restore', () {
    test(
      'without a stored credential there is no session and no reason',
      () async {
        final unit = Unit();

        final outcome = await unit.repository.restore();

        expect(outcome, isA<NoSession>());
        expect((outcome as NoSession).reason, isNull);
        expect(unit.api.calls, isEmpty);
      },
    );

    test(
      'a locally expired credential is left for the server to judge',
      () async {
        final unit = Unit();
        unit.store.current = RefreshCredential(
          token: 'old',
          expiresAt: unit.clock.subtract(const Duration(days: 1)),
        );
        unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
          UnauthorizedFailure(UnauthorizedKind.tokenExpired),
        );

        final outcome = await unit.repository.restore();
        await unit.flush();

        expect((outcome as NoSession).reason, SignOutReason.expired);
        expect(unit.store.current, isNull);
        expect(unit.api.calls, isNotEmpty);
      },
    );

    test('a valid credential refreshes, loads the user and restores', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = Success<AuthTokens, ApiFailure>(
        sampleTokens(access: 'a2', refresh: 'r2'),
      );
      unit.api.meResult = Success<User, ApiFailure>(sampleUser());

      final outcome = await unit.repository.restore();

      expect(outcome, isA<Restored>());
      expect((outcome as Restored).user, sampleUser());
      expect(unit.api.calls, <String>['refresh', 'getMe']);
      expect(unit.api.args.first['refresh'], 'stored');
      expect(unit.store.current?.token, 'r2');
      expect(unit.manager.currentRefreshToken, 'r2');
    });

    test('refresh rejected as invalid ends the session as expired', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
        UnauthorizedFailure(UnauthorizedKind.invalidToken),
      );

      final outcome = await unit.repository.restore();
      await unit.flush();

      expect(outcome, isA<NoSession>());
      expect((outcome as NoSession).reason, SignOutReason.expired);
      expect(unit.store.current, isNull);
      expect(unit.endings, <SignOutReason>[SignOutReason.expired]);
    });

    test('token_reused ends the session with reason reused', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
        UnauthorizedFailure(UnauthorizedKind.tokenReused),
      );

      final outcome = await unit.repository.restore();
      await unit.flush();

      expect((outcome as NoSession).reason, SignOutReason.reused);
      expect(unit.endings, <SignOutReason>[SignOutReason.reused]);
      expect(unit.store.current, isNull);
    });

    test('a network failure is unavailable and keeps the credential', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );

      final outcome = await unit.repository.restore();

      expect(outcome, isA<RestoreUnavailable>());
      expect(
        (outcome as RestoreUnavailable).failure,
        const NetworkFailure(NetworkFailureKind.offline),
      );
      expect(unit.store.current?.token, 'stored');
      expect(unit.endings, isEmpty);
    });

    test(
      'a server error on refresh is unavailable and keeps the credential',
      () async {
        final unit = unitWithStored();
        unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
          UnknownFailure(statusCode: 500),
        );

        final outcome = await unit.repository.restore();

        expect(outcome, isA<RestoreUnavailable>());
        expect(unit.store.current?.token, 'stored');
      },
    );

    test('getMe unauthorized after a good refresh ends the session', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = Success<AuthTokens, ApiFailure>(sampleTokens());
      unit.api.meResult = const Failure<User, ApiFailure>(
        UnauthorizedFailure(UnauthorizedKind.tokenExpired),
      );

      final outcome = await unit.repository.restore();
      await unit.flush();

      expect((outcome as NoSession).reason, SignOutReason.expired);
      expect(unit.store.current, isNull);
      expect(unit.manager.currentRefreshToken, isNull);
      expect(unit.endings, <SignOutReason>[SignOutReason.expired]);
    });

    test('getMe network failure after a good refresh is unavailable and keeps tokens', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = Success<AuthTokens, ApiFailure>(
        sampleTokens(refresh: 'r2'),
      );
      unit.api.meResult = const Failure<User, ApiFailure>(
        NetworkFailure(NetworkFailureKind.timeout),
      );

      final outcome = await unit.repository.restore();

      expect(outcome, isA<RestoreUnavailable>());
      expect(unit.store.current?.token, 'r2');
      expect(unit.endings, isEmpty);
    });

    test('getMe server error after a good refresh is unavailable', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = Success<AuthTokens, ApiFailure>(sampleTokens());
      unit.api.meResult = const Failure<User, ApiFailure>(
        UnknownFailure(statusCode: 500),
      );

      expect(await unit.repository.restore(), isA<RestoreUnavailable>());
    });

    test('a retry after Unavailable can still restore', () async {
      final unit = unitWithStored();
      unit.api.refreshResult = const Failure<AuthTokens, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );
      expect(await unit.repository.restore(), isA<RestoreUnavailable>());

      unit.api.refreshResult = Success<AuthTokens, ApiFailure>(sampleTokens());
      unit.api.meResult = Success<User, ApiFailure>(sampleUser());

      expect(await unit.repository.restore(), isA<Restored>());
    });
  });

  group('login and register', () {
    test('login success adopts the tokens and returns the user', () async {
      final unit = Unit();
      unit.api.loginResult = Success<AuthGrant, ApiFailure>(
        AuthGrant(
          tokens: sampleTokens(refresh: 'r9'),
          user: sampleUser(),
        ),
      );

      final result = await unit.repository.login(
        email: 'anna@example.com',
        password: 'secret-pass',
      );

      expect(result, Success<User, ApiFailure>(sampleUser()));
      expect(unit.store.current?.token, 'r9');
      expect(unit.manager.currentRefreshToken, 'r9');
      expect(await unit.manager.accessToken(), 'access-x');
      expect(unit.api.args.single, <String, Object?>{
        'email': 'anna@example.com',
        'password': 'secret-pass',
      });
    });

    test('register passes every field through and adopts the tokens', () async {
      final unit = Unit();
      unit.api.registerResult = Success<AuthGrant, ApiFailure>(
        AuthGrant(tokens: sampleTokens(), user: sampleUser()),
      );

      final result = await unit.repository.register(
        email: 'a@b.co',
        password: 'password1',
        displayName: 'Anna',
        avatarColor: '#7C3AED',
      );

      expect(result.isSuccess, isTrue);
      expect(unit.api.args.single, <String, Object?>{
        'email': 'a@b.co',
        'password': 'password1',
        'displayName': 'Anna',
        'avatarColor': '#7C3AED',
      });
      expect(unit.store.current, isNotNull);
    });

    test('failures leave tokens untouched', () async {
      for (final failure in <ApiFailure>[
        const InvalidCredentialsFailure(),
        const EmailTakenFailure(),
        const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
        const ValidationFailure(),
        const NetworkFailure(NetworkFailureKind.offline),
      ]) {
        final unit = Unit();
        unit.api.loginResult = Failure<AuthGrant, ApiFailure>(failure);
        unit.api.registerResult = Failure<AuthGrant, ApiFailure>(failure);

        final login = await unit.repository.login(email: 'a', password: 'b');
        final register = await unit.repository.register(
          email: 'a',
          password: 'b',
          displayName: 'c',
        );

        expect(login, Failure<User, ApiFailure>(failure));
        expect(register, Failure<User, ApiFailure>(failure));
        expect(unit.store.current, isNull);
        expect(unit.manager.currentRefreshToken, isNull);
        expect(unit.store.writes, 0);
      }
    });
  });

  group('over HTTP', () {
    AuthRepositoryImpl build(AuthHarness h) =>
        AuthRepositoryImpl(api: DioAuthApi(h.dio), tokens: h.manager);

    test(
      'login success stores the refresh token and sends no Authorization',
      () async {
        final h = AuthHarness();
        h.adapter.handler = (options) => FakeResponse.ok(
          tokenJson(access: 'A', refresh: 'R', user: userJson()),
        );
        final repo = build(h);

        final result = await repo.login(
          email: 'anna@example.com',
          password: 'pw',
        );

        expect(result.valueOrNull?.email, 'anna@example.com');
        expect(h.store.current?.token, 'R');
        expect(h.adapter.requests.single.path, ApiPaths.login);
        expect(h.adapter.requests.single.authorization, isNull);
        expect(h.adapter.requests.single.body, <String, Object?>{
          'email': 'anna@example.com',
          'password': 'pw',
        });
      },
    );

    test('register sends avatar_color only when chosen', () async {
      final h = AuthHarness();
      h.adapter.handler = (options) =>
          FakeResponse.ok(tokenJson(user: userJson()), status: 201);
      final repo = build(h);

      await repo.register(
        email: 'a@b.co',
        password: 'password1',
        displayName: 'A',
      );
      await repo.register(
        email: 'a@b.co',
        password: 'password1',
        displayName: 'A',
        avatarColor: '#0EA5E9',
      );

      final bodies = h.adapter
          .to(ApiPaths.register)
          .map((r) => r.body)
          .toList();
      expect(bodies.first, <String, Object?>{
        'email': 'a@b.co',
        'password': 'password1',
        'display_name': 'A',
      });
      expect(bodies.last['avatar_color'], '#0EA5E9');
    });

    final failures = <String, (FakeResponse, ApiFailure)>{
      'email_taken 409': (
        FakeResponse.error(409, 'email_taken'),
        const EmailTakenFailure(),
      ),
      'invalid_credentials 401': (
        FakeResponse.error(401, 'invalid_credentials'),
        const InvalidCredentialsFailure(),
      ),
      'rate_limited 429 with Retry-After': (
        FakeResponse.error(
          429,
          'rate_limited',
          headers: <String, String>{'Retry-After': '45'},
        ),
        const RateLimitedFailure(retryAfter: Duration(seconds: 45)),
      ),
      'validation_error 400': (
        FakeResponse.error(400, 'validation_error', message: 'bad email'),
        const ValidationFailure(message: 'bad email'),
      ),
      'overloaded 503 with Retry-After': (
        FakeResponse.error(
          503,
          'overloaded',
          headers: <String, String>{'Retry-After': '2'},
        ),
        const BusyFailure(retryAfter: Duration(seconds: 2)),
      ),
    };
    for (final entry in failures.entries) {
      test('login/register map ${entry.key}', () async {
        final h = AuthHarness();
        h.adapter.handler = (options) => entry.value.$1;
        final repo = build(h);

        final login = await repo.login(email: 'a', password: 'b');
        final register = await repo.register(
          email: 'a',
          password: 'b',
          displayName: 'c',
        );

        expect(login.failureOrNull, entry.value.$2);
        expect(register.failureOrNull, entry.value.$2);
        expect(h.store.current, isNull);
        expect(h.adapter.count(ApiPaths.refresh), 0);
      });
    }

    test('a login response without a user is unknown', () async {
      final h = AuthHarness();
      h.adapter.handler = (options) => FakeResponse.ok(tokenJson());

      final result = await build(h).login(email: 'a', password: 'b');

      expect(result.failureOrNull, const UnknownFailure());
      expect(h.store.current, isNull);
    });

    test('offline login is a network failure', () async {
      final h = AuthHarness();
      h.adapter.handler = (options) =>
          FakeResponse.network(DioExceptionType.connectionError);

      final result = await build(h).login(email: 'a', password: 'b');

      expect(
        result.failureOrNull,
        const NetworkFailure(NetworkFailureKind.offline),
      );
    });

    test(
      'restore over HTTP walks refresh then /api/me with the new token',
      () async {
        final h = AuthHarness();
        h.store.current = RefreshCredential(
          token: 'stored',
          expiresAt: h.clock.add(const Duration(days: 1)),
        );
        final repo = build(h);

        final outcome = await repo.restore();

        expect(outcome, isA<Restored>());
        expect(h.adapter.requests.map((r) => r.path), <String>[
          ApiPaths.refresh,
          ApiPaths.me,
        ]);
        expect(
          h.adapter.to(ApiPaths.me).single.authorization,
          'Bearer access-1',
        );
      },
    );
  });

  group('updateProfile', () {
    test('sends only the provided fields and returns the new user', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.ok(userJson(displayName: 'Bea', avatarColor: '#0ea5e9'));
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      final result = await repo.updateProfile(displayName: 'Bea');

      expect(result.valueOrNull?.displayName, 'Bea');
      expect(result.valueOrNull?.avatarColor, '#0EA5E9');
      final sent = h.adapter.to(ApiPaths.me).single;
      expect(sent.method, 'PATCH');
      expect(sent.body, <String, Object?>{'display_name': 'Bea'});
      expect(sent.authorization, 'Bearer old');
    });

    test('sends both fields when both are given', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) => FakeResponse.ok(userJson());
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      await repo.updateProfile(displayName: 'Bea', avatarColor: '#0EA5E9');

      expect(h.adapter.to(ApiPaths.me).single.body, <String, Object?>{
        'display_name': 'Bea',
        'avatar_color': '#0EA5E9',
      });
    });

    test('validation errors are returned as failures', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.error(400, 'validation_error');
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      final result = await repo.updateProfile(displayName: '');

      expect(result.failureOrNull, const ValidationFailure(message: 'message'));
    });

    test('an expired access token is refreshed transparently', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.protectedOverride = (options) {
        return options.headers['Authorization'] == 'Bearer old'
            ? FakeResponse.error(401, 'token_expired')
            : FakeResponse.ok(userJson(displayName: 'Bea'));
      };
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      final result = await repo.updateProfile(displayName: 'Bea');

      expect(result.valueOrNull?.displayName, 'Bea');
      expect(h.adapter.count(ApiPaths.refresh), 1);
    });
  });

  group('logout', () {
    test(
      'revokes the refresh token on the server and clears locally',
      () async {
        final unit = Unit();
        await unit.manager.adopt(sampleTokens(refresh: 'r1'));

        await unit.repository.logout();

        expect(unit.api.calls, <String>['logout']);
        expect(unit.api.args.single['refresh'], 'r1');
        expect(unit.store.current, isNull);
        expect(unit.manager.currentRefreshToken, isNull);
      },
    );

    test('a network failure still clears the tokens', () async {
      final unit = Unit();
      await unit.manager.adopt(sampleTokens());
      unit.api.logoutResult = const Failure<void, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );

      await unit.repository.logout();

      expect(unit.store.current, isNull);
      expect(unit.manager.currentRefreshToken, isNull);
    });

    test('a server error still clears the tokens', () async {
      final unit = Unit();
      await unit.manager.adopt(sampleTokens());
      unit.api.logoutResult = const Failure<void, ApiFailure>(
        UnknownFailure(statusCode: 500),
      );

      await unit.repository.logout();

      expect(unit.store.current, isNull);
    });

    test('without a refresh token it does not call the server', () async {
      final unit = Unit();

      await unit.repository.logout();

      expect(unit.api.calls, isEmpty);
      expect(unit.store.current, isNull);
    });

    test('does not announce itself as a forced sign-out', () async {
      final unit = Unit();
      await unit.manager.adopt(sampleTokens());

      await unit.repository.logout();
      await unit.flush();

      expect(unit.endings, isEmpty);
    });

    test('over HTTP a dead network still clears everything', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.network(DioExceptionType.connectionError);
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      await repo.logout();

      expect(h.adapter.count(ApiPaths.logout), 1);
      expect(h.adapter.to(ApiPaths.logout).single.body, <String, Object?>{
        'refresh_token': 'refresh-0',
      });
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test(
      'over HTTP an almost expired access token is not refreshed before logout',
      () async {
        final h = AuthHarness();
        await h.signIn(
          h.tokens(accessLeft: const Duration(seconds: 20), accepted: true),
        );
        final repo = AuthRepositoryImpl(
          api: DioAuthApi(h.dio),
          tokens: h.manager,
        );

        await repo.logout();

        expect(h.adapter.count(ApiPaths.refresh), 0);
        final logout = h.adapter.to(ApiPaths.logout).single;
        expect(logout.body, <String, Object?>{'refresh_token': 'refresh-0'});
        expect(logout.authorization, 'Bearer old');
        expect(h.store.current, isNull);
        expect(h.manager.currentRefreshToken, isNull);
      },
    );

    test('over HTTP a token_expired logout refreshes once and resends the new refresh token', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      final repo = AuthRepositoryImpl(
        api: DioAuthApi(h.dio),
        tokens: h.manager,
      );

      await repo.logout();

      expect(h.adapter.count(ApiPaths.refresh), 1);
      final logouts = h.adapter.to(ApiPaths.logout);
      expect(logouts.length, 2);
      expect(logouts.first.body, <String, Object?>{
        'refresh_token': 'refresh-0',
      });
      expect(logouts.last.body, <String, Object?>{
        'refresh_token': 'refresh-1',
      });
      expect(logouts.last.authorization, 'Bearer access-1');
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test(
      'over HTTP a failing refresh during logout still clears the tokens',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshOverride = (options) =>
            FakeResponse.network(DioExceptionType.connectionError);
        final repo = AuthRepositoryImpl(
          api: DioAuthApi(h.dio),
          tokens: h.manager,
        );

        await repo.logout();

        expect(h.adapter.count(ApiPaths.logout), 1);
        expect(h.store.current, isNull);
        expect(h.manager.currentRefreshToken, isNull);
      },
    );

    test('forcedSignOuts mirrors the token manager', () async {
      final unit = Unit();
      await unit.manager.adopt(sampleTokens());

      await unit.manager.endSession(SignOutReason.reused);
      await unit.flush();

      expect(unit.endings, <SignOutReason>[SignOutReason.reused]);
    });
  });
}
