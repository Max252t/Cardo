import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/boards/presentation/boards_screen.dart';
import 'package:cardo/shared/widgets/avatar_color_picker.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:cardo/theme/cardo_avatar_palette.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String patchKey = 'PATCH /api/me';
const String logoutKey = 'POST /api/auth/logout';

FakeServer serverWithPaletteUser() {
  return FakeServer()
    ..user = userJson(
      displayName: 'Anna',
      avatarColor: CardoAvatarPalette.violet,
    );
}

Future<AppHandle> openProfile(
  WidgetTester tester, {
  FakeServer? server,
  Variant variant = ruPhone,
}) {
  return pumpCardoApp(
    tester,
    server: server ?? serverWithPaletteUser(),
    variant: variant,
    openLocation: '/profile',
  );
}

Finder saveButton(AppHandle app) =>
    find.widgetWithText(CardoPrimaryButton, app.l10n.profileSave);

Finder signOutButton(AppHandle app) =>
    find.widgetWithText(CardoSecondaryButton, app.l10n.profileSignOut);

bool enabled(WidgetTester tester, Finder button) {
  final widget = tester.widget<CardoPrimaryButton>(button);
  return widget.onPressed != null && !widget.busy;
}

List<bool> selection(WidgetTester tester) {
  return tester
      .widgetList<AvatarColorSwatch>(find.byType(AvatarColorSwatch))
      .map((swatch) => swatch.selected)
      .toList();
}

