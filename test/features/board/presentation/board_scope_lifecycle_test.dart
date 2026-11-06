import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/board_sidebar_items.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String snapshotKey = 'GET /api/boards/$boardId1';

ProviderContainer boardContainer(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(BoardScreen)));
}

Finder sidebarText(String text) {
  return find.descendant(
    of: find.byType(SidebarProfile),
    matching: find.text(text),
  );
}

void main() {
  group('profile changes while a board is open', () {
    testWidgets('the session carries the new profile', (tester) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        openLocation: '/boards/$boardId1',
      );
      expect(sidebarText('Anna'), findsOneWidget);

      final result = await tester.runAsync(
        () => app.container
            .read(sessionProvider.notifier)
            .updateProfile(displayName: 'Bea'),
      );
      await pumpFrames(tester);

      expect(result!.isSuccess, isTrue);
      final session = app.container.read(sessionProvider) as SessionSignedIn;
      expect(session.user.displayName, 'Bea');
      expect(app.server.count('PATCH /api/me'), 1);
    });

    testWidgets('the open board follows the live session user', (tester) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        openLocation: '/boards/$boardId1',
      );

      await tester.runAsync(
        () => app.container
            .read(sessionProvider.notifier)
            .updateProfile(displayName: 'Bea'),
      );
      await pumpFrames(tester);

      expect(boardContainer(tester).read(currentUserProvider).name, 'Bea');
      expect(sidebarText('Bea'), findsOneWidget);
      expect(sidebarText('Anna'), findsNothing);
      expect(app.server.count(snapshotKey), 1);

      app.router.go('/boards');
      await pumpFrames(tester);
      app.router.go('/boards/$boardId1');
      await pumpFrames(tester);

      expect(sidebarText('Bea'), findsOneWidget);
      expect(boardContainer(tester).read(currentUserProvider).name, 'Bea');
      expect(app.server.count(snapshotKey), 2);
    });

    testWidgets('editing the profile through its screen and coming back', (
      tester,
    ) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        server: FakeServer()..user = userJson(displayName: 'Anna'),
        openLocation: '/boards/$boardId1',
      );

      await tester.tap(find.byType(SidebarProfile));
      await pumpFrames(tester);
      expect(find.text(app.l10n.profileTitle), findsOneWidget);
      await enterAt(tester, 0, 'Bea');
      await tester.tap(find.text(app.l10n.profileSave));
      await pumpFrames(tester, 3);
      await tester.tap(find.byTooltip(app.l10n.profileBack));
      await pumpFrames(tester);

      expect(app.location, '/boards/$boardId1');
      expect(find.byType(BoardScreen), findsOneWidget);
      expect(
        (app.container.read(
          sessionProvider,
        ) as SessionSignedIn).user.displayName,
        'Bea',
      );
      expect(sidebarText('Bea'), findsOneWidget);
      expect(sidebarText('Anna'), findsNothing);
    });
  });

  group('leaving the board closes its container', () {
    testWidgets('board providers die while app providers live on', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/$boardId1');
      final inner = boardContainer(tester);
      expect(inner.read(boardViewProvider).id, boardId1);
      final manager = app.container.read(tokenManagerProvider);

      app.router.go('/boards');
      await pumpFrames(tester);

      expect(find.byType(BoardScreen), findsNothing);
      expect(() => inner.read(boardViewProvider), throwsA(anything));
      expect(app.container.read(sessionProvider), isA<SessionSignedIn>());
      expect(
        identical(app.container.read(tokenManagerProvider), manager),
        true,
      );
      expect(app.container.read(dioProvider), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening the board again loads the snapshot anew', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/$boardId1');
      final first = boardContainer(tester);
      expect(app.server.count(snapshotKey), 1);

      app.router.go('/boards');
      await pumpFrames(tester);
      app.router.go('/boards/$boardId1');
      await pumpFrames(tester);

      final second = boardContainer(tester);
      expect(identical(first, second), isFalse);
      expect(app.server.count(snapshotKey), 2);
      expect(second.read(boardViewProvider).id, boardId1);
      expect(find.text('First'), findsOneWidget);
    });

    testWidgets('moving to another board replaces the container', (
      tester,
    ) async {
      final app = await pumpCardoApp(
        tester,
        variant: ruDesktop,
        openLocation: '/boards/$boardId1',
      );
      final first = boardContainer(tester);

      await tester.tap(find.text('Design').first);
      await pumpFrames(tester);

      final second = boardContainer(tester);
      expect(identical(first, second), isFalse);
      expect(() => first.read(boardViewProvider), throwsA(anything));
      expect(second.read(boardViewProvider).id, 'board-2');
      expect(app.location, '/boards/board-2');
    });

    testWidgets('the Back button closes the container as well', (tester) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/$boardId1');
      final inner = boardContainer(tester);

      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(() => inner.read(boardViewProvider), throwsA(anything));
    });
  });
}
