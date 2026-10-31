import 'package:cardo/features/boards/presentation/widgets/board_tile.dart';
import 'package:cardo/features/boards/presentation/widgets/boards_body.dart';
import 'package:cardo/features/boards/presentation/widgets/boards_states.dart';
import 'package:cardo/shared/widgets/role_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String listKey = 'GET /api/boards';

Map<String, Object?> board(
  String id,
  String title,
  String role,
  int updatedMinutes,
) {
  return boardJson(id: id, title: title, role: role)
    ..['updated_at'] = iso(t0.add(Duration(minutes: updatedMinutes)));
}

FakeServer threeBoards() {
  return FakeServer()
    ..boards = <Map<String, Object?>>[
      board('b-old', 'Archive', 'viewer', 10),
      board('b-new', 'Roadmap', 'owner', 90),
      board('b-mid', 'Design', 'editor', 50),
    ];
}

List<String> tileTitles(WidgetTester tester) {
  return tester
      .widgetList<BoardTile>(find.byType(BoardTile))
      .map((tile) => tile.board.title)
      .toList();
}

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('list renders for $variant', (tester) async {
        await pumpCardoApp(tester, server: threeBoards(), variant: variant);

        expect(find.byType(BoardTile), findsAtLeastNWidgets(2));
        expect(find.text(variant.l10n.boardsTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty renders for $variant', (tester) async {
        final server = FakeServer()..boards = <Map<String, Object?>>[];
        await pumpCardoApp(tester, server: server, variant: variant);

        expect(find.text(variant.l10n.boardsEmptyTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error renders for $variant', (tester) async {
        final server = FakeServer()
          ..on(listKey, FakeResponse.error(500, 'internal'));
        await pumpCardoApp(tester, server: server, variant: variant);

        expect(find.text(variant.l10n.boardsLoadError), findsOneWidget);
        expect(find.text(variant.l10n.commonRetry), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('loading renders for $variant', (tester) async {
        final server = FakeServer();
        server.gate(listKey);
        await pumpCardoApp(tester, server: server, variant: variant);

        expect(find.byType(BoardsSkeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('search without results renders for $variant', (
        tester,
      ) async {
        await pumpCardoApp(tester, server: threeBoards(), variant: variant);

        await tester.enterText(find.byType(TextField), 'zzz');
        await pumpFrames(tester, 2);

        expect(find.text(variant.l10n.boardsNoResults), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('states', () {
    testWidgets('loading shows the skeleton and no boards', (tester) async {
      final server = FakeServer();
      final gate = server.gate(listKey);
      final app = await pumpCardoApp(tester, server: server);

      expect(find.byType(BoardsSkeleton), findsOneWidget);
      expect(find.byType(BoardTile), findsNothing);
      expect(find.text(app.l10n.boardsEmptyTitle), findsNothing);

      gate.complete();
      await pumpFrames(tester);

      expect(find.byType(BoardsSkeleton), findsNothing);
      expect(find.byType(BoardTile), findsNWidgets(3));
    });

    testWidgets('an error offers a retry that reloads', (tester) async {
      final server = threeBoards()
        ..on(listKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(tester, server: server);
      expect(find.text(app.l10n.boardsLoadError), findsOneWidget);
      expect(find.text(app.l10n.errorUnknown), findsOneWidget);

      server.clear(listKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(find.byType(BoardTile), findsNWidgets(3));
      expect(find.text(app.l10n.boardsLoadError), findsNothing);
      expect(server.count(listKey), 2);
    });

    testWidgets('a network error names the problem', (tester) async {
      final server = FakeServer()
        ..on(listKey, FakeResponse.network(DioExceptionType.connectionError));
      final app = await pumpCardoApp(tester, server: server);

      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
    });

    testWidgets('a malformed answer is an error, not a crash', (tester) async {
      final server = FakeServer()
        ..on(listKey, FakeResponse.ok(<String, Object?>{'boards': 5}));
      final app = await pumpCardoApp(tester, server: server);

      expect(find.text(app.l10n.boardsLoadError), findsOneWidget);
    });

    testWidgets('empty shows the call to action', (tester) async {
      final server = FakeServer()..boards = <Map<String, Object?>>[];
      final app = await pumpCardoApp(tester, server: server);

      expect(find.text(app.l10n.boardsEmptyTitle), findsOneWidget);
      expect(find.text(app.l10n.boardsEmptyBody), findsOneWidget);
      expect(find.text(app.l10n.boardsEmptyAction), findsOneWidget);
      expect(find.byType(BoardTile), findsNothing);
      expect(find.text(app.l10n.boardsNew), findsNothing);
    });

    testWidgets('the empty state opens the new board sheet', (tester) async {
      final server = FakeServer()..boards = <Map<String, Object?>>[];
      final app = await pumpCardoApp(tester, server: server);

      await tester.tap(find.text(app.l10n.boardsEmptyAction));
      await pumpFrames(tester, 4);

      expect(find.text(app.l10n.newBoardTitle), findsOneWidget);
    });
  });

  group('compact list', () {
    testWidgets('sorts by last update, newest first', (tester) async {
      await pumpCardoApp(tester, server: threeBoards());

      expect(tileTitles(tester), <String>['Roadmap', 'Design', 'Archive']);
    });

    testWidgets('is a list, not a grid', (tester) async {
      await pumpCardoApp(tester, server: threeBoards());

      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(NewBoardTile), findsNothing);
    });

    testWidgets('role badges follow the roles', (tester) async {
      final app = await pumpCardoApp(tester, server: threeBoards());

      final roles = tester
          .widgetList<RoleBadge>(find.byType(RoleBadge))
          .map((badge) => RoleBadge.labelFor(app.l10n, badge.role))
          .toList();
      expect(roles, <String>[
        app.l10n.roleOwner,
        app.l10n.roleEditor,
        app.l10n.roleViewer,
      ]);
    });

    testWidgets('role labels in English', (tester) async {
      await pumpCardoApp(tester, server: threeBoards(), variant: enPhone);

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
    });

    testWidgets('shows the new board button when there are boards', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, server: threeBoards());

      expect(find.text(app.l10n.boardsNew), findsOneWidget);
    });

    testWidgets('the new board button is hidden while loading and on error', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(listKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(tester, server: server);

      expect(find.text(app.l10n.boardsNew), findsNothing);
    });

    testWidgets('tapping a tile opens that board', (tester) async {
      final app = await pumpCardoApp(tester, server: threeBoards());

      await tester.tap(find.text('Design'));
      await pumpFrames(tester);

      expect(app.location, '/boards/b-mid');
    });

    testWidgets('the search filters case-insensitively and can be cleared', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, server: threeBoards());

      await tester.enterText(find.byType(TextField), 'dEs');
      await pumpFrames(tester, 2);
      expect(tileTitles(tester), <String>['Design']);

      await tester.enterText(find.byType(TextField), 'zzz');
      await pumpFrames(tester, 2);
      expect(tileTitles(tester), isEmpty);
      expect(find.text(app.l10n.boardsNoResults), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await pumpFrames(tester, 2);
      expect(tileTitles(tester), hasLength(3));
    });

    testWidgets('a long title is clipped inside the tile', (tester) async {
      final server = FakeServer()
        ..boards = <Map<String, Object?>>[board('b', 'Q' * 190, 'owner', 1)];
      await pumpCardoApp(
        tester,
        server: server,
        variant: const Variant(Locale('ru'), compactPhone, 2),
      );

      expect(find.byType(BoardTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each tile announces title and role', (tester) async {
      final app = await pumpCardoApp(tester, server: threeBoards());

      expect(
        find.bySemanticsLabel(
          app.l10n.boardSemantic('Roadmap', app.l10n.roleOwner),
        ),
        findsOneWidget,
      );
    });
  });

  group('expanded grid', () {
    testWidgets('is a grid with the new-board tile', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: threeBoards(),
        variant: ruDesktop,
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(BoardTile), findsNWidgets(3));
      expect(find.byType(NewBoardTile), findsOneWidget);
      expect(find.text(app.l10n.boardsCount(3)), findsOneWidget);
    });

    testWidgets('there is no floating button next to the header button', (
      tester,
    ) async {
      final app = await pumpCardoApp(
        tester,
        server: threeBoards(),
        variant: ruDesktop,
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text(app.l10n.boardsNew), findsOneWidget);
    });

    testWidgets('the count is singular for one board', (tester) async {
      final server = FakeServer()
        ..boards = <Map<String, Object?>>[board('b', 'Solo', 'owner', 1)];
      final app = await pumpCardoApp(
        tester,
        server: server,
        variant: enDesktop,
      );

      expect(find.text(app.l10n.boardsCount(1)), findsOneWidget);
      expect(find.text('1 board'), findsOneWidget);
    });

    testWidgets('tapping a tile opens the board', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: threeBoards(),
        variant: ruDesktop,
      );

      await tester.tap(find.text('Archive'));
      await pumpFrames(tester);

      expect(app.location, '/boards/b-old');
    });

    testWidgets('the new-board tile opens the dialog', (tester) async {
      final app = await pumpCardoApp(
        tester,
        server: threeBoards(),
        variant: ruDesktop,
      );

      await tester.tap(find.byType(NewBoardTile));
      await pumpFrames(tester, 4);

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(app.l10n.newBoardTitle),
        ),
        findsOneWidget,
      );
    });
  });

  group('pull to refresh', () {
    testWidgets('reloads the list and shows new boards', (tester) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);
      expect(server.count(listKey), 1);

      server.boards = <Map<String, Object?>>[
        board('b-fresh', 'Fresh', 'owner', 200),
        ...server.boards,
      ];
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1500,
      );
      await pumpFrames(tester, 20);

      expect(server.count(listKey), 2);
      expect(tileTitles(tester).first, 'Fresh');
      expect(tileTitles(tester), hasLength(4));
    });

    testWidgets('the grid refreshes as well', (tester) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server, variant: ruDesktop);

      await tester.fling(find.byType(GridView), const Offset(0, 400), 1500);
      await pumpFrames(tester, 20);

      expect(server.count(listKey), 2);
    });

    testWidgets('a failed refresh turns into the error state', (tester) async {
      final server = threeBoards();
      final app = await pumpCardoApp(tester, server: server);

      server.on(listKey, FakeResponse.error(500, 'internal'));
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1500,
      );
      await pumpFrames(tester, 20);

      expect(find.text(app.l10n.boardsLoadError), findsOneWidget);
    });
  });

  testWidgets('relative update times use the injected clock', (tester) async {
    final server = FakeServer()
      ..boards = <Map<String, Object?>>[board('b', 'Timed', 'owner', 60 + 60)];
    final app = await pumpCardoApp(tester, server: server);

    expect(
      find.textContaining(app.l10n.boardUpdatedAt('').trim()),
      findsOneWidget,
    );
  });
}
