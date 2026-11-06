import 'package:cardo/features/board/presentation/widgets/board_ended_dialog.dart';
import 'package:cardo/features/board_settings/presentation/board_settings_screen.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/api_json.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_server.dart';
import '../../helpers/pump_cardo_app.dart';

const String ownerBoard = '/boards/$boardId1';
const String ownerPath = '/api/boards/$boardId1';
const String renameKey = 'PATCH $ownerPath';
const String deleteKey = 'DELETE $ownerPath';
const String leaveEditorKey = 'DELETE /api/boards/board-2/members/$annaId';
const String leaveViewerKey = 'DELETE /api/boards/board-3/members/$annaId';
const Variant narrowBig = Variant(Locale('ru'), Size(360, 640), 2);

FakeServer ownerServer({int others = 0}) {
  final server = FakeServer();
  if (others > 0) {
    server.on(
      'GET $ownerPath',
      FakeResponse.ok(
        snapshotJson(
          board: boardJson(),
          members: <Map<String, Object?>>[
            memberJson(userId: annaId, displayName: 'Anna', role: 'owner'),
            for (var i = 0; i < others; i++)
              memberJson(userId: 'user-$i', displayName: 'User $i'),
          ],
        ),
      ),
    );
  }
  return server;
}

Future<AppHandle> openSettings(
  WidgetTester tester, {
  FakeServer? server,
  String location = ownerBoard,
  Variant variant = ruPhone,
}) async {
  final app = await pumpCardoApp(
    tester,
    server: server,
    variant: variant,
    openLocation: location,
  );
  await tester.tap(find.byTooltip(app.l10n.boardMenu));
  await pumpFrames(tester, 6);
  return app;
}

