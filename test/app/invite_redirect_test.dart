import 'package:cardo/app/app_router.dart';
import 'package:cardo/app/app_routes.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/helpers/fake_auth_api.dart';

const String token = 'abcdefghijklmnopqrstuvwxyz012345';
final String invitePath = AppRoutes.inviteFor(token);

String? redirect(String location, {Session? session}) {
  return resolveRedirect(
    configValid: true,
    session: session,
    location: Uri.parse(location),
    debug: false,
  );
}

String fromOf(String? location) {
  return Uri.parse(location!).queryParameters[AppRoutes.fromParam]!;
}

void main() {
  final Session signedIn = SessionSignedIn(sampleUser());

  group('signed out', () {
    test('an invite goes to login and keeps the invite path in from', () {
      final target = redirect(invitePath, session: const SessionSignedOut());

      expect(Uri.parse(target!).path, AppRoutes.login);
      expect(fromOf(target), invitePath);
    });

    test('other protected paths go to a plain login', () {
      expect(
        redirect('/boards/42', session: const SessionSignedOut()),
        AppRoutes.login,
      );
    });

    test('login and register stay open', () {
      final login = AppRoutes.withFrom(AppRoutes.login, invitePath);
      expect(redirect(login, session: const SessionSignedOut()), isNull);
      expect(
        redirect(AppRoutes.register, session: const SessionSignedOut()),
        isNull,
      );
    });

    test('splash carrying an invite resolves to login with from', () {
      final splash = AppRoutes.splashFrom(invitePath);
      final target = redirect(splash, session: const SessionSignedOut());

      expect(Uri.parse(target!).path, AppRoutes.login);
      expect(fromOf(target), invitePath);
    });

    test('splash carrying a non-invite path drops it', () {
      final splash = AppRoutes.splashFrom('/boards/42');

      expect(
        redirect(splash, session: const SessionSignedOut()),
        AppRoutes.login,
      );
    });

    test('an invite while the session restores goes through splash', () {
      final target = redirect(invitePath);

      expect(Uri.parse(target!).path, AppRoutes.splash);
      expect(fromOf(target), invitePath);
    });
  });

  group('signed in', () {
    test('the invite itself is open', () {
      expect(redirect(invitePath, session: signedIn), isNull);
    });

    test('login with from returns to the invite', () {
      final login = AppRoutes.withFrom(AppRoutes.login, invitePath);

      expect(redirect(login, session: signedIn), invitePath);
    });

    test('register with from returns to the invite', () {
      final register = AppRoutes.withFrom(AppRoutes.register, invitePath);

      expect(redirect(register, session: signedIn), invitePath);
    });

    test('splash with from returns to the invite', () {
      expect(
        redirect(AppRoutes.splashFrom(invitePath), session: signedIn),
        invitePath,
      );
    });

    test('login without from goes to the boards', () {
      expect(redirect(AppRoutes.login, session: signedIn), AppRoutes.boards);
    });

    for (final unsafe in <String>[
      'https://evil.example/invite/$token',
      '//evil.example/invite/$token',
      r'/\evil.example',
      'javascript:alert(1)',
      'invite/$token',
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.splash,
      AppRoutes.config,
      '',
    ]) {
      test('from "$unsafe" is refused', () {
        final login = AppRoutes.withFrom(AppRoutes.login, unsafe);

        expect(redirect(login, session: signedIn), AppRoutes.boards);
      });
    }
  });

  group('route helpers', () {
    test('inviteFor encodes the token as one path segment', () {
      expect(AppRoutes.inviteFor('a/b'), '/invite/a%2Fb');
      expect(AppRoutes.isInvitePath(invitePath), isTrue);
      expect(AppRoutes.isInvitePath('/boards/1'), isFalse);
    });

    test('keepFrom carries from to the next auth route', () {
      final current = Uri.parse(
        AppRoutes.withFrom(AppRoutes.login, invitePath),
      );

      expect(
        fromOf(AppRoutes.keepFrom(AppRoutes.register, current)),
        invitePath,
      );
      expect(
        AppRoutes.keepFrom(AppRoutes.register, Uri.parse(AppRoutes.login)),
        AppRoutes.register,
      );
    });
  });
}
