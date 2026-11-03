import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';

class EndHarness {
  EndHarness(this.container);

  final ProviderContainer container;
  int backCalls = 0;
}

Future<EndHarness> pumpEnd(
  WidgetTester tester, {
  required BoardGateway gateway,
  required Locale locale,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late EndHarness harness;
  final ids = IdSequence();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(gateway),
        idGeneratorProvider.overrideWithValue(ids.call),
        nowProvider.overrideWithValue(() => demoReferenceTime),
        boardNavigationProvider.overrideWith(
          (ref) => BoardNavigation(onBack: () => harness.backCalls++),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BoardScreen(),
      ),
    ),
  );
  harness = EndHarness(
    ProviderScope.containerOf(tester.element(find.byType(BoardScreen))),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return harness;
}

enum EndCase { removedEvent, deletedEvent, closed4003, closed4004 }

void trigger(FakeBoardGateway gateway, EndCase end) {
  switch (end) {
    case EndCase.removedEvent:
      gateway.server.removeMember(DemoIds.elena);
    case EndCase.deletedEvent:
      gateway.server.deleteBoard();
    case EndCase.closed4003:
      gateway.server.closeConnections(4003);
    case EndCase.closed4004:
      gateway.server.closeConnections(4004);
  }
}

bool isRemoval(EndCase end) =>
    end == EndCase.removedEvent || end == EndCase.closed4003;

void main() {
  final locales = <Locale, AppLocalizations>{
    const Locale('ru'): AppLocalizationsRu(),
    const Locale('en'): AppLocalizationsEn(),
  };

  for (final entry in locales.entries) {
    for (final end in EndCase.values) {
      testWidgets(
        '${entry.key.languageCode}: ${end.name} shows the snackbar and goes '
        'back',
        (tester) async {
          final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
          final harness = await pumpEnd(
            tester,
            gateway: gateway,
            locale: entry.key,
          );
          final title = harness.container.read(boardViewProvider).title;
          final expected = isRemoval(end)
              ? entry.value.boardEndedRemoved(title)
              : entry.value.boardEndedDeleted(title);

          trigger(gateway, end);
          await tester.pump(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));

          expect(find.text(expected), findsOneWidget);
          expect(harness.backCalls, 1);
          expect(
            harness.container.read(boardNotifierProvider).ended,
            endReasonFor(end),
          );
          await tester.pump(const Duration(seconds: 10));
          await tester.pump(const Duration(seconds: 10));
        },
      );
    }
  }

  for (final entry in locales.entries) {
    testWidgets(
      '${entry.key.languageCode}: a refused upgrade shows the access text',
      (tester) async {
        final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
        final harness = await pumpEnd(
          tester,
          gateway: gateway,
          locale: entry.key,
        );

        gateway.server.rejectUpgrades(404);
        gateway.server.dropConnections();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(entry.value.boardEndedAccessLost), findsOneWidget);
        expect(harness.backCalls, 1);
        expect(
          harness.container.read(boardNotifierProvider).ended,
          BoardEndReason.accessLost,
        );
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
      },
    );
  }

  testWidgets('the Russian and English texts differ and name the board', (
    tester,
  ) async {
    final ru = AppLocalizationsRu().boardEndedRemoved('Доска');
    final en = AppLocalizationsEn().boardEndedRemoved('Board');

    expect(ru, contains('Доска'));
    expect(en, contains('Board'));
    expect(ru, isNot(en));
  });

  testWidgets('a session end shows no snackbar and does not navigate', (
    tester,
  ) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.sessionEnded));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar), findsNothing);
    expect(harness.backCalls, 0);
    expect(
      harness.container.read(boardNotifierProvider).ended,
      BoardEndReason.sessionEnded,
    );
  });

  testWidgets('an unsupported platform shows no snackbar', (tester) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('en'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.unsupported));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar), findsNothing);
    expect(harness.backCalls, 0);
  });

  testWidgets('the end is announced once even if signalled twice', (
    tester,
  ) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('en'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.removed));
    gateway.emit(const EndedSignal(BoardEndReason.boardDeleted));
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.backCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an ongoing board shows nothing', (tester) async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );

    gateway.server.dropConnections();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(SnackBar), findsNothing);
    expect(harness.backCalls, 0);
  });
}

Matcher endReasonFor(EndCase end) => equals(
  isRemoval(end) ? BoardEndReason.removed : BoardEndReason.boardDeleted,
);