void main() {
  group('owner', () {
    testWidgets('opens from the board menu with the current title', (
      tester,
    ) async {
      final app = await openSettings(tester);

      expect(find.byType(BoardSettingsScreen), findsOneWidget);
      expect(find.text(app.l10n.boardSettingsTitle), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Roadmap',
      );
      expect(find.text(app.l10n.boardSettingsDeleteAction), findsOneWidget);
      expect(find.text(app.l10n.boardSettingsLeaveAction), findsNothing);
    });

    testWidgets('renames through PATCH and confirms', (tester) async {
      final server = ownerServer()
        ..on(renameKey, FakeResponse.ok(boardJson(title: 'Launch')));
      final app = await openSettings(tester, server: server);

      await tester.enterText(find.byType(TextFormField), '  Launch  ');
      await tester.tap(find.text(app.l10n.boardSettingsSave));
      await pumpFrames(tester, 3);

      expect(server.requests(renameKey).single.body, <String, Object?>{
        'title': 'Launch',
      });
      expect(find.text(app.l10n.boardSettingsSaved), findsOneWidget);
    });

    testWidgets('an empty or overlong title is not sent', (tester) async {
      final server = ownerServer();
      final app = await openSettings(tester, server: server);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text(app.l10n.boardSettingsSave));
      await tester.pump();
      expect(find.text(app.l10n.newBoardRequired), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'я' * 250);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text.runes.length, 200);
      expect(server.count(renameKey), 0);
    });

    testWidgets('rename 403 shows the forbidden text', (tester) async {
      final server = ownerServer()
        ..on(renameKey, FakeResponse.error(403, 'forbidden'));
      final app = await openSettings(tester, server: server);

      await tester.enterText(find.byType(TextFormField), 'Launch');
      await tester.tap(find.text(app.l10n.boardSettingsSave));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.errorForbidden), findsOneWidget);
      expect(find.text(app.l10n.boardSettingsSaved), findsNothing);
    });

    testWidgets('delete needs confirmation, then leaves to the list', (
      tester,
    ) async {
      final server = ownerServer(others: 2)
        ..on(deleteKey, FakeResponse.empty(204));
      final app = await openSettings(tester, server: server);

      await tester.ensureVisible(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();

      expect(find.text(app.l10n.boardSettingsDeleteTitle), findsOneWidget);
      expect(find.text(app.l10n.boardSettingsDeleteBody(2)), findsOneWidget);
      expect(server.count(deleteKey), 0);

      await tester.tap(find.text(app.l10n.commonCancel));
      await tester.pump();
      expect(find.text(app.l10n.boardSettingsDeleteTitle), findsNothing);

      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();
      await tester.tap(find.text(app.l10n.boardSettingsDeleteConfirm));
      await pumpFrames(tester);

      expect(server.count(deleteKey), 1);
      expect(app.location, '/boards');
      expect(find.byType(BoardEndedDialog), findsNothing);
      expect(find.byType(BoardSettingsScreen), findsNothing);
    });

    testWidgets('delete without other members uses the short warning', (
      tester,
    ) async {
      final app = await openSettings(tester);

      await tester.ensureVisible(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();

      expect(find.text(app.l10n.boardSettingsDeleteAlone), findsOneWidget);
    });

    testWidgets('delete 403 and 503 keep the screen and show the error', (
      tester,
    ) async {
      final server = ownerServer()
        ..on(deleteKey, FakeResponse.error(403, 'forbidden'));
      final app = await openSettings(tester, server: server);

      await tester.ensureVisible(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();
      await tester.tap(find.text(app.l10n.boardSettingsDeleteConfirm));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.errorForbidden), findsOneWidget);
      expect(find.byType(BoardSettingsScreen), findsOneWidget);

      server.on(deleteKey, FakeResponse.error(503, 'busy'));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteConfirm));
      await pumpFrames(tester, 3);
      expect(find.text(app.l10n.errorBusy), findsOneWidget);

      server.on(deleteKey, FakeResponse.error(404, 'not_found'));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteConfirm));
      await pumpFrames(tester, 3);
      expect(find.text(app.l10n.errorNotFound), findsOneWidget);
      expect(app.location, ownerBoard);
    });

    testWidgets('delete is sent once while the request is in flight', (
      tester,
    ) async {
      final server = ownerServer()..on(deleteKey, FakeResponse.empty(204));
      final gate = server.gate(deleteKey);
      final app = await openSettings(tester, server: server);

      await tester.ensureVisible(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();
      await tester.tap(find.text(app.l10n.boardSettingsDeleteConfirm));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await pumpFrames(tester);

      expect(server.count(deleteKey), 1);
      expect(app.location, '/boards');
    });
  });

  group('not the owner', () {
    for (final (location, key, role) in <(String, String, String)>[
      ('/boards/board-2', leaveEditorKey, 'editor'),
      ('/boards/board-3', leaveViewerKey, 'viewer'),
    ]) {
      testWidgets('$role sees leave instead of delete and leaves', (
        tester,
      ) async {
        final server = FakeServer()..on(key, FakeResponse.empty(204));
        final app = await openSettings(
          tester,
          server: server,
          location: location,
        );

        expect(find.byType(TextFormField), findsNothing);
        expect(find.text(app.l10n.boardSettingsDeleteAction), findsNothing);
        expect(find.text(app.l10n.boardSettingsRole), findsOneWidget);

        await tester.ensureVisible(
          find.text(app.l10n.boardSettingsLeaveAction),
        );
        await tester.tap(find.text(app.l10n.boardSettingsLeaveAction));
        await tester.pump();
        expect(find.text(app.l10n.boardSettingsLeaveTitle), findsOneWidget);
        expect(server.count(key), 0);

        await tester.tap(find.text(app.l10n.boardSettingsLeaveConfirm));
        await pumpFrames(tester);

        expect(server.count(key), 1);
        expect(app.location, '/boards');
        expect(find.byType(BoardEndedDialog), findsNothing);
      });
    }

    testWidgets('leave 403 (owner cannot leave) keeps the screen', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(leaveEditorKey, FakeResponse.error(403, 'forbidden'));
      final app = await openSettings(
        tester,
        server: server,
        location: '/boards/board-2',
      );

      await tester.ensureVisible(find.text(app.l10n.boardSettingsLeaveAction));
      await tester.tap(find.text(app.l10n.boardSettingsLeaveAction));
      await tester.pump();
      await tester.tap(find.text(app.l10n.boardSettingsLeaveConfirm));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.errorForbidden), findsOneWidget);
      expect(find.byType(BoardSettingsScreen), findsOneWidget);
      expect(app.location, '/boards/board-2');
    });
  });

  group('layout and language', () {
    testWidgets('owner with confirmation at 360x640 and text scale 2', (
      tester,
    ) async {
      final app = await openSettings(
        tester,
        server: ownerServer(others: 3),
        variant: narrowBig,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.tap(find.text(app.l10n.boardSettingsDeleteAction));
      await tester.pump();
      await tester.ensureVisible(find.byType(FilledButton).last);

      expect(find.text(app.l10n.boardSettingsDeleteTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('member with confirmation at 360x640 and text scale 2', (
      tester,
    ) async {
      final app = await openSettings(
        tester,
        location: '/boards/board-2',
        variant: narrowBig,
      );

      await tester.ensureVisible(find.text(app.l10n.boardSettingsLeaveAction));
      await tester.tap(find.text(app.l10n.boardSettingsLeaveAction));
      await tester.pump();

      expect(find.text(app.l10n.boardSettingsLeaveTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('english copy on the desktop layout', (tester) async {
      final app = await openSettings(tester, variant: enDesktop);

      expect(find.text('Board settings'), findsOneWidget);
      await tester.tap(find.text('Delete board'));
      await tester.pump();
      expect(find.text('Delete this board?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
      expect(find.byType(CardoPrimaryButton), findsOneWidget);
      expect(app.l10n.boardSettingsBack, 'Back to the board');
    });
  });
}
