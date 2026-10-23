import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

const String _card = DemoIds.handshakeCard;

final Finder _archive = find.byTooltip('В архив');
final Finder _close = find.byTooltip('Закрыть');

bool _archiveEnabled(WidgetTester tester) {
  final button = tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, LucideIcons.archive),
  );
  return button.onPressed != null;
}

TextField _description(WidgetTester tester) =>
    tester.widget<TextField>(descriptionField);

void main() {
  final handshakeLength = demoBoard().cardById(_card)!.description.length;

  group('structure on 375x812', () {
    testWidgets('shows every part of the sheet', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);

      expect(find.byType(CardSheet), findsOneWidget);
      expect(tester.getRect(find.byType(CardSheet)).top, 96);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints ==
                  const BoxConstraints.tightFor(width: 40, height: 5),
        ),
        findsOneWidget,
      );
      expect(find.text('В работе'), findsWidgets);
      expect(_archive, findsOneWidget);
      expect(_close, findsOneWidget);
      expect(tester.getSize(_archive), const Size(44, 44));
      expect(tester.getSize(_close), const Size(44, 44));
      expect(
        find.text('Handshake: last_seq → дельта или снапшот'),
        findsWidgets,
      );
      expect(find.text('Создал Максим · вчера'), findsOneWidget);
      expect(find.text('v14'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.text('Описание'),
        ),
        findsOneWidget,
      );
      expect(
        _description(tester).controller!.text,
        demoBoard().cardById(_card)!.description,
      );
      expect(find.byType(ConflictBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('counter is formatted for the locale', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      final expected = AppLocalizationsRu().cardDescriptionCounter(
        handshakeLength,
        10000,
      );
      expect(expected, contains('10 000'));
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('counter follows typing', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'abc');
      await tester.pump();
      expect(find.text('3 / 10 000'), findsOneWidget);
    });
  });

  group('opening by tap', () {
    testWidgets('compact', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Rate limit на логин: 5 попыток в минуту'));
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.byType(CardSheet), findsOneWidget);
      expect(find.text('Создал Елена · 2 дня назад'), findsOneWidget);
    });

    testWidgets('medium', (tester) async {
      await pumpBoard(tester, size: mediumSize);
      await tester.tap(find.text('Rate limit на логин: 5 попыток в минуту'));
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.byType(CardSheet), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
    });
  });

  group('closing', () {
    testWidgets('archive closes the sheet and archives the card', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.tap(_archive);
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.byType(CardSheet), findsNothing);
      expect(submittedOps<ArchiveCard>(gateway).single.cardId, _card);
    });

    testWidgets('archiving from outside closes the sheet', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .archiveCard(_card);
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.byType(CardSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('close saves the changed description', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'новый текст');
      await tester.pump();
      expect(submittedOps<EditCardDescription>(gateway), isEmpty);
      await closeCardSheet(tester);
      expect(find.byType(CardSheet), findsNothing);
      final ops = submittedOps<EditCardDescription>(gateway);
      expect(ops.length, 1);
      expect(ops.single.description, 'новый текст');
      expect(ops.single.baseDescriptionVersion, 1);
    });

    testWidgets('close without changes sends nothing', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await closeCardSheet(tester);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('losing focus saves the description', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.tap(descriptionField);
      await tester.pump();
      await tester.enterText(descriptionField, 'blur text');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        submittedOps<EditCardDescription>(gateway).single.description,
        'blur text',
      );
    });
  });

  group('viewer', () {
    testWidgets('read-only field, no archive, no title editing', (
      tester,
    ) async {
      await pumpBoard(tester, role: BoardRole.viewer);
      await openCardSheet(tester);
      expect(_description(tester).readOnly, isTrue);
      expect(_archive, findsNothing);
      expect(_close, findsOneWidget);
      await tester.tap(
        find.text('Handshake: last_seq → дельта или снапшот').last,
      );
      await tester.pump();
      expect(titleField, findsNothing);
      expect(find.text('Перезаписать'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('locked', () {
    testWidgets('a nack on the card disables archive and editing', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is MoveCard
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await openCardSheet(tester);
      expect(_archiveEnabled(tester), isTrue);
      expect(_description(tester).readOnly, isFalse);

      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_archiveEnabled(tester), isFalse);
      expect(_description(tester).readOnly, isTrue);
      await tester.tap(
        find.text('Handshake: last_seq → дельта или снапшот').last,
      );
      await tester.pump();
      expect(titleField, findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(_archiveEnabled(tester), isTrue);
      expect(_description(tester).readOnly, isFalse);
    });
  });

  group('title editing', () {
    final titleText = find.text('Handshake: last_seq → дельта или снапшот');

    Future<void> startEditing(WidgetTester tester) async {
      await tester.tap(titleText.last);
      await tester.pump();
    }

    testWidgets('tap turns the title into a field', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      expect(titleField, findsNothing);
      await startEditing(tester);
      expect(titleField, findsOneWidget);
      expect(
        tester.widget<TextField>(titleField).controller!.text,
        'Handshake: last_seq → дельта или снапшот',
      );
    });

    testWidgets('Enter saves through EditCardTitle', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.enterText(titleField, 'Новый заголовок');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final ops = submittedOps<EditCardTitle>(gateway);
      expect(ops.length, 1);
      expect(ops.single.title, 'Новый заголовок');
      expect(ops.single.cardId, _card);
      expect(titleField, findsNothing);
      expect(find.text('Новый заголовок'), findsWidgets);
    });

    testWidgets('Escape cancels', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.enterText(titleField, 'Не сохранять');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(gateway.calls, isEmpty);
      expect(titleField, findsNothing);
      expect(titleText, findsWidgets);
    });

    testWidgets('losing focus saves', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.enterText(titleField, 'По blur');
      await tester.tap(descriptionField);
      await tester.pump();
      expect(submittedOps<EditCardTitle>(gateway).single.title, 'По blur');
      expect(titleField, findsNothing);
    });

    testWidgets('an unchanged or blank title creates no operation', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await startEditing(tester);
      await tester.enterText(titleField, '   ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(gateway.calls, isEmpty);
    });

    testWidgets('the close button commits the title through focus loss', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.enterText(titleField, 'Через кнопку');
      await closeCardSheet(tester);
      expect(find.byType(CardSheet), findsNothing);
      expect(submittedOps<EditCardTitle>(gateway).single.title, 'Через кнопку');
    });

    testWidgets('a back-dismiss during editing still commits the title', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await startEditing(tester);
      await tester.enterText(titleField, 'Потерянная правка');
      unawaited(
        Navigator.of(tester.element(find.byType(CardSheet))).maybePop(),
      );
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.byType(CardSheet), findsNothing);
      expect(
        submittedOps<EditCardTitle>(gateway).single.title,
        'Потерянная правка',
      );
    });
  });
}
