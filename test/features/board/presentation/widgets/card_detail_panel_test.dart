import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/presentation/widgets/card_detail_panel.dart';
import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

const String _card = DemoIds.handshakeCard;
const String _title = 'Handshake: last_seq → дельта или снапшот';

final Finder _save = find.widgetWithText(FilledButton, 'Сохранить');

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_save).onPressed != null;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.text(_title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(descriptionField).controller!.text;

void main() {
  group('expanded panel', () {
    testWidgets('shows the same body as the sheet', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await _openPanel(tester);
      expect(find.byType(CardDetailPanel), findsOneWidget);
      expect(find.text('Создал Максим · вчера'), findsOneWidget);
      expect(find.text('v14'), findsOneWidget);
      expect(_fieldText(tester), demoBoard().cardById(_card)!.description);
      expect(find.byTooltip('В архив'), findsOneWidget);
      expect(find.text('Переместить'), findsOneWidget);
      expect(find.byType(ConflictBanner), findsNothing);
    });

    testWidgets('save is active only with an unsaved draft', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      expect(_saveEnabled(tester), isFalse);

      await tester.enterText(descriptionField, 'панель');
      await tester.pump();
      expect(_saveEnabled(tester), isTrue);

      await tester.enterText(
        descriptionField,
        demoBoard().cardById(_card)!.description,
      );
      await tester.pump();
      expect(_saveEnabled(tester), isFalse);

      await tester.enterText(descriptionField, 'панель');
      await tester.pump();
      await tester.tap(_save);
      await tester.pump();
      final ops = submittedOps<EditCardDescription>(gateway);
      expect(ops.single.description, 'панель');
      expect(ops.single.baseDescriptionVersion, 1);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('blur does not save in the panel', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      await tester.tap(descriptionField);
      await tester.enterText(descriptionField, 'без blur');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(gateway.calls, isEmpty);
    });

    testWidgets('save is disabled over the limit', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      await tester.enterText(descriptionField, 'x' * 10001);
      await tester.pump();
      expect(_saveEnabled(tester), isFalse);
      expect(find.text('10 001 / 10 000'), findsOneWidget);
      expect(find.textContaining('Слишком длинное'), findsOneWidget);
      await tester.enterText(descriptionField, 'x' * 10000);
      await tester.pump();
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('save is disabled during a conflict and the banner works', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      await tester.enterText(descriptionField, 'моё');
      await tester.pump();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'чужое',
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ConflictBanner), findsOneWidget);
      expect(find.text('Описание изменил Максим'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      expect(_fieldText(tester), 'моё');

      await tester.tap(find.text('Перезаписать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ConflictBanner), findsNothing);
      expect(gateway.serverBoard.cardById(_card)!.description, 'моё');
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('cancel in the panel restores the server text', (tester) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      await tester.enterText(descriptionField, 'моё');
      await tester.pump();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'чужое',
        actorId: DemoIds.maxim,
        deliver: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Отменить'));
      await tester.pump();
      expect(find.byType(ConflictBanner), findsNothing);
      expect(_fieldText(tester), 'чужое');
    });

    testWidgets('title editing works in the panel', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      await _openPanel(tester);
      await tester.tap(find.text(_title).last);
      await tester.pump();
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Из панели');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submittedOps<EditCardTitle>(gateway).single.title, 'Из панели');
    });

    testWidgets('a viewer gets no save, archive or editing', (tester) async {
      await pumpBoard(tester, size: expandedSize, role: BoardRole.viewer);
      await _openPanel(tester);
      expect(_save, findsNothing);
      expect(find.byTooltip('В архив'), findsNothing);
      expect(tester.widget<TextField>(descriptionField).readOnly, isTrue);
      await tester.tap(find.text(_title).last);
      await tester.pump();
      expect(titleField, findsNothing);
    });

    for (final brightness in Brightness.values) {
      for (final scale in <double>[1, 2]) {
        testWidgets('${brightness.name} scale $scale with a conflict', (
          tester,
        ) async {
          final gateway = fakeGateway();
          await pumpBoard(
            tester,
            size: expandedSize,
            brightness: brightness,
            textScale: scale,
            gateway: gateway,
          );
          await _openPanel(tester);
          await tester.enterText(descriptionField, 'моё');
          gateway.simulateRemoteDescriptionEdit(
            cardId: _card,
            text: 'чужое',
            actorId: DemoIds.maxim,
            deliver: true,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(ConflictBanner), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
