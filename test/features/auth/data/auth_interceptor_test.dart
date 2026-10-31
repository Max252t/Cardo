import 'dart:async';

import 'package:cardo/core/network/api_call.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/data/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../helpers/auth_harness.dart';

void main() {
  group('single-flight refresh on 401', () {
    for (final parallel in <int>[1, 3, 10]) {
      test(
        '$parallel parallel token_expired -> one refresh, all retried',
        () async {
          final h = AuthHarness();
          await h.signIn(h.tokens());
          h.refreshGate = Completer<void>();

          final calls = <Future<Response<dynamic>>>[
            for (var i = 0; i < parallel; i++) h.getBoards(),
          ];
          await h.settle();
          expect(h.adapter.count(ApiPaths.refresh), 1);
          expect(h.adapter.count(ApiPaths.boards), parallel);

          h.refreshGate!.complete();
          final responses = await Future.wait(calls);

          expect(responses.map((r) => r.statusCode), everyElement(200));
          expect(h.adapter.count(ApiPaths.refresh), 1);
          final boards = h.adapter.to(ApiPaths.boards);
          expect(boards, hasLength(parallel * 2));
          expect(
            boards.take(parallel).map((r) => r.authorization),
            everyElement('Bearer old'),
          );
          expect(
            boards.skip(parallel).map((r) => r.authorization),
            everyElement('Bearer access-1'),
          );
          expect(h.adapter.to(ApiPaths.refresh).single.body, <String, Object?>{
            'refresh_token': 'refresh-0',
          });
          expect(h.endings, isEmpty);
        },
      );
    }

    test(
      'a late 401 for the old token reuses the already rotated pair',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        final gate = Completer<void>();
        var held = 0;
        h.protectedOverride = (options) async {
          final auth = options.headers['Authorization'];
          if (auth == 'Bearer old') {
            held++;
            if (held == 2) {
              await gate.future;
            }
            return FakeResponse.error(401, 'token_expired');
          }
          return FakeResponse.ok(<String, Object?>{'boards': <Object?>[]});
        };

        final first = h.getBoards();
        final second = h.getBoards();
        await first;
        expect(h.adapter.count(ApiPaths.refresh), 1);
        gate.complete();
        final late = await second;

        expect(late.statusCode, 200);
        expect(h.adapter.count(ApiPaths.refresh), 1);
        final retried = h.adapter
            .to(ApiPaths.boards)
            .where((r) => r.authorization == 'Bearer access-1');
        expect(retried, hasLength(2));
      },
    );

    test('invalid_token also triggers one refresh and a retry', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.protectedOverride = (options) {
        return options.headers['Authorization'] == 'Bearer old'
            ? FakeResponse.error(401, 'invalid_token')
            : FakeResponse.ok(<String, Object?>{'boards': <Object?>[]});
      };

      final response = await h.getBoards();

      expect(response.statusCode, 200);
      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(
        h.adapter.to(ApiPaths.boards).last.authorization,
        'Bearer access-1',
      );
    });

    test('the retried request keeps method and body', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.protectedOverride = (options) {
        return options.headers['Authorization'] == 'Bearer old'
            ? FakeResponse.error(401, 'token_expired')
            : FakeResponse.ok(<String, Object?>{'ok': true});
      };

      await h.dio.patch<dynamic>(
        ApiPaths.me,
        data: <String, String>{'display_name': 'Anna'},
      );

      final sent = h.adapter.to(ApiPaths.me);
      expect(sent, hasLength(2));
      expect(sent.map((r) => r.method), everyElement('PATCH'));
      expect(sent.last.body, <String, String>{'display_name': 'Anna'});
    });
  });

  group('second 401 after the retry', () {
    test('ends the session and clears tokens', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.protectedOverride = (options) =>
          FakeResponse.error(401, 'token_expired');

      await expectLater(
        h.getBoards(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      await h.settle();

      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(h.adapter.count(ApiPaths.boards), 2);
      expect(h.endings, <SignOutReason>[SignOutReason.expired]);
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
      expect(await h.manager.accessToken(), isNull);
    });
  });

  group('refresh itself fails', () {
    final cases = <String, (FakeResponse, SignOutReason)>{
      'invalid_token': (
        FakeResponse.error(401, 'invalid_token'),
        SignOutReason.expired,
      ),
      'token_expired': (
        FakeResponse.error(401, 'token_expired'),
        SignOutReason.expired,
      ),
      'token_reused': (
        FakeResponse.error(401, 'token_reused'),
        SignOutReason.reused,
      ),
      'unauthorized': (
        FakeResponse.error(401, 'unauthorized'),
        SignOutReason.expired,
      ),
      'validation_error': (
        FakeResponse.error(400, 'validation_error'),
        SignOutReason.expired,
      ),
    };
    for (final entry in cases.entries) {
      test(
        '${entry.key} wipes tokens and signs out with the right reason',
        () async {
          final h = AuthHarness();
          await h.signIn(h.tokens());
          h.refreshOverride = (options) => entry.value.$1;

          await expectLater(h.getBoards(), throwsA(isA<DioException>()));
          await h.settle();

          expect(h.endings, <SignOutReason>[entry.value.$2]);
          expect(h.store.current, isNull);
          expect(h.manager.currentRefreshToken, isNull);
          expect(h.adapter.count(ApiPaths.refresh), 1);
          expect(h.adapter.count(ApiPaths.boards), 1);
        },
      );
    }

    test(
      'parallel callers share one failed refresh and one sign-out',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshGate = Completer<void>();
        h.refreshOverride = (options) =>
            FakeResponse.error(401, 'token_reused');

        final calls = <Future<Object?>>[
          for (var i = 0; i < 5; i++)
            h.getBoards().then<Object?>((_) => null, onError: (Object e) => e),
        ];
        await h.settle();
        h.refreshGate!.complete();
        final errors = await Future.wait(calls);

        expect(errors, everyElement(isA<DioException>()));
        expect(h.adapter.count(ApiPaths.refresh), 1);
        expect(h.endings, <SignOutReason>[SignOutReason.reused]);
      },
    );
  });

  group('network trouble during refresh', () {
    for (final type in <DioExceptionType>[
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test(
        '$type keeps the session and fails the call with NetworkFailure',
        () async {
          final h = AuthHarness();
          await h.signIn(h.tokens());
          h.refreshOverride = (options) => FakeResponse.network(type);

          final result = await apiCall(h.getBoards);

          final expectedKind = type == DioExceptionType.connectionError
              ? NetworkFailureKind.offline
              : NetworkFailureKind.timeout;
          expect(
            result,
            Failure<Response<dynamic>, ApiFailure>(
              NetworkFailure(expectedKind),
            ),
          );
          expect(h.endings, isEmpty);
          expect(h.store.current?.token, 'refresh-0');
          expect(h.store.clears, 0);
          expect(h.manager.currentRefreshToken, 'refresh-0');

          h.refreshOverride = null;
          final retry = await h.getBoards();
          expect(retry.statusCode, 200);
          expect(h.manager.currentRefreshToken, 'refresh-1');
        },
      );
    }

    test('a 5xx or 429 on refresh also keeps the session', () async {
      for (final response in <FakeResponse>[
        FakeResponse.error(500, 'internal'),
        FakeResponse.error(
          429,
          'rate_limited',
          headers: <String, String>{'Retry-After': '3'},
        ),
        FakeResponse.error(503, 'busy'),
      ]) {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshOverride = (options) => response;

        final result = await apiCall(h.getBoards);

        expect(result.isSuccess, isFalse);
        expect(h.endings, isEmpty);
        expect(h.store.current?.token, 'refresh-0');
        expect(h.manager.currentRefreshToken, 'refresh-0');
      }
    });

    test(
      'refresh failure surfaces its own failure type to the caller',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshOverride = (options) => FakeResponse.error(
          429,
          'rate_limited',
          headers: <String, String>{'Retry-After': '12'},
        );

        final result = await apiCall(h.getBoards);

        expect(
          result.failureOrNull,
          const RateLimitedFailure(retryAfter: Duration(seconds: 12)),
        );
      },
    );
  });

  group('proactive refresh', () {
    test('under 60 seconds left refreshes before the request', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accessLeft: const Duration(seconds: 59)));

      final response = await h.getBoards();

      expect(response.statusCode, 200);
      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(h.adapter.count(ApiPaths.boards), 1);
      expect(
        h.adapter.to(ApiPaths.boards).single.authorization,
        'Bearer access-1',
      );
    });

    test('61 seconds left does not refresh', () async {
      final h = AuthHarness();
      await h.signIn(
        h.tokens(accessLeft: const Duration(seconds: 61), accepted: true),
      );

      await h.getBoards();

      expect(h.adapter.count(ApiPaths.refresh), 0);
      expect(h.adapter.to(ApiPaths.boards).single.authorization, 'Bearer old');
    });

    test('exactly 60 seconds left does not refresh', () async {
      final h = AuthHarness();
      await h.signIn(
        h.tokens(accessLeft: const Duration(seconds: 60), accepted: true),
      );

      await h.getBoards();

      expect(h.adapter.count(ApiPaths.refresh), 0);
    });

    test('the injected clock drives the decision', () async {
      final h = AuthHarness();
      await h.signIn(
        h.tokens(accessLeft: const Duration(minutes: 5), accepted: true),
      );
      await h.getBoards();
      expect(h.adapter.count(ApiPaths.refresh), 0);

      h.clock = h.clock.add(const Duration(minutes: 4, seconds: 30));
      await h.getBoards();

      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(
        h.adapter.to(ApiPaths.boards).last.authorization,
        'Bearer access-1',
      );
    });

    test('parallel requests share one proactive refresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accessLeft: const Duration(seconds: 10)));
      h.refreshGate = Completer<void>();

      final calls = <Future<Response<dynamic>>>[
        for (var i = 0; i < 5; i++) h.getBoards(),
      ];
      await h.settle();
      h.refreshGate!.complete();
      await Future.wait(calls);

      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(
        h.adapter.to(ApiPaths.boards).map((r) => r.authorization),
        everyElement('Bearer access-1'),
      );
    });

    test(
      'a failed proactive refresh falls back to the current access token',
      () async {
        final h = AuthHarness();
        await h.signIn(
          h.tokens(accessLeft: const Duration(seconds: 30), accepted: true),
        );
        h.refreshOverride = (options) =>
            FakeResponse.network(DioExceptionType.connectionError);

        final response = await h.getBoards();

        expect(response.statusCode, 200);
        expect(
          h.adapter.to(ApiPaths.boards).single.authorization,
          'Bearer old',
        );
        expect(h.endings, isEmpty);
      },
    );

    test(
      'a proactive refresh that ends the session sends no Authorization',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens(accessLeft: const Duration(seconds: 30)));
        h.refreshOverride = (options) =>
            FakeResponse.error(401, 'token_reused');

        await expectLater(h.getBoards(), throwsA(isA<DioException>()));
        await h.settle();

        expect(h.endings, <SignOutReason>[SignOutReason.reused]);
        expect(h.adapter.to(ApiPaths.boards).single.authorization, isNull);
        expect(h.adapter.count(ApiPaths.refresh), 1);
      },
    );
  });

  group('Authorization header policy', () {
    test('public paths never carry Authorization', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));

      for (final path in ApiPaths.public) {
        await h.dio.post<dynamic>(path, data: <String, String>{});
      }

      expect(
        h.adapter.requests.map((r) => r.path),
        containsAll(ApiPaths.public),
      );
      for (final request in h.adapter.requests) {
        expect(
          request.authorization,
          isNull,
          reason: '${request.path} must be anonymous',
        );
      }
    });

    test('public set is exactly register, login, refresh, healthz, readyz', () {
      expect(ApiPaths.public, <String>{
        '/api/auth/register',
        '/api/auth/login',
        '/api/auth/refresh',
        '/healthz',
        '/readyz',
      });
    });

    test(
      'protected paths carry Bearer with the current access token',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens(accepted: true));

        await h.getBoards();
        await h.dio.get<dynamic>(ApiPaths.me);

        expect(
          h.adapter.requests.map((r) => r.authorization),
          everyElement('Bearer old'),
        );
      },
    );

    test('logout is protected', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));

      await h.dio.post<dynamic>(ApiPaths.logout, data: <String, String>{});

      expect(h.adapter.to(ApiPaths.logout).single.authorization, 'Bearer old');
    });

    test('without credentials the request goes out anonymous and a 401 is passed through', () async {
      final h = AuthHarness();

      final result = await apiCall(h.getBoards);

      expect(h.adapter.to(ApiPaths.boards).single.authorization, isNull);
      expect(h.adapter.count(ApiPaths.refresh), 0);
      expect(
        result.failureOrNull,
        const UnauthorizedFailure(UnauthorizedKind.tokenExpired),
      );
    });

    test('a 401 on a public path does not start a refresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.adapter.handler = (options) =>
          FakeResponse.error(401, 'invalid_credentials');

      final result = await apiCall(
        () => h.dio.post<dynamic>(ApiPaths.login, data: <String, String>{}),
      );

      expect(result.failureOrNull, const InvalidCredentialsFailure());
      expect(h.adapter.count(ApiPaths.refresh), 0);
    });
  });

  group('401 unauthorized with a sent token', () {
    test('ends the session without a refresh', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.error(401, 'unauthorized');

      await expectLater(h.getBoards(), throwsA(isA<DioException>()));
      await h.settle();

      expect(h.adapter.count(ApiPaths.refresh), 0);
      expect(h.endings, <SignOutReason>[SignOutReason.expired]);
      expect(h.manager.currentRefreshToken, isNull);
    });
  });

  group('401 unauthorized on logout', () {
    test('is passed through without ending the session', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.error(401, 'unauthorized');

      await expectLater(
        h.dio.post<dynamic>(ApiPaths.logout, data: <String, String>{}),
        throwsA(isA<DioException>()),
      );
      await h.settle();

      expect(h.adapter.count(ApiPaths.refresh), 0);
      expect(h.adapter.count(ApiPaths.logout), 1);
      expect(h.endings, isEmpty);
    });
  });

  group('401 that must not refresh', () {
    final cases = <String, FakeResponse>{
      'token_reused': FakeResponse.error(401, 'token_reused'),
      'invalid_credentials': FakeResponse.error(401, 'invalid_credentials'),
      'no body': FakeResponse.empty(401),
      'html body': const FakeResponse(401, text: '<html></html>'),
      '403 forbidden': FakeResponse.error(403, 'forbidden'),
      '404 not_found': FakeResponse.error(404, 'not_found'),
      '500 internal': FakeResponse.error(500, 'internal'),
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        final h = AuthHarness();
        await h.signIn(h.tokens(accepted: true));
        h.protectedOverride = (options) => entry.value;

        await expectLater(h.getBoards(), throwsA(isA<DioException>()));

        expect(h.adapter.count(ApiPaths.refresh), 0);
        expect(h.adapter.count(ApiPaths.boards), 1);
        expect(h.endings, isEmpty);
        expect(h.manager.currentRefreshToken, 'refresh-0');
      });
    }
  });

  group('logout request', () {
    Future<void> logout(AuthHarness h) async {
      final refresh = h.manager.currentRefreshToken;
      await h.dio.post<dynamic>(
        ApiPaths.logout,
        data: <String, String?>{'refresh_token': refresh},
      );
    }

    test('almost expired access goes out without a refresh and with the current refresh token', () async {
      final h = AuthHarness();
      await h.signIn(
        h.tokens(accessLeft: const Duration(seconds: 20), accepted: true),
      );

      await logout(h);
      await h.manager.clear();

      expect(h.adapter.count(ApiPaths.refresh), 0);
      final sent = h.adapter.to(ApiPaths.logout).single;
      expect(sent.authorization, 'Bearer old');
      expect(sent.body, <String, Object?>{'refresh_token': 'refresh-0'});
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test(
      'token_expired refreshes once and resends with the rotated refresh token',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());

        await logout(h);
        await h.manager.clear();

        expect(h.adapter.count(ApiPaths.refresh), 1);
        final sent = h.adapter.to(ApiPaths.logout);
        expect(sent, hasLength(2));
        expect(sent.first.authorization, 'Bearer old');
        expect(sent.first.body, <String, Object?>{
          'refresh_token': 'refresh-0',
        });
        expect(sent.last.authorization, 'Bearer access-1');
        expect(sent.last.body, <String, Object?>{'refresh_token': 'refresh-1'});
        expect(h.store.current, isNull);
        expect(h.manager.currentRefreshToken, isNull);
        expect(h.endings, isEmpty);
      },
    );

    test('a repeated 401 does not loop and forces no sign-out', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens());
      h.protectedOverride = (options) =>
          FakeResponse.error(401, 'token_expired');

      await expectLater(logout(h), throwsA(isA<DioException>()));
      await h.settle();
      await h.manager.clear();

      expect(h.adapter.count(ApiPaths.refresh), 1);
      expect(h.adapter.count(ApiPaths.logout), 2);
      expect(h.endings, isEmpty);
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test(
      'a failing refresh sends logout once and tokens end cleared',
      () async {
        final h = AuthHarness();
        await h.signIn(h.tokens());
        h.refreshOverride = (options) =>
            FakeResponse.network(DioExceptionType.connectionError);

        await expectLater(logout(h), throwsA(isA<DioException>()));
        await h.manager.clear();

        expect(h.adapter.count(ApiPaths.refresh), 1);
        expect(h.adapter.count(ApiPaths.logout), 1);
        expect(h.store.current, isNull);
        expect(h.manager.currentRefreshToken, isNull);
      },
    );

    test('a dead network on logout still ends with cleared tokens', () async {
      final h = AuthHarness();
      await h.signIn(h.tokens(accepted: true));
      h.protectedOverride = (options) =>
          FakeResponse.network(DioExceptionType.connectionError);

      await expectLater(logout(h), throwsA(isA<DioException>()));
      await h.manager.clear();

      expect(h.adapter.count(ApiPaths.refresh), 0);
      expect(h.adapter.count(ApiPaths.logout), 1);
      expect(h.store.current, isNull);
      expect(h.manager.currentRefreshToken, isNull);
    });

    test('endsSessionOn401 spares only logout', () {
      expect(endsSessionOn401(ApiPaths.logout), isFalse);
      expect(endsSessionOn401(ApiPaths.boards), isTrue);
      expect(endsSessionOn401(ApiPaths.me), isTrue);
    });
  });
}
