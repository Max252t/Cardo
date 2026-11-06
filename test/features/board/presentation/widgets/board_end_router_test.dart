import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/board_ended_dialog.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/board_fixtures.dart';

void main() {
  testWidgets('leaving the dialog navigates a real router to /boards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = ControlledGateway();
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/board',
      routes: [
        GoRoute(
          path: '/board',
          builder: (context, state) => const BoardScreen(),
        ),
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
          nowProvider.overrideWithValue(() => demoReferenceTime),
          boardNavigationProvider.overrideWith(
            (ref) => BoardNavigation(onBack: () => router.go('/boards')),
          ),
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

    gateway.emit(const EndedSignal(BoardEndReason.removed));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BoardEndedDialog), findsOneWidget);

    await tester.tap(find.text('К моим доскам'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('boards-list-page'), findsOneWidget);
    expect(find.byType(BoardEndedDialog), findsNothing);
    expect(find.byType(BoardScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
