import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

const String _card = DemoIds.handshakeCard;
const String _serverText = 'Серверный текст';
const String _mine = 'Мой текст';

final Finder _banner = find.byType(ConflictBanner);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(descriptionField).controller!.text;

void main() {
  group('conflict banner in the sheet', () {
    testWidgets('a remote edit shows the banner and keeps the user text', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      expect(_banner, findsNothing);

      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await _settle(tester);

      expect(_banner, findsOneWidget);
      expect(find.text('Описание изменил Максим'), findsOneWidget);
      expect(
        find.text(
          'Ваш черновик сохранён. Перезаписать его версией или отменить свои правки?',
        ),
        findsOneWidget,
      );
      expect(find.text('Перезаписать'), findsOneWidget);
      expect(find.text('Отменить'), findsOneWidget);
      expect(_fieldText(tester), _mine);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overwrite saves the draft on top of the server version', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await _settle(tester);

      await tester.tap(find.text('Перезаписать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_banner, findsNothing);
      expect(_fieldText(tester), _mine);
      final server = gateway.serverBoard.cardById(_card)!;
      expect(server.description, _mine);
      expect(server.descriptionVersion, 3);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('cancel drops the draft and shows the server text', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await _settle(tester);

      await tester.tap(find.text('Отменить'));
      await tester.pump();

      expect(_banner, findsNothing);
      expect(_fieldText(tester), _serverText);
      expect(gateway.serverBoard.cardById(_card)!.description, _serverText);
    });

    testWidgets('a silent remote edit becomes a conflict through a nack', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.anya,
      );
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsNothing);

      await openCardSheet(tester);
      expect(_banner, findsOneWidget);
      expect(find.text('Описание изменил Аня'), findsOneWidget);
      expect(_fieldText(tester), _mine);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a conflicted draft survives closing the sheet', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await _settle(tester);
      await closeCardSheet(tester);
      expect(find.byType(CardSheet), findsNothing);
      expect(draftTextOf(tester, _card), _mine);

      await openCardSheet(tester);
      expect(_banner, findsOneWidget);
      expect(_fieldText(tester), _mine);
    });

    testWidgets('a viewer never sees the banner', (tester) async {
      final gateway = fakeGateway(role: BoardRole.viewer);
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: _serverText,
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await _settle(tester);
      expect(_banner, findsNothing);
      expect(_fieldText(tester), _serverText);
    });
  });

  group('snackbar', () {
    testWidgets('a description version conflict shows no snackbar', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is EditCardDescription
            ? const OpRejection(
                reason: NackReason.versionConflict,
                actorId: DemoIds.maxim,
              )
            : null,
      );
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('other nacks still show a snackbar', (tester) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is MoveCard
            ? const OpRejection(
                reason: NackReason.versionConflict,
                actorId: DemoIds.maxim,
              )
            : null,
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a forbidden description nack shows a snackbar', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is EditCardDescription
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await openCardSheet(tester);
      await tester.enterText(descriptionField, _mine);
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('limit', () {
    testWidgets('over the limit shows the counter, hint and blocks saving', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'x' * 10001);
      await tester.pump();
      expect(find.text('10 001 / 10 000'), findsOneWidget);
      expect(
        find.text(
          'Слишком длинное описание: максимум 10 000 символов. Сохранение недоступно.',
        ),
        findsOneWidget,
      );
      await closeCardSheet(tester);
      expect(submittedOps<EditCardDescription>(gateway), isEmpty);
      expect(draftTextOf(tester, _card)!.length, 10001);
      await openCardSheet(tester);
      expect(_fieldText(tester).length, 10001);
    });

    testWidgets('exactly 10 000 characters show no hint and are saved', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'x' * 10000);
      await tester.pump();
      expect(find.text('10 000 / 10 000'), findsOneWidget);
      expect(find.textContaining('Слишком длинное'), findsNothing);
      await closeCardSheet(tester);
      expect(submittedOps<EditCardDescription>(gateway), hasLength(1));
    });
  });

  group('keyboard and scale', () {
    testWidgets('the field stays visible above a 300 px keyboard', (
      tester,
    ) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await pumpBoard(tester);
      await openCardSheet(tester);
      expect(tester.getRect(descriptionField).top, lessThan(812 - 300));
      await tester.drag(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.byType(CustomScrollView),
        ),
        const Offset(0, -600),
      );
      await tester.pump();
      final field = tester.getRect(descriptionField);
      expect(field.bottom, lessThanOrEqualTo(812 - 300));
      expect(field.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      for (final scale in <double>[1, 2]) {
        testWidgets('360x640 ${brightness.name} scale $scale', (tester) async {
          final gateway = fakeGateway();
          await pumpBoard(
            tester,
            size: const Size(360, 640),
            brightness: brightness,
            textScale: scale,
            gateway: gateway,
          );
          await openCardSheet(tester);
          expect(tester.takeException(), isNull);

          await tester.enterText(descriptionField, _mine);
          gateway.simulateRemoteDescriptionEdit(
            cardId: _card,
            text: _serverText,
            actorId: DemoIds.maxim,
            deliver: true,
          );
          await _settle(tester);
          expect(_banner, findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.enterText(descriptionField, 'x' * 10001);
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
