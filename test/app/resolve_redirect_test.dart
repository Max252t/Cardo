import 'package:cardo/app/app_router.dart';
import 'package:cardo/app/app_routes.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/helpers/fake_auth_api.dart';

String? redirect(
  String location, {
  bool configValid = true,
  Session? session,
  bool debug = false,
}) {
  return resolveRedirect(
    configValid: configValid,
    session: session,
    location: Uri.parse(location),
    debug: debug,
  );
}

final Session signedIn = SessionSignedIn(sampleUser());

void main() {
  group('debug-only routes', () {
    for (final path in <String>[AppRoutes.demo, AppRoutes.design]) {
      test('$path is open in debug whatever the state', () {
        expect(redirect(path, debug: true), isNull);
        expect(redirect(path, debug: true, configValid: false), isNull);
        expect(redirect(path, debug: true, session: signedIn), isNull);
        expect(
          redirect(path, debug: true, session: const SessionSignedOut()),
          isNull,
        );
      });

      test('$path bounces to /boards in release whatever the state', () {
        expect(redirect(path), AppRoutes.boards);
        expect(redirect(path, configValid: false), AppRoutes.boards);
        expect(redirect(path, session: signedIn), AppRoutes.boards);
        expect(
          redirect(path, session: const SessionSignedOut()),
          AppRoutes.boards,
        );
      });
    }
  });

  group('invalid config', () {
    test('everything goes to /config', () {
      for (final path in <String>[
        '/',
        AppRoutes.boards,
        '/boards/42',
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.profile,
        AppRoutes.splash,
      ]) {
        expect(
          redirect(path, configValid: false, session: signedIn),
          AppRoutes.config,
          reason: path,
        );
      }
    });

    test('/config itself is allowed', () {
      expect(redirect(AppRoutes.config, configValid: false), isNull);
    });

    test('the session is irrelevant', () {
      expect(redirect(AppRoutes.login, configValid: false), AppRoutes.config);
      expect(
        redirect(
          AppRoutes.boards,
          configValid: false,
          session: const SessionRestoring(),
        ),
        AppRoutes.config,
      );
    });
  });

  group('valid config', () {
    test('/config is not reachable', () {
      expect(redirect(AppRoutes.config), AppRoutes.boards);
      expect(redirect(AppRoutes.config, session: signedIn), AppRoutes.boards);
    });
  });

  group('restoring and unavailable', () {
    for (final session in <Session?>[
      null,
      const SessionRestoring(),
      const SessionUnavailable(),
    ]) {
      test('${session ?? 'no session'} funnels everything into the splash', () {
        expect(
          redirect(AppRoutes.boards, session: session),
          AppRoutes.splashFrom('/boards'),
        );
        expect(
          redirect('/boards/42', session: session),
          AppRoutes.splashFrom('/boards/42'),
        );
        expect(
          redirect(AppRoutes.login, session: session),
          AppRoutes.splashFrom('/login'),
        );
      });

      test('${session ?? 'no session'} keeps the splash itself', () {
        expect(redirect(AppRoutes.splash, session: session), isNull);
        expect(
          redirect(AppRoutes.splashFrom('/boards'), session: session),
          isNull,
        );
      });
    }

    test('the full original location, including its query, is remembered', () {
      final target = redirect('/boards/42?tab=2&x=y');
      final from = Uri.parse(target!).queryParameters[AppRoutes.fromParam];

      expect(Uri.parse(target).path, AppRoutes.splash);
      expect(from, '/boards/42?tab=2&x=y');
    });
  });

  group('signed out', () {
    const session = SessionSignedOut();

    test('login and register stay open', () {
      expect(redirect(AppRoutes.login, session: session), isNull);
      expect(redirect(AppRoutes.register, session: session), isNull);
    });

    test('everything else goes to login', () {
      for (final path in <String>[
        '/',
        AppRoutes.boards,
        '/boards/42',
        AppRoutes.profile,
        AppRoutes.splash,
        '/nowhere',
      ]) {
        expect(redirect(path, session: session), AppRoutes.login, reason: path);
      }
    });

    test('a sign-out reason does not change routing', () {
      for (final reason in SignOutReason.values) {
        final withReason = SessionSignedOut(reason: reason);
        expect(redirect(AppRoutes.login, session: withReason), isNull);
        expect(
          redirect(AppRoutes.boards, session: withReason),
          AppRoutes.login,
        );
      }
    });
  });

  group('signed in', () {
    test('ordinary routes are open', () {
      for (final path in <String>[
        AppRoutes.boards,
        '/boards/42',
        AppRoutes.profile,
        '/nowhere',
      ]) {
        expect(redirect(path, session: signedIn), isNull, reason: path);
      }
    });

    test('entry routes bounce to /boards', () {
      for (final path in <String>['/', AppRoutes.login, AppRoutes.register]) {
        expect(
          redirect(path, session: signedIn),
          AppRoutes.boards,
          reason: path,
        );
      }
    });

    test('the splash without from goes to /boards', () {
      expect(redirect(AppRoutes.splash, session: signedIn), AppRoutes.boards);
    });

    test('the splash returns to the remembered location', () {
      expect(
        redirect(AppRoutes.splashFrom('/boards/42'), session: signedIn),
        '/boards/42',
      );
      expect(
        redirect(AppRoutes.splashFrom(AppRoutes.profile), session: signedIn),
        AppRoutes.profile,
      );
    });

    test('the remembered location keeps its query intact', () {
      expect(
        redirect(
          AppRoutes.splashFrom('/boards/42?tab=2&x=y'),
          session: signedIn,
        ),
        '/boards/42?tab=2&x=y',
      );
    });
  });

  group('safety of the from parameter', () {
    String? viaSplash(String? from) {
      final location = from == null
          ? AppRoutes.splash
          : Uri(
              path: AppRoutes.splash,
              queryParameters: <String, String>{AppRoutes.fromParam: from},
            ).toString();
      return redirect(location, session: signedIn);
    }

    test('safe in-app paths are honoured', () {
      expect(viaSplash('/boards'), '/boards');
      expect(viaSplash('/boards/abc'), '/boards/abc');
      expect(viaSplash('/profile'), '/profile');
    });

    final rejected = <String, String?>{
      'absolute https url': 'https://evil.example/phish',
      'absolute http url': 'http://evil.example',
      'scheme-relative': '//evil.example',
      'scheme-relative with path': '//evil.example/boards',
      'javascript scheme': 'javascript:alert(1)',
      'relative path': 'boards/1',
      'empty': '',
      'config': '/config',
      'config with query': '/config?x=1',
      'login': '/login',
      'login with query': '/login?next=/boards',
      'register': '/register',
      'splash': '/splash',
      'splash with nested from': '/splash?from=/boards',
      'null': null,
    };
    for (final entry in rejected.entries) {
      test('${entry.key} falls back to /boards', () {
        expect(viaSplash(entry.value), AppRoutes.boards);
      });
    }

    test('an encoded scheme-relative url is decoded and rejected', () {
      expect(
        redirect('/splash?from=%2F%2Fevil.example', session: signedIn),
        AppRoutes.boards,
      );
    });

    test('an encoded external url is decoded and rejected', () {
      expect(
        redirect('/splash?from=https%3A%2F%2Fevil.example', session: signedIn),
        AppRoutes.boards,
      );
    });

    test('from is ignored while the session is not signed in', () {
      expect(
        redirect(
          AppRoutes.splashFrom('/boards/1'),
          session: const SessionRestoring(),
        ),
        isNull,
      );
      expect(
        redirect(
          AppRoutes.splashFrom('/boards/1'),
          session: const SessionSignedOut(),
        ),
        AppRoutes.login,
      );
    });
  });

  group('AppRoutes', () {
    test('board encodes the id', () {
      expect(AppRoutes.board('42'), '/boards/42');
      expect(AppRoutes.board('a b/c'), '/boards/a%20b%2Fc');
    });

    test('splashFrom round-trips an arbitrary location', () {
      const location = '/boards/42?tab=2&x=y z';
      final uri = Uri.parse(AppRoutes.splashFrom(location));

      expect(uri.path, AppRoutes.splash);
      expect(uri.queryParameters[AppRoutes.fromParam], location);
    });
  });
}
