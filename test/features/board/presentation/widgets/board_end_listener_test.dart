import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/widgets/board_ended_dialog.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:cardo/features/boards/presentation/boards_providers.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_sheet.dart';

class EndHarness {
  EndHarness(this.container);

  final ProviderContainer container;
  int backCalls = 0;
  int listLoads = 0;
}

Future<EndHarness> pumpEnd(
  WidgetTester tester, {
  required BoardGateway gateway,
  required Locale locale,
  Size size = const Size(375, 812),
  double textScale = 1,
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
        boardsListProvider.overrideWith(
          () => CountingBoardsList(() => harness.listLoads++),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
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

Future<void> settleDialog(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 400));
}

List<String> mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

final Finder dialogFinder = find.byType(BoardEndedDialog);

class CountingBoardsList extends BoardsListNotifier {
  CountingBoardsList(this.onBuild);

  final void Function() onBuild;

  @override
  Future<Result<List<BoardInfo>, ApiFailure>> build() {
    onBuild();
    return Future.value(
      const Success<List<BoardInfo>, ApiFailure>(<BoardInfo>[]),
    );
  }
}

void main() {
  final locales = <Locale, AppLocalizations>{
    const Locale('ru'): AppLocalizationsRu(),
    const Locale('en'): AppLocalizationsEn(),
  };

  for (final entry in locales.entries) {
    for (final end in EndCase.values) {
      testWidgets(
        '${entry.key.languageCode}: ${end.name} shows a dialog and waits for '
        'the button',
        (tester) async {
          final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
          final harness = await pumpEnd(
            tester,
            gateway: gateway,
            locale: entry.key,
          );
          final title = harness.container.read(boardViewProvider).title;
          final l10n = entry.value;

          trigger(gateway, end);
          await settleDialog(tester);

          expect(dialogFinder, findsOneWidget);
          expect(
            find.text(
              isRemoval(end)
                  ? l10n.boardEndedRemovedTitle
                  : l10n.boardEndedDeletedTitle,
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              isRemoval(end)
                  ? l10n.boardEndedRemovedBody(title)
                  : l10n.boardEndedDeletedBody(title),
            ),
            findsOneWidget,
          );
          expect(find.byType(SnackBar), findsNothing);
          expect(harness.backCalls, 0);
          expect(
            harness.container.read(boardNotifierProvider).ended,
            isRemoval(end)
                ? BoardEndReason.removed
                : BoardEndReason.boardDeleted,
          );

          await tester.tap(find.text(l10n.boardEndedAction));
          await settleDialog(tester);

          expect(harness.backCalls, 1);
          expect(dialogFinder, findsNothing);
        },
      );
    }
  }

  for (final entry in locales.entries) {
    testWidgets(
      '${entry.key.languageCode}: a refused upgrade shows the general text',
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
        await settleDialog(tester);

        expect(find.text(entry.value.boardEndedAccessLostBody), findsOneWidget);
        expect(find.text(entry.value.boardEndedRemovedTitle), findsOneWidget);
        expect(harness.backCalls, 0);
        expect(
          harness.container.read(boardNotifierProvider).ended,
          BoardEndReason.accessLost,
        );
        await tester.tap(find.text(entry.value.boardEndedAction));
        await settleDialog(tester);
        expect(harness.backCalls, 1);
      },
    );
  }

  testWidgets('the dialog cannot be dismissed by tapping outside', (
    tester,
  ) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.removed));
    await settleDialog(tester);
    await tester.tapAt(const Offset(4, 4));
    await settleDialog(tester);

    expect(dialogFinder, findsOneWidget);
    expect(harness.backCalls, 0);
  });

  testWidgets('system back does the same as the button, once', (tester) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.boardDeleted));
    await settleDialog(tester);
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await settleDialog(tester);

    expect(harness.backCalls, 1);
    expect(dialogFinder, findsNothing);
  });

  testWidgets('leaving reloads the list of boards', (tester) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );
    final subscription = harness.container.listen(
      boardsListProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await tester.pump();
    final before = harness.listLoads;

    gateway.emit(const EndedSignal(BoardEndReason.removed));
    await settleDialog(tester);
    await tester.tap(find.text('К моим доскам'));
    await settleDialog(tester);

    expect(harness.listLoads, before + 1);
    expect(harness.backCalls, 1);
  });

  testWidgets('a session end shows no dialog and does not navigate', (
    tester,
  ) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.sessionEnded));
    await settleDialog(tester);

    expect(dialogFinder, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.backCalls, 0);
    expect(
      harness.container.read(boardNotifierProvider).ended,
      BoardEndReason.sessionEnded,
    );
  });

  testWidgets('an unsupported platform shows no dialog', (tester) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('en'),
    );

    gateway.emit(const EndedSignal(BoardEndReason.unsupported));
    await settleDialog(tester);

    expect(dialogFinder, findsNothing);
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
    await settleDialog(tester);

    expect(dialogFinder, findsOneWidget);
    await tester.tap(find.text('To my boards'));
    await settleDialog(tester);
    expect(harness.backCalls, 1);
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

    expect(dialogFinder, findsNothing);
    expect(harness.backCalls, 0);
  });

  testWidgets('unsaved description text is shown and can be copied', (
    tester,
  ) async {
    final copied = mockClipboard(tester);
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );
    harness.container
        .read(cardDraftsProvider.notifier)
        .edit(DemoIds.handshakeCard, 'Мой важный черновик');
    await tester.pump();

    gateway.server.removeMember(DemoIds.elena);
    await settleDialog(tester);

    expect(find.text('Несохранённый текст'), findsOneWidget);
    expect(find.text('Мой важный черновик'), findsOneWidget);

    await tester.tap(find.text('Скопировать'));
    await tester.pump();

    expect(copied, ['Мой важный черновик']);
    expect(find.text('Скопировано'), findsOneWidget);
    expect(harness.backCalls, 0);
  });

  testWidgets('a description edit already queued is shown as well', (
    tester,
  ) async {
    final gateway = ControlledGateway();
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('en'),
    );
    harness.container
        .read(boardNotifierProvider.notifier)
        .editCardDescription(
          cardId: DemoIds.rankCard,
          description: 'Queued words',
          baseDescriptionVersion: 0,
        );

    gateway.emit(const EndedSignal(BoardEndReason.boardDeleted));
    await settleDialog(tester);

    expect(find.text('Unsaved text'), findsOneWidget);
    expect(find.text('Queued words'), findsOneWidget);
  });

  testWidgets('without unsaved text the block is absent', (tester) async {
    final gateway = ControlledGateway();
    await pumpEnd(tester, gateway: gateway, locale: const Locale('ru'));

    gateway.emit(const EndedSignal(BoardEndReason.removed));
    await settleDialog(tester);

    expect(find.text('Несохранённый текст'), findsNothing);
  });

  testWidgets('the dialog appears above an open card sheet and closes it', (
    tester,
  ) async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
    );
    await openCardSheet(tester);
    expect(find.byType(CardSheet), findsOneWidget);

    gateway.server.removeMember(DemoIds.elena);
    await settleDialog(tester);

    expect(find.byType(CardSheet), findsNothing);
    expect(dialogFinder, findsOneWidget);
    expect(harness.backCalls, 0);

    await tester.tap(find.text('К моим доскам'));
    await settleDialog(tester);

    expect(harness.backCalls, 1);
    expect(dialogFinder, findsNothing);
    expect(find.byType(CardSheet), findsNothing);
  });

  testWidgets('a narrow screen with large text scrolls without overflow', (
    tester,
  ) async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final harness = await pumpEnd(
      tester,
      gateway: gateway,
      locale: const Locale('ru'),
      size: const Size(360, 640),
      textScale: 2,
    );
    harness.container
        .read(cardDraftsProvider.notifier)
        .edit(DemoIds.handshakeCard, List.filled(40, 'длинный').join(' '));
    await tester.pump();

    gateway.server.deleteBoard();
    await settleDialog(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Доска удалена'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('К моим доскам'),
      200,
      scrollable: find.descendant(
        of: dialogFinder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('К моим доскам'));
    await settleDialog(tester);
    expect(harness.backCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