String fieldText(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).controller.text;
}

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('profile renders for $variant', (tester) async {
        final app = await openProfile(tester, variant: variant);

        expect(find.text(variant.l10n.profileTitle), findsOneWidget);
        expect(find.text('anna@example.com'), findsOneWidget);
        expect(app.location, '/profile');
        expect(tester.takeException(), isNull);
      });

      testWidgets('profile dirty with an error renders for $variant', (
        tester,
      ) async {
        final server = serverWithPaletteUser()
          ..on(patchKey, FakeResponse.error(400, 'validation_error'));
        final app = await openProfile(tester, server: server, variant: variant);

        await enterAt(tester, 0, 'Anna B');
        await tester.ensureVisible(saveButton(app));
        await tester.tap(saveButton(app));
        await pumpFrames(tester, 3);

        expect(find.text(variant.l10n.errorValidation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('initial state', () {
    testWidgets('shows the current name, color and email', (tester) async {
      final app = await openProfile(tester);

      expect(fieldText(tester), 'Anna');
      expect(find.text('anna@example.com'), findsOneWidget);
      expect(selection(tester), <bool>[false, false, true, false, false]);
      expect(enabled(tester, saveButton(app)), isFalse);
    });

    testWidgets('the email cannot be edited', (tester) async {
      await openProfile(tester);

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('a color outside the palette selects nothing', (tester) async {
      await openProfile(tester, server: FakeServer());

      expect(selection(tester), everyElement(isFalse));
    });
  });

  group('dirty state and saving', () {
    testWidgets('changing the name enables Save, reverting disables it', (
      tester,
    ) async {
      final app = await openProfile(tester);

      await enterAt(tester, 0, 'Anna B');
      expect(enabled(tester, saveButton(app)), isTrue);

      await enterAt(tester, 0, 'Anna');
      expect(enabled(tester, saveButton(app)), isFalse);
    });

    testWidgets('surrounding spaces alone do not make it dirty', (
      tester,
    ) async {
      final app = await openProfile(tester);

      await enterAt(tester, 0, '  Anna  ');

      expect(enabled(tester, saveButton(app)), isFalse);
    });

    testWidgets('picking another color enables Save', (tester) async {
      final app = await openProfile(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(0));
      await tester.pump();

      expect(selection(tester), <bool>[true, false, false, false, false]);
      expect(enabled(tester, saveButton(app)), isTrue);
    });

    testWidgets('tapping the selected color keeps it selected', (tester) async {
      final app = await openProfile(tester);

      await tester.tap(find.byType(AvatarColorSwatch).at(2));
      await tester.pump();

      expect(selection(tester), <bool>[false, false, true, false, false]);
      expect(enabled(tester, saveButton(app)), isFalse);
    });

    testWidgets('saving the name sends only the name and confirms', (
      tester,
    ) async {
      final server = serverWithPaletteUser();
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, '  Anna B ');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(server.requests(patchKey).single.body, <String, Object?>{
        'display_name': 'Anna B',
      });
      expect(find.text(app.l10n.profileSaved), findsOneWidget);
      expect(enabled(tester, saveButton(app)), isFalse);
      final session = app.container.read(sessionProvider) as SessionSignedIn;
      expect(session.user.displayName, 'Anna B');
    });

    testWidgets('saving the color sends only the color', (tester) async {
      final server = serverWithPaletteUser();
      final app = await openProfile(tester, server: server);

      await tester.tap(find.byType(AvatarColorSwatch).at(3));
      await tester.pump();
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(server.requests(patchKey).single.body, <String, Object?>{
        'avatar_color': CardoAvatarPalette.pink,
      });
      final session = app.container.read(sessionProvider) as SessionSignedIn;
      expect(session.user.avatarColor, CardoAvatarPalette.pink);
    });

    testWidgets('both fields are sent together', (tester) async {
      final server = serverWithPaletteUser();
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, 'Bea');
      await tester.tap(find.byType(AvatarColorSwatch).at(1));
      await tester.pump();
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(server.requests(patchKey).single.body, <String, Object?>{
        'display_name': 'Bea',
        'avatar_color': CardoAvatarPalette.green,
      });
    });

    testWidgets('a blank name is rejected on the client', (tester) async {
      final server = serverWithPaletteUser();
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, '   ');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.fieldNameRequired), findsOneWidget);
      expect(server.count(patchKey), 0);
    });

    testWidgets('the name is capped at 100 characters', (tester) async {
      await openProfile(tester);

      await enterAt(tester, 0, 'x' * 150);

      expect(fieldText(tester).length, 100);
    });

    testWidgets('the submit action on the keyboard saves', (tester) async {
      final server = serverWithPaletteUser();
      await openProfile(tester, server: server);
      await enterAt(tester, 0, 'Via keyboard');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFrames(tester, 3);

      expect(server.count(patchKey), 1);
    });

    testWidgets('the preview avatar shows the typed initial', (tester) async {
      await openProfile(tester);

      await enterAt(tester, 0, 'Yuri');
      await pumpFrames(tester, 2);

      expect(find.text('Y'), findsWidgets);
    });
  });

  group('save failures', () {
    testWidgets('validation_error', (tester) async {
      final server = serverWithPaletteUser()
        ..on(patchKey, FakeResponse.error(400, 'validation_error'));
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, 'Bea');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.errorValidation), findsOneWidget);
      expect(find.text(app.l10n.profileSaved), findsNothing);
      expect(enabled(tester, saveButton(app)), isTrue);
    });

    testWidgets('no connection keeps the edit', (tester) async {
      final server = serverWithPaletteUser()
        ..on(patchKey, FakeResponse.network(DioExceptionType.connectionError));
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, 'Bea');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
      expect(fieldText(tester), 'Bea');
    });

    testWidgets('editing clears the error', (tester) async {
      final server = serverWithPaletteUser()
        ..on(patchKey, FakeResponse.error(500, 'internal'));
      final app = await openProfile(tester, server: server);
      await enterAt(tester, 0, 'Bea');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 3);
      expect(find.text(app.l10n.errorUnknown), findsOneWidget);

      await enterAt(tester, 0, 'Bea 2');

      expect(find.text(app.l10n.errorUnknown), findsNothing);
    });

    testWidgets('while saving the controls are blocked', (tester) async {
      final server = serverWithPaletteUser();
      final gate = server.gate(patchKey);
      final app = await openProfile(tester, server: server);

      await enterAt(tester, 0, 'Bea');
      await tester.tap(saveButton(app));
      await pumpFrames(tester, 2);

      expect(
        tester.widget<CardoPrimaryButton>(find.byType(CardoPrimaryButton)).busy,
        isTrue,
      );
      expect(
        tester.widget<CardoSecondaryButton>(signOutButton(app)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      gate.complete();
      await pumpFrames(tester, 3);

      expect(server.count(patchKey), 1);
    });
  });

  group('sign out', () {
    testWidgets('revokes the refresh token, wipes storage, opens the login', (
      tester,
    ) async {
      final server = serverWithPaletteUser();
      final app = await openProfile(tester, server: server);
      final refreshBefore = app.store.current!.token;

      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      final logout = server.requests(logoutKey).single;
      expect(logout.body['refresh_token'], isNotEmpty);
      expect(logout.body['refresh_token'], refreshBefore);
      expect(logout.authorization, startsWith('Bearer '));
      expect(app.store.current, isNull);
      expect(app.location, '/login');
      expect(app.container.read(sessionProvider), const SessionSignedOut());
      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
    });

    testWidgets('a dead network still signs out locally', (tester) async {
      final server = serverWithPaletteUser()
        ..on(logoutKey, FakeResponse.network(DioExceptionType.connectionError));
      final app = await openProfile(tester, server: server);

      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      expect(app.store.current, isNull);
      expect(app.location, '/login');
    });

    testWidgets('a 500 from the server still signs out locally', (
      tester,
    ) async {
      final server = serverWithPaletteUser()
        ..on(logoutKey, FakeResponse.error(500, 'internal'));
      final app = await openProfile(tester, server: server);

      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      expect(app.store.current, isNull);
      expect(app.location, '/login');
    });

    testWidgets('the button is blocked while the request runs', (tester) async {
      final server = serverWithPaletteUser();
      final gate = server.gate(logoutKey);
      final app = await openProfile(tester, server: server);

      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 2);
      await tester.tap(signOutButton(app), warnIfMissed: false);
      await pumpFrames(tester, 2);

      expect(server.count(logoutKey), 1);
      expect(
        tester.widget<CardoSecondaryButton>(signOutButton(app)).onPressed,
        isNull,
      );

      gate.complete();
      await pumpFrames(tester, 4);

      expect(app.location, '/login');
    });

    testWidgets('after signing out the profile is unreachable', (tester) async {
      final app = await openProfile(tester);
      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      app.router.go('/profile');
      await pumpFrames(tester);

      expect(app.location, '/login');
    });
  });

  group('back', () {
    testWidgets('goes to the boards when there is no history', (tester) async {
      final app = await openProfile(tester);

      await tester.tap(find.byTooltip(app.l10n.profileBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });

    testWidgets('pops when opened from the boards screen', (tester) async {
      final app = await pumpCardoApp(tester, server: serverWithPaletteUser());
      expect(app.location, '/boards');

      await tester.tap(find.byType(ProfileButton));
      await pumpFrames(tester);
      expect(find.text(app.l10n.profileTitle), findsOneWidget);

      await tester.tap(find.byTooltip(app.l10n.profileBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });
  });

  testWidgets('the English labels', (tester) async {
    await openProfile(tester, variant: enPhone);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
