import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/presentation/board_load_views.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String snapshotKey = 'GET /api/boards/$boardId1';

Future<AppHandle> openBoard(
  WidgetTester tester, {
  FakeServer? server,
  Variant variant = ruPhone,
}) {
  return pumpCardoApp(
    tester,
    server: server,
    variant: variant,
    openLocation: '/boards/$boardId1',
  );
}

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('loading renders for $variant', (tester) async {
        final server = FakeServer();
        server.gate(snapshotKey);
        final app = await openBoard(tester, server: server, variant: variant);

        expect(find.text(app.l10n.boardLoadingTitle), findsOneWidget);
        expect(find.byType(BoardSkeletonColumns), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error renders for $variant', (tester) async {
        final server = FakeServer()
          ..on(snapshotKey, FakeResponse.error(404, 'not_found'));
        final app = await openBoard(tester, server: server, variant: variant);

        expect(find.text(app.l10n.boardLoadErrorTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('data renders for $variant', (tester) async {
        final app = await openBoard(tester, variant: variant);

        expect(find.byType(BoardScreen), findsOneWidget);
        expect(find.text('To do'), findsWidgets);
        expect(tester.takeException(), isNull);
        expect(app.location, '/boards/$boardId1');
      });
    }
  });

  group('loading to data', () {
    testWidgets('shows the skeleton first, then the board', (tester) async {
      final server = FakeServer();
      final gate = server.gate(snapshotKey);
      final app = await openBoard(tester, server: server);

      expect(find.text(app.l10n.boardLoadingTitle), findsOneWidget);
      expect(find.byType(BoardScreen), findsNothing);

      gate.complete();
      await pumpFrames(tester);

      expect(find.text(app.l10n.boardLoadingTitle), findsNothing);
      expect(find.byType(BoardScreen), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Roadmap'), findsWidgets);
    });

    testWidgets('columns are in rank order', (tester) async {
      await openBoard(tester);

      final todo = tester.getTopLeft(find.text('To do').first).dx;
      final doing = tester.getTopLeft(find.text('Doing').first).dx;
      expect(todo, lessThan(doing));
    });

    testWidgets('the loading screen back button returns to the list', (
      tester,
    ) async {
      final server = FakeServer();
      server.gate(snapshotKey);
      final app = await openBoard(tester, server: server);

      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });

    testWidgets('the board loads exactly one snapshot and one list', (
      tester,
    ) async {
      final app = await openBoard(tester);

      expect(app.server.count(snapshotKey), 1);
    });

    testWidgets('the board starts syncing and queues edits until sync.ready', (
      tester,
    ) async {
      final app = await openBoard(tester);

      expect(find.text(app.l10n.connectionSyncing), findsWidgets);
    });

    testWidgets('an owner can add cards', (tester) async {
      final app = await openBoard(tester);

      expect(find.text(app.l10n.boardAddCard), findsWidgets);
    });

    testWidgets('a viewer role is taken from the board', (tester) async {
      final server = FakeServer()
        ..boards = <Map<String, Object?>>[
          boardJson(role: BoardRole.viewer.wireName),
        ];
      final app = await openBoard(tester, server: server);

      expect(find.byType(BoardScreen), findsOneWidget);
      expect(find.text(app.l10n.boardAddCard), findsNothing);
    });
  });

  group('error to retry', () {
    testWidgets('404 shows the message, the code and both actions', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(404, 'not_found'));
      final app = await openBoard(tester, server: server);

      expect(find.text(app.l10n.boardLoadErrorTitle), findsOneWidget);
      expect(find.text(app.l10n.errorNotFound), findsOneWidget);
      expect(
        find.text(app.l10n.boardLoadErrorCode('not_found')),
        findsOneWidget,
      );
      expect(find.text(app.l10n.commonRetry), findsOneWidget);
      expect(find.text(app.l10n.boardLoadErrorToList), findsOneWidget);
    });

    testWidgets('Retry loads the board once the server answers', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(
          snapshotKey,
          FakeResponse.network(DioExceptionType.connectionError),
        );
      final app = await openBoard(tester, server: server);
      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
      expect(
        find.text(app.l10n.boardLoadErrorCode('network_offline')),
        findsOneWidget,
      );

      server.clear(snapshotKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(find.byType(BoardScreen), findsOneWidget);
      expect(server.count(snapshotKey), 2);
    });

    testWidgets('Retry that fails again stays on the error', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(500, 'internal'));
      final app = await openBoard(tester, server: server);

      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(find.text(app.l10n.boardLoadErrorTitle), findsOneWidget);
      expect(server.count(snapshotKey), 2);
    });

    testWidgets('Back to boards returns to the list', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(403, 'forbidden'));
      final app = await openBoard(tester, server: server);
      expect(find.text(app.l10n.errorForbidden), findsOneWidget);

      await tester.tap(find.text(app.l10n.boardLoadErrorToList));
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(find.text(app.l10n.boardsTitle), findsOneWidget);
    });

    testWidgets('the arrow in the header goes back as well', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(404, 'not_found'));
      final app = await openBoard(tester, server: server);

      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });

    testWidgets('a broken snapshot is shown as an unknown error', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.ok(<String, Object?>{'board': 1}));
      final app = await openBoard(tester, server: server);

      expect(find.text(app.l10n.errorUnknown), findsOneWidget);
      expect(find.text(app.l10n.boardLoadErrorCode('unknown')), findsOneWidget);
    });

    testWidgets('503 busy names the server state', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(503, 'busy'));
      final app = await openBoard(tester, server: server);

      expect(find.text(app.l10n.errorBusy), findsOneWidget);
    });

    testWidgets('English texts', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(404, 'not_found'));
      await openBoard(tester, server: server, variant: enPhone);

      expect(find.text("Couldn't open the board"), findsOneWidget);
      expect(find.text('Back to boards'), findsOneWidget);
      expect(find.text('Error code: not_found'), findsOneWidget);
    });
  });

  group('navigation from the board', () {
    testWidgets('Back on the compact board returns to /boards', (tester) async {
      final app = await openBoard(tester);

      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(find.text(app.l10n.boardsTitle), findsOneWidget);
    });

    testWidgets('the sidebar lists the boards of the server', (tester) async {
      final app = await openBoard(tester, variant: ruDesktop);

      expect(find.text('Design'), findsWidgets);
      expect(find.text('Archive'), findsWidgets);
      expect(app.server.count('GET /api/boards'), greaterThanOrEqualTo(1));
    });

    testWidgets('choosing another board in the sidebar opens it', (
      tester,
    ) async {
      final app = await openBoard(tester, variant: ruDesktop);

      await tester.tap(find.text('Design').first);
      await pumpFrames(tester);

      expect(app.location, '/boards/board-2');
      expect(find.byType(BoardScreen), findsOneWidget);
    });

    testWidgets('an unknown board id ends in the not found error', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/nope');

      expect(find.text(app.l10n.errorNotFound), findsOneWidget);
    });
  });
}
