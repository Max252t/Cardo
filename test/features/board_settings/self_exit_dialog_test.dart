import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/board_ended_dialog.dart';
import 'package:cardo/features/board_settings/data/board_settings_api.dart';
import 'package:cardo/features/board_settings/presentation/board_settings_providers.dart';
import 'package:cardo/features/board_settings/presentation/board_settings_screen.dart';
import 'package:cardo/features/board_settings/presentation/self_exit.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../board/helpers/board_fixtures.dart';

class EndingSettingsApi implements BoardSettingsApi {
  EndingSettingsApi(this.gateway, this.reason);

  final ControlledGateway gateway;
  final BoardEndReason reason;
  Result<void, ApiFailure> outcome = const Success<void, ApiFailure>(null);
  final List<String> calls = <String>[];

  @override
  Future<Result<BoardInfo, ApiFailure>> renameBoard(
    String boardId,
    String title,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void, ApiFailure>> deleteBoard(String boardId) async {
    calls.add('delete $boardId');
    gateway.emit(EndedSignal(reason));
    return outcome;
  }

  @override
  Future<Result<void, ApiFailure>> leaveBoard(
    String boardId,
    String userId,
  ) async {
    calls.add('leave $boardId $userId');
    gateway.emit(EndedSignal(reason));
    return outcome;
  }
}

class Rig {
  Rig(this.gateway, this.api, this.router, this.container);

  final ControlledGateway gateway;
  final EndingSettingsApi api;
  final GoRouter router;
  final ProviderContainer container;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

Future<Rig> pumpRig(
  WidgetTester tester, {
  required BoardRole role,
  required BoardEndReason reason,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gateway = ControlledGateway(
    initial: demoBoardSnapshot(currentUserRole: role),
  );
  final api = EndingSettingsApi(gateway, reason);
  final router = GoRouter(
    initialLocation: '/board',
    routes: <RouteBase>[
      GoRoute(path: '/board', builder: (context, state) => const BoardScreen()),
      GoRoute(
        path: '/boards',
        builder: (context, state) =>
            const Scaffold(body: Text('boards-list-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final ids = IdSequence();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(gateway),
        idGeneratorProvider.overrideWithValue(ids.call),
        nowProvider.overrideWithValue(clock ?? () => demoReferenceTime),
        boardNavigationProvider.overrideWith(
          (ref) => BoardNavigation(onBack: () => router.go('/boards')),
        ),
        boardSettingsApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(
        theme: buildLightTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return Rig(gateway, api, router, container);
}

Future<void> openSettingsAndConfirm(
  WidgetTester tester, {
  required String start,
  required String confirm,
}) async {
  await tester.tap(find.byTooltip('Меню доски'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(BoardSettingsScreen), findsOneWidget);
  await tester.ensureVisible(find.text(start));
  await tester.tap(find.text(start));
  await tester.pump();
  await tester.tap(find.text(confirm));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('owner deleting: the own 4004 raises no M-Removed dialog', (
    tester,
  ) async {
    final rig = await pumpRig(
      tester,
      role: BoardRole.owner,
      reason: BoardEndReason.boardDeleted,
    );

    await openSettingsAndConfirm(
      tester,
      start: 'Удалить доску',
      confirm: 'Удалить',
    );

    expect(rig.api.calls, hasLength(1));
    expect(find.byType(BoardEndedDialog), findsNothing);
    expect(find.byType(BoardSettingsScreen), findsNothing);
    expect(rig.location, '/boards');
    expect(find.text('boards-list-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final role in <BoardRole>[BoardRole.editor, BoardRole.viewer]) {
    testWidgets('${role.name} leaving: the own 4003 raises no dialog', (
      tester,
    ) async {
      final rig = await pumpRig(
        tester,
        role: role,
        reason: BoardEndReason.removed,
      );

      await openSettingsAndConfirm(
        tester,
        start: 'Покинуть доску',
        confirm: 'Покинуть',
      );

      expect(rig.api.calls.single, startsWith('leave '));
      expect(find.byType(BoardEndedDialog), findsNothing);
      expect(rig.location, '/boards');
      expect(find.text('boards-list-page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed leave clears the mark so a real removal still asks', (
    tester,
  ) async {
    final rig = await pumpRig(
      tester,
      role: BoardRole.editor,
      reason: BoardEndReason.removed,
    );
    rig.api.outcome = const Failure<void, ApiFailure>(ForbiddenFailure());

    await openSettingsAndConfirm(
      tester,
      start: 'Покинуть доску',
      confirm: 'Покинуть',
    );

    expect(rig.container.read(selfExitProvider), isEmpty);
    expect(rig.location, '/board');
  });

  testWidgets('a removal by someone else still shows the dialog', (
    tester,
  ) async {
    final rig = await pumpRig(
      tester,
      role: BoardRole.editor,
      reason: BoardEndReason.removed,
    );

    rig.gateway.emit(const EndedSignal(BoardEndReason.removed));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BoardEndedDialog), findsOneWidget);
  });

  testWidgets('a stale mark does not hide a later removal', (tester) async {
    var now = demoReferenceTime;
    final rig = await pumpRig(
      tester,
      role: BoardRole.editor,
      reason: BoardEndReason.removed,
      clock: () => now,
    );
    final boardId = rig.container.read(selfExitProvider.notifier);
    boardId.mark(demoBoardSnapshot().board.id);
    now = now.add(const Duration(minutes: 5));

    rig.gateway.emit(const EndedSignal(BoardEndReason.removed));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BoardEndedDialog), findsOneWidget);
  });
}
