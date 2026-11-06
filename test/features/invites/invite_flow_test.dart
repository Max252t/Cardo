import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/api_json.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_server.dart';
import '../../helpers/pump_cardo_app.dart';

const String token = 'abcdefghijklmnopqrstuvwxyz012345';
const String acceptKey = 'POST /api/invites/$token/accept';
const String listKey = 'GET /api/boards';
const Variant narrowBig = Variant(Locale('ru'), Size(360, 640), 2);

FakeServer serverAccepting({String role = 'editor'}) {
  return FakeServer()..on(
    acceptKey,
    FakeResponse.ok(boardJson(id: 'board-2', title: 'Design', role: role)),
  );
}

Finder acceptButton(AppHandle app) =>
    find.widgetWithText(CardoPrimaryButton, app.l10n.inviteAccept);

void main() {
  group('signed in', () {
    testWidgets('shows the invite without leaking the token', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: serverAccepting(),
        openLocation: '/invite/$token',
      );

      expect(find.text(app.l10n.inviteHeadline), findsOneWidget);
      expect(find.text(app.l10n.inviteNote), findsOneWidget);
      expect(acceptButton(app), findsOneWidget);
      expect(find.textContaining(token), findsNothing);
      expect(app.server.count(acceptKey), 0);
    });

    testWidgets('accepting opens the board and reloads the list', (
      tester,
    ) async {
      final server = serverAccepting();
      final app = await pumpCardoApp(tester, server: server);
      final loadsBefore = server.count(listKey);
      app.router.go('/invite/$token');
      await pumpFrames(tester);

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(server.count(acceptKey), 1);
      expect(app.location, '/boards/board-2');
      app.router.go('/boards');
      await pumpFrames(tester);
      expect(server.count(listKey), greaterThan(loadsBefore));
    });

    testWidgets('accept sends one request while it is in flight', (
      tester,
    ) async {
      final server = serverAccepting();
      final gate = server.gate(acceptKey);
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await tester.pump();
      await tester.tap(find.byType(CardoPrimaryButton), warnIfMissed: false);
      await tester.pump();

      expect(
        tester.widget<CardoPrimaryButton>(find.byType(CardoPrimaryButton)).busy,
        isTrue,
      );
      gate.complete();
      await pumpFrames(tester);
      expect(server.count(acceptKey), 1);
      expect(app.location, '/boards/board-2');
    });

    testWidgets('an existing member (200) goes straight to the board', (
      tester,
    ) async {
      final server = serverAccepting(role: 'owner');
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(app.location, '/boards/board-2');
    });

    testWidgets('410 invite_unavailable shows the dead-link screen', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(acceptKey, FakeResponse.error(410, 'invite_unavailable'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(find.text(app.l10n.inviteUnavailableTitle), findsOneWidget);
      expect(find.text(app.l10n.inviteUnavailableBody), findsOneWidget);
      expect(acceptButton(app), findsNothing);

      await tester.tap(find.text(app.l10n.inviteToBoards));
      await pumpFrames(tester);
      expect(app.location, '/boards');
    });

    testWidgets('404 shows the not-found screen', (tester) async {
      final server = FakeServer()
        ..on(acceptKey, FakeResponse.error(404, 'not_found'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(find.text(app.l10n.inviteNotFoundTitle), findsOneWidget);
      expect(find.text(app.l10n.inviteNotFoundBody), findsOneWidget);
    });

    testWidgets('a temporary failure keeps the invite and allows a retry', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(acceptKey, FakeResponse.error(503, 'busy'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(find.text(app.l10n.errorBusy), findsOneWidget);
      expect(acceptButton(app), findsOneWidget);

      server.on(
        acceptKey,
        FakeResponse.ok(boardJson(id: 'board-2', role: 'editor')),
      );
      await tester.tap(acceptButton(app));
      await pumpFrames(tester);
      expect(app.location, '/boards/board-2');
    });

    testWidgets('a malformed token never reaches the server', (tester) async {
      final app = await pumpCardoApp(tester, openLocation: '/invite/short');

      expect(find.text(app.l10n.inviteNotFoundTitle), findsOneWidget);
      expect(
        app.server.adapter.requests.where(
          (request) => request.path.startsWith('/api/invites'),
        ),
        isEmpty,
      );
    });

    testWidgets('close returns to the boards', (tester) async {
      final app = await pumpCardoApp(tester, openLocation: '/invite/$token');

      await tester.tap(find.byTooltip(app.l10n.commonClose));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });
  });

  group('signed out', () {
    testWidgets('login first, then back to the invite', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: serverAccepting(),
        signedIn: false,
        openLocation: '/invite/$token',
      );

      expect(app.location, startsWith('/login'));
      expect(find.text(app.l10n.loginTitle), findsOneWidget);

      await enterAt(tester, 0, 'anna@example.com');
      await enterAt(tester, 1, 'secret-pass');
      await tester.tap(find.byType(CardoPrimaryButton));
      await pumpFrames(tester);

      expect(app.location, '/invite/$token');
      expect(find.text(app.l10n.inviteHeadline), findsOneWidget);
    });

    testWidgets('the invite survives the trip through register', (
      tester,
    ) async {
      final app = await pumpCardoApp(
        tester,
        server: serverAccepting(),
        signedIn: false,
        openLocation: '/invite/$token',
      );

      await tester.tap(find.text(app.l10n.loginCreateAccount));
      await pumpFrames(tester);
      expect(app.location, startsWith('/register'));
      expect(app.location, contains('from='));

      await tester.tap(find.byTooltip(app.l10n.registerBack));
      await pumpFrames(tester);
      expect(app.location, startsWith('/login'));
      expect(app.location, contains('from='));
    });
  });

  group('I have a link', () {
    testWidgets('empty list: invalid input shows an error, a link opens', (
      tester,
    ) async {
      final server = serverAccepting()..boards = <Map<String, Object?>>[];
      final app = await pumpCardoApp(tester, server: server);

      await tester.tap(find.text(app.l10n.inviteHaveLink));
      await pumpFrames(tester, 6);
      expect(find.text(app.l10n.inviteLinkTitle), findsOneWidget);

      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await tester.pump();
      expect(find.text(app.l10n.inviteLinkRequired), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'not a link');
      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await tester.pump();
      expect(find.text(app.l10n.inviteLinkInvalid), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField),
        'cardo://invite/$token',
      );
      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await pumpFrames(tester);

      expect(app.location, '/invite/$token');
      expect(find.text(app.l10n.inviteHeadline), findsOneWidget);
    });

    testWidgets('boards list: the header button takes a raw token', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester);

      await tester.tap(find.byTooltip(app.l10n.inviteHaveLink));
      await pumpFrames(tester, 6);
      await tester.enterText(find.byType(TextFormField), token);
      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await pumpFrames(tester);

      expect(app.location, '/invite/$token');
    });

    testWidgets('desktop: opens as a dialog and takes an https link', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, variant: enDesktop);

      await tester.tap(find.byTooltip(app.l10n.inviteHaveLink));
      await pumpFrames(tester, 6);
      expect(find.byType(Dialog), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField),
        'https://cardo.example/invite/$token',
      );
      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await pumpFrames(tester);

      expect(app.location, '/invite/$token');
      expect(find.text(app.l10n.inviteHeadline), findsOneWidget);
    });
  });

  group('layout at 360x640 with text scale 2', () {
    testWidgets('ready, dead link and not found fit', (tester) async {
      final server = FakeServer()
        ..on(acceptKey, FakeResponse.error(410, 'invite_unavailable'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        variant: narrowBig,
        openLocation: '/invite/$token',
      );
      expect(find.text(app.l10n.inviteHeadline), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(acceptButton(app));
      await tester.tap(acceptButton(app));
      await pumpFrames(tester);
      expect(find.text(app.l10n.inviteUnavailableTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      app.router.go('/invite/short');
      await pumpFrames(tester);
      expect(find.text(app.l10n.inviteNotFoundTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the link dialog fits', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: FakeServer()..boards = <Map<String, Object?>>[],
        variant: narrowBig,
      );

      await tester.ensureVisible(find.text(app.l10n.inviteHaveLink));
      await tester.tap(find.text(app.l10n.inviteHaveLink));
      await pumpFrames(tester, 6);
      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.tap(find.text(app.l10n.inviteLinkSubmit));
      await tester.pump();

      expect(find.text(app.l10n.inviteLinkInvalid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('english', () {
    testWidgets('dead-link copy', (tester) async {
      final server = FakeServer()
        ..on(acceptKey, FakeResponse.error(410, 'invite_unavailable'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        variant: enPhone,
        openLocation: '/invite/$token',
      );

      await tester.tap(acceptButton(app));
      await pumpFrames(tester);

      expect(find.text('This link no longer works'), findsOneWidget);
      expect(find.text('To my boards'), findsOneWidget);
    });
  });
}
