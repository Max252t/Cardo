import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String loginKey = 'POST /api/auth/login';

Finder submitButton() => find.byType(CardoPrimaryButton);

bool isDisabled(WidgetTester tester, Finder button) {
  return tester.widget<CardoPrimaryButton>(button).onPressed == null ||
      tester.widget<CardoPrimaryButton>(button).busy;
}

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'anna@example.com',
  String password = 'secret-pass',
}) async {
  await enterAt(tester, 0, email);
  await enterAt(tester, 1, password);
  await tester.ensureVisible(submitButton());
  await tester.tap(submitButton());
  await pumpFrames(tester, 3);
}

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('login renders for $variant', (tester) async {
        await pumpCardoApp(tester, variant: variant, signedIn: false);

        expect(find.text(variant.l10n.loginTitle), findsOneWidget);
        expect(find.text(variant.l10n.loginSubmit), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('login with every error renders for $variant', (
        tester,
      ) async {
        final server = FakeServer()
          ..on(
            loginKey,
            FakeResponse.error(
              429,
              'rate_limited',
              headers: <String, String>{'Retry-After': '120'},
            ),
          );
        await pumpCardoApp(
          tester,
          server: server,
          variant: variant,
          signedIn: false,
        );

        await fillAndSubmit(tester);
        await pumpFrames(tester, 3);

        expect(
          find.text(variant.l10n.errorRateLimitedMinutes(2)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('entry', () {
    testWidgets('an app without a stored session opens the login', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      expect(app.location, '/login');
      expect(app.server.adapter.requests, isEmpty);
    });

    testWidgets('the wide layout shows the brand panel and the link', (
      tester,
    ) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        signedIn: false,
      );

      expect(find.text(app.l10n.loginBrandHeadline), findsOneWidget);
      expect(find.text(app.l10n.loginCreateLink), findsOneWidget);
      expect(find.text(app.l10n.loginCreateAccount), findsNothing);
      expect(find.text(app.l10n.loginSubtitleWide), findsOneWidget);
    });

    testWidgets('the compact layout has no brand panel', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      expect(find.text(app.l10n.loginBrandHeadline), findsNothing);
      expect(find.text(app.l10n.loginCreateAccount), findsOneWidget);
      expect(find.text(app.l10n.loginSubtitle), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('empty fields show both errors and send nothing', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      await tester.tap(submitButton());
      await pumpFrames(tester, 2);

      expect(find.text(app.l10n.fieldEmailRequired), findsOneWidget);
      expect(find.text(app.l10n.fieldPasswordRequired), findsOneWidget);
      expect(app.server.count(loginKey), 0);
    });

    testWidgets('a lone password is enough for the client', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      await enterAt(tester, 0, 'someone');
      await enterAt(tester, 1, 'x');
      await tester.tap(submitButton());
      await pumpFrames(tester, 3);

      expect(app.server.count(loginKey), 1);
    });
  });

  group('failures', () {
    testWidgets('401 invalid_credentials is shown under the form', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(401, 'invalid_credentials'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.loginInvalidCredentials), findsOneWidget);
      expect(app.location, '/login');
      expect(isDisabled(tester, submitButton()), isFalse);
    });

    testWidgets('editing a field clears the error', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(401, 'invalid_credentials'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);
      await fillAndSubmit(tester);
      expect(find.text(app.l10n.loginInvalidCredentials), findsOneWidget);

      await enterAt(tester, 1, 'another');

      expect(find.text(app.l10n.loginInvalidCredentials), findsNothing);
    });

    testWidgets('429 with Retry-After in seconds', (tester) async {
      final server = FakeServer()
        ..on(
          loginKey,
          FakeResponse.error(
            429,
            'rate_limited',
            headers: <String, String>{'Retry-After': '30'},
          ),
        );
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorRateLimitedSeconds(30)), findsOneWidget);
    });

    testWidgets('429 with Retry-After over a minute', (tester) async {
      final server = FakeServer()
        ..on(
          loginKey,
          FakeResponse.error(
            429,
            'rate_limited',
            headers: <String, String>{'Retry-After': '90'},
          ),
        );
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorRateLimitedMinutes(2)), findsOneWidget);
    });

    testWidgets('429 without Retry-After uses the generic text', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(429, 'rate_limited'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorRateLimited), findsOneWidget);
    });

    testWidgets('no connection', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.network(DioExceptionType.connectionError));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
    });

    testWidgets('a timeout', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.network(DioExceptionType.receiveTimeout));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorNetworkTimeout), findsOneWidget);
    });

    testWidgets('a server error', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorUnknown), findsOneWidget);
    });

    testWidgets('503 overloaded', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(503, 'overloaded'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);

      expect(find.text(app.l10n.errorBusy), findsOneWidget);
    });

    testWidgets('the same failures read in English', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(401, 'invalid_credentials'));
      await pumpCardoApp(
        tester,
        server: server,
        variant: enPhone,
        signedIn: false,
      );

      await fillAndSubmit(tester);

      expect(find.text('Wrong email or password.'), findsOneWidget);
    });
  });

  group('while the request runs', () {
    testWidgets('the button is blocked, the fields are disabled, one request', (
      tester,
    ) async {
      final server = FakeServer();
      final gate = server.gate(loginKey);
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);
      await tester.tap(submitButton(), warnIfMissed: false);
      await pumpFrames(tester, 2);

      expect(isDisabled(tester, submitButton()), isTrue);
      expect(tester.widget<CardoPrimaryButton>(submitButton()).busy, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(app.l10n.loginSubmit), findsNothing);
      expect(server.count(loginKey), 1);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester
            .widgetList<TextButton>(find.byType(TextButton))
            .every((b) => b.onPressed == null),
        isTrue,
      );

      gate.complete();
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });

    testWidgets('the secondary action is blocked while submitting', (
      tester,
    ) async {
      final server = FakeServer();
      server.gate(loginKey);
      final app = await pumpCardoApp(tester, server: server, signedIn: false);

      await fillAndSubmit(tester);
      await tester.tap(
        find.text(app.l10n.loginCreateAccount),
        warnIfMissed: false,
      );
      await pumpFrames(tester, 3);

      expect(app.location, '/login');
    });

    testWidgets('the button is usable again after a failure', (tester) async {
      final server = FakeServer()
        ..on(loginKey, FakeResponse.error(401, 'invalid_credentials'));
      final app = await pumpCardoApp(tester, server: server, signedIn: false);
      await fillAndSubmit(tester);

      server.clear(loginKey);
      await tester.tap(submitButton());
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(server.count(loginKey), 2);
    });
  });

  group('password visibility', () {
    bool obscured(WidgetTester tester) {
      return tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .obscureText;
    }

    testWidgets('is hidden by default and can be toggled both ways', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, signedIn: false);
      expect(obscured(tester), isTrue);
      expect(find.byTooltip(app.l10n.authShowPassword), findsOneWidget);

      await tester.tap(find.byTooltip(app.l10n.authShowPassword));
      await tester.pump();

      expect(obscured(tester), isFalse);
      expect(find.byTooltip(app.l10n.authHidePassword), findsOneWidget);

      await tester.tap(find.byTooltip(app.l10n.authHidePassword));
      await tester.pump();

      expect(obscured(tester), isTrue);
    });

    testWidgets('toggling keeps what was typed', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);
      await enterAt(tester, 1, 'hunter2hunter2');

      await tester.tap(find.byTooltip(app.l10n.authShowPassword));
      await tester.pump();

      expect(find.text('hunter2hunter2'), findsOneWidget);
    });
  });

  group('sign-out banner', () {
    testWidgets('an expired session explains itself', (tester) async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_expired'),
        );
      final app = await pumpCardoApp(tester, server: server);

      expect(app.location, '/login');
      expect(find.text(app.l10n.errorSessionExpired), findsOneWidget);
    });

    testWidgets('a reused token shows the security message', (tester) async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_reused'),
        );
      final app = await pumpCardoApp(tester, server: server);

      expect(app.location, '/login');
      expect(find.text(app.l10n.errorSessionReused), findsOneWidget);
      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
    });

    testWidgets('the English texts', (tester) async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_reused'),
        );
      await pumpCardoApp(tester, server: server, variant: enPhone);

      expect(
        find.text('We ended all sessions for security reasons. Sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('a plain first start shows no banner', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
      expect(find.text(app.l10n.errorSessionReused), findsNothing);
    });

    testWidgets('the stored credential is wiped when the session ends', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_reused'),
        );
      final app = await pumpCardoApp(tester, server: server);

      expect(app.store.current, isNull);
    });

    testWidgets('the banner survives wide layout as well', (tester) async {
      final server = FakeServer()
        ..on(
          'POST ${ApiPaths.refresh}',
          FakeResponse.error(401, 'token_expired'),
        );
      final app = await pumpCardoApp(
        tester,
        server: server,
        variant: ruDesktop,
      );

      expect(find.text(app.l10n.errorSessionExpired), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the create-account button leads to the registration', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      await tester.tap(find.text(app.l10n.loginCreateAccount));
      await pumpFrames(tester);

      expect(app.location, '/register');
      expect(find.text(app.l10n.registerTitle), findsWidgets);
    });

    testWidgets('the wide link leads to the registration', (tester) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        signedIn: false,
      );

      await tester.tap(find.text(app.l10n.loginCreateLink));
      await pumpFrames(tester);

      expect(app.location, '/register');
    });
  });

  group('success', () {
    testWidgets(
      'sends trimmed email, keeps the password, stores the refresh token',
      (tester) async {
        final app = await pumpCardoApp(tester, signedIn: false);

        await fillAndSubmit(
          tester,
          email: '  anna@example.com ',
          password: ' pass word ',
        );
        await pumpFrames(tester);

        final request = app.server.requests(loginKey).single;
        expect(request.body, <String, Object?>{
          'email': 'anna@example.com',
          'password': ' pass word ',
        });
        expect(request.authorization, isNull);
        expect(app.store.current?.token, 'refresh-1');
        expect(app.location, '/boards');
        expect(app.container.read(sessionProvider), isA<SessionSignedIn>());
      },
    );

    testWidgets('the done action on the keyboard submits', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);
      await enterAt(tester, 0, 'anna@example.com');
      await enterAt(tester, 1, 'secret-pass');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFrames(tester);

      expect(app.server.count(loginKey), 1);
      expect(app.location, '/boards');
    });

    testWidgets('after a login the login route is not reachable', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, signedIn: false);
      await fillAndSubmit(tester);
      await pumpFrames(tester);

      app.router.go('/login');
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });
  });
}
