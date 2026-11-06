import 'package:cardo/features/boards/presentation/widgets/boards_body.dart';
import 'package:cardo/features/boards/presentation/widgets/boards_refresh_button.dart';
import 'package:cardo/features/boards/presentation/widgets/boards_states.dart';
import 'package:cardo/theme/cardo_durations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';
import 'boards_screen_test.dart' show board, listKey, threeBoards, tileTitles;

void addBoard(FakeServer server, String title) {
  server.boards = <Map<String, Object?>>[
    board('b-$title', title, 'editor', 500),
    ...server.boards,
  ];
}

Future<void> background(WidgetTester tester) async {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Future<void> foreground(WidgetTester tester) async {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await pumpFrames(tester, 3);
}

void main() {
  group('background refresh', () {
    testWidgets('a new board appears after the interval without a spinner', (
      tester,
    ) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);
      expect(server.count(listKey), 1);

      addBoard(server, 'Added');
      await tester.pump(CardoDurations.boardsRefresh);
      await tester.pump();

      expect(server.count(listKey), 2);
      expect(tileTitles(tester), contains('Added'));
      expect(find.byType(BoardsSkeleton), findsNothing);
    });

    testWidgets('the list never shows the skeleton while refreshing', (
      tester,
    ) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);
      final gate = server.gate(listKey);

      await tester.pump(CardoDurations.boardsRefresh);

      expect(find.byType(BoardsSkeleton), findsNothing);
      expect(tileTitles(tester), hasLength(3));
      gate.complete();
      await pumpFrames(tester, 2);
    });

    testWidgets('a failed background refresh keeps the shown list', (
      tester,
    ) async {
      final server = threeBoards();
      final app = await pumpCardoApp(tester, server: server);

      server.on(listKey, FakeResponse.error(500, 'internal'));
      await tester.pump(CardoDurations.boardsRefresh);
      await tester.pump();

      expect(server.count(listKey), 2);
      expect(tileTitles(tester), hasLength(3));
      expect(find.text(app.l10n.boardsLoadError), findsNothing);

      server.clear(listKey);
      addBoard(server, 'Later');
      await tester.pump(CardoDurations.boardsRefresh);
      await tester.pump();
      expect(tileTitles(tester), contains('Later'));
    });

    testWidgets('resuming the app refreshes immediately', (tester) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);

      await background(tester);
      addBoard(server, 'WhileAway');
      await foreground(tester);

      expect(server.count(listKey), 2);
      expect(tileTitles(tester), contains('WhileAway'));
    });

    testWidgets('the timer is silent while the app is in the background', (
      tester,
    ) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);

      await background(tester);
      await tester.pump(CardoDurations.boardsRefresh * 3);

      expect(server.count(listKey), 1);
    });

    testWidgets('the timer stops once the list screen is closed', (
      tester,
    ) async {
      final server = threeBoards();
      final app = await pumpCardoApp(tester, server: server);

      app.router.go('/boards/b-mid');
      await pumpFrames(tester);
      final before = server.count(listKey);
      await tester.pump(CardoDurations.boardsRefresh * 3);

      expect(server.count(listKey), before);
    });

    testWidgets('returning to the list from a board loads it afresh', (
      tester,
    ) async {
      final server = threeBoards();
      final app = await pumpCardoApp(tester, server: server);

      app.router.go('/boards/b-mid');
      await pumpFrames(tester);
      addBoard(server, 'Meanwhile');
      app.router.go('/boards');
      await pumpFrames(tester);

      expect(tileTitles(tester), contains('Meanwhile'));
    });

    testWidgets('the timer is gone after the whole app is disposed', (
      tester,
    ) async {
      final server = threeBoards();
      await pumpCardoApp(tester, server: server);

      await tester.pumpWidget(const SizedBox.shrink());
      final before = server.count(listKey);
      await tester.pump(CardoDurations.boardsRefresh * 3);

      expect(server.count(listKey), before);
    });
  });

  group('refresh button', () {
    for (final variant in <Variant>[ruPhone, enDesktop]) {
      testWidgets('reloads the list for $variant', (tester) async {
        final server = threeBoards();
        await pumpCardoApp(tester, server: server, variant: variant);
        addBoard(server, 'ByButton');

        final button = find.byType(BoardsRefreshButton);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(LucideIcons.refreshCw),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(variant.l10n.boardsRefresh), findsOneWidget);
        final size = tester.getSize(find.byType(IconButton).first);
        expect(size.shortestSide, greaterThanOrEqualTo(44));

        await tester.tap(button);
        await pumpFrames(tester, 3);

        expect(server.count(listKey), 2);
        expect(tileTitles(tester), contains('ByButton'));
        expect(find.byType(BoardsContent), findsOneWidget);
      });
    }
  });
}
