import 'package:cardo/features/auth/domain/auth_validation.dart';
import 'package:cardo/shared/widgets/avatar_color_picker.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:cardo/theme/cardo_avatar_palette.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String registerKey = 'POST /api/auth/register';

Finder submitButton() => find.byType(CardoPrimaryButton);

List<bool> selection(WidgetTester tester) {
  return tester
      .widgetList<AvatarColorSwatch>(find.byType(AvatarColorSwatch))
      .map((swatch) => swatch.selected)
      .toList();
}

Future<void> fill(
  WidgetTester tester, {
  String name = 'Anna',
  String email = 'anna@example.com',
  String password = 'secret-pass',
}) async {
  await enterAt(tester, 0, name);
  await enterAt(tester, 1, email);
  await enterAt(tester, 2, password);
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(submitButton());
  await tester.tap(submitButton());
  await pumpFrames(tester, 3);
}

Future<AppHandle> openRegister(
  WidgetTester tester, {
  FakeServer? server,
  Variant variant = ruPhone,
}) {
  return pumpCardoApp(
    tester,
    server: server,
    variant: variant,
    signedIn: false,
    openLocation: '/register',
  );
}

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('register renders for $variant', (tester) async {
        await openRegister(tester, variant: variant);

        expect(find.text(variant.l10n.registerTitle), findsWidgets);
        expect(find.byType(TextFormField), findsNWidgets(3));
        expect(find.byType(AvatarColorSwatch), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('register with validation errors renders for $variant', (
        tester,
      ) async {
        await openRegister(tester, variant: variant);

        await tester.ensureVisible(submitButton());
        await tester.tap(submitButton());
        await pumpFrames(tester, 3);

        expect(find.text(variant.l10n.fieldNameRequired), findsOneWidget);
        expect(find.text(variant.l10n.fieldEmailRequired), findsOneWidget);
        expect(find.text(variant.l10n.fieldPasswordRequired), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('register with a server error renders for $variant', (
        tester,
      ) async {
        final server = FakeServer()
          ..on(registerKey, FakeResponse.error(409, 'email_taken'));
        await openRegister(tester, server: server, variant: variant);

        await fill(tester);
        await submit(tester);

        expect(find.text(variant.l10n.registerEmailTaken), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('validation', () {
    testWidgets('all three fields are required', (tester) async {
      final app = await openRegister(tester);

      await submit(tester);

      expect(find.text(app.l10n.fieldNameRequired), findsOneWidget);
      expect(find.text(app.l10n.fieldEmailRequired), findsOneWidget);
      expect(find.text(app.l10n.fieldPasswordRequired), findsOneWidget);
      expect(app.server.count(registerKey), 0);
    });

    testWidgets('a blank name is rejected', (tester) async {
      final app = await openRegister(tester);

      await fill(tester, name: '    ');
      await submit(tester);

      expect(find.text(app.l10n.fieldNameRequired), findsOneWidget);
      expect(app.server.count(registerKey), 0);
    });

    testWidgets('a malformed email is rejected', (tester) async {
      final app = await openRegister(tester);

      await fill(tester, email: 'not-an-email');
      await submit(tester);

      expect(find.text(app.l10n.fieldEmailInvalid), findsOneWidget);
      expect(app.server.count(registerKey), 0);
    });

    testWidgets('a 7 character password is too short', (tester) async {
      final app = await openRegister(tester);

      await fill(tester, password: 'a' * 7);
      await submit(tester);

      expect(
        find.text(app.l10n.fieldPasswordTooShort(AuthLimits.passwordMin)),
        findsOneWidget,
      );
      expect(app.server.count(registerKey), 0);
    });

    testWidgets('an 8 character password passes', (tester) async {
      final app = await openRegister(tester);

      await fill(tester, password: 'a' * 8);
      await submit(tester);

      expect(app.server.count(registerKey), 1);
    });

    testWidgets('typing is capped at the name and password limits', (
      tester,
    ) async {
      await openRegister(tester);

      await enterAt(tester, 0, 'n' * 150);
      await enterAt(tester, 2, 'p' * 200);

      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields[0].controller.text.length, AuthLimits.nameMax);
      expect(fields[2].controller.text.length, AuthLimits.passwordMax);
    });

    testWidgets('the error appears as soon as the user leaves a bad value', (
      tester,
    ) async {
      final app = await openRegister(tester);

      await enterAt(tester, 1, 'x');
      await pumpFrames(tester, 2);

      expect(find.text(app.l10n.fieldEmailInvalid), findsOneWidget);
    });

    testWidgets('English validation texts', (tester) async {
      await openRegister(tester, variant: enPhone);

      await fill(tester, name: '', email: 'bad', password: 'short');
      await submit(tester);

      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Check the email address'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
    });
  });

  group('avatar color', () {
    testWidgets('nothing is selected at first', (tester) async {
      await openRegister(tester);

      expect(selection(tester), <bool>[false, false, false, false, false]);
    });

    testWidgets('tapping selects exactly one swatch', (tester) async {
      await openRegister(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(1));
      await tester.pump();
      expect(selection(tester), <bool>[false, true, false, false, false]);

      await tester.tap(find.byType(AvatarColorSwatch).at(3));
      await tester.pump();
      expect(selection(tester), <bool>[false, false, false, true, false]);
    });

    testWidgets('tapping the selected swatch clears the choice', (
      tester,
    ) async {
      await openRegister(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(2));
      await tester.pump();
      await tester.tap(find.byType(AvatarColorSwatch).at(2));
      await tester.pump();

      expect(selection(tester), <bool>[false, false, false, false, false]);
    });

    testWidgets('the chosen color goes to the server', (tester) async {
      final app = await openRegister(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(1));
      await tester.pump();
      await fill(tester);
      await submit(tester);

      expect(
        app.server.requests(registerKey).single.body['avatar_color'],
        CardoAvatarPalette.green,
      );
    });

    testWidgets('without a choice avatar_color is omitted', (tester) async {
      final app = await openRegister(tester);

      await fill(tester);
      await submit(tester);

      expect(
        app.server
            .requests(registerKey)
            .single
            .body
            .containsKey('avatar_color'),
        isFalse,
      );
    });

    testWidgets('a choice that was cleared is not sent', (tester) async {
      final app = await openRegister(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(0));
      await tester.pump();
      await tester.tap(find.byType(AvatarColorSwatch).at(0));
      await tester.pump();
      await fill(tester);
      await submit(tester);

      expect(
        app.server
            .requests(registerKey)
            .single
            .body
            .containsKey('avatar_color'),
        isFalse,
      );
    });

    testWidgets('swatches carry localized names', (tester) async {
      final app = await openRegister(tester, variant: enPhone);

      expect(find.bySemanticsLabel(app.l10n.avatarColorViolet), findsOneWidget);
      expect(find.text(app.l10n.avatarColorOptional), findsOneWidget);
    });
  });

  group('server answers', () {
    testWidgets('409 email_taken keeps the form and shows the message', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(registerKey, FakeResponse.error(409, 'email_taken'));
      final app = await openRegister(tester, server: server);

      await fill(tester);
      await submit(tester);

      expect(find.text(app.l10n.registerEmailTaken), findsOneWidget);
      expect(app.location, '/register');
      expect(find.text('anna@example.com'), findsOneWidget);
      expect(app.store.current, isNull);
    });

    testWidgets('editing after email_taken clears the message', (tester) async {
      final server = FakeServer()
        ..on(registerKey, FakeResponse.error(409, 'email_taken'));
      final app = await openRegister(tester, server: server);
      await fill(tester);
      await submit(tester);

      await enterAt(tester, 1, 'other@example.com');

      expect(find.text(app.l10n.registerEmailTaken), findsNothing);
    });

    testWidgets('400 validation_error', (tester) async {
      final server = FakeServer()
        ..on(registerKey, FakeResponse.error(400, 'validation_error'));
      final app = await openRegister(tester, server: server);

      await fill(tester);
      await submit(tester);

      expect(find.text(app.l10n.errorValidation), findsOneWidget);
    });

    testWidgets('429 with Retry-After', (tester) async {
      final server = FakeServer()
        ..on(
          registerKey,
          FakeResponse.error(
            429,
            'rate_limited',
            headers: <String, String>{'Retry-After': '15'},
          ),
        );
      final app = await openRegister(tester, server: server);

      await fill(tester);
      await submit(tester);

      expect(find.text(app.l10n.errorRateLimitedSeconds(15)), findsOneWidget);
    });

    testWidgets('no connection', (tester) async {
      final server = FakeServer()
        ..on(
          registerKey,
          FakeResponse.network(DioExceptionType.connectionError),
        );
      final app = await openRegister(tester, server: server);

      await fill(tester);
      await submit(tester);

      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
    });

    testWidgets('while sending the button and picker are blocked', (
      tester,
    ) async {
      final server = FakeServer();
      final gate = server.gate(registerKey);
      final app = await openRegister(tester, server: server);

      await fill(tester);
      await submit(tester);
      await tester.tap(submitButton(), warnIfMissed: false);
      await tester.tap(
        find.byType(AvatarColorSwatch).at(0),
        warnIfMissed: false,
      );
      await pumpFrames(tester, 2);

      expect(tester.widget<CardoPrimaryButton>(submitButton()).busy, isTrue);
      expect(server.count(registerKey), 1);
      expect(selection(tester), everyElement(isFalse));

      gate.complete();
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });

    testWidgets('success trims the input and signs in', (tester) async {
      final app = await openRegister(tester);

      await fill(
        tester,
        name: '  Anna K  ',
        email: ' new@example.com ',
        password: ' my password ',
      );
      await submit(tester);
      await pumpFrames(tester);

      final body = app.server.requests(registerKey).single.body;
      expect(body['display_name'], 'Anna K');
      expect(body['email'], 'new@example.com');
      expect(body['password'], ' my password ');
      expect(app.location, '/boards');
      expect(app.store.current?.token, 'refresh-1');
    });

    testWidgets('success lands on the boards of the new user', (tester) async {
      final app = await openRegister(tester);

      await fill(tester);
      await submit(tester);
      await pumpFrames(tester);

      expect(find.text(app.l10n.boardsTitle), findsWidgets);
    });
  });

  group('navigation and controls', () {
    testWidgets('the sign-in link goes back to the login', (tester) async {
      final app = await openRegister(tester);

      await tester.ensureVisible(find.text(app.l10n.registerSignIn));
      await tester.tap(find.text(app.l10n.registerSignIn));
      await pumpFrames(tester);

      expect(app.location, '/login');
    });

    testWidgets('the password can be revealed and hidden', (tester) async {
      final app = await openRegister(tester);
      bool obscured() => tester
          .widget<EditableText>(find.byType(EditableText).at(2))
          .obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip(app.l10n.authShowPassword));
      await tester.pump();
      expect(obscured(), isFalse);
      await tester.tap(find.byTooltip(app.l10n.authHidePassword));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('the preview avatar follows the typed name', (tester) async {
      await openRegister(tester);

      await enterAt(tester, 0, 'Zed');
      await pumpFrames(tester, 2);

      expect(find.text('Z'), findsWidgets);
    });

    testWidgets('the submit action on the password field sends the form', (
      tester,
    ) async {
      final app = await openRegister(tester);
      await fill(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFrames(tester);

      expect(app.server.count(registerKey), 1);
    });
  });
}
