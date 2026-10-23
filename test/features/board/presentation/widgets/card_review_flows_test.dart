import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/widgets/card_detail_panel.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

const String _card = DemoIds.handshakeCard;
const String _title = 'Handshake: last_seq → дельта или снапшот';

OpRejection? _rejectMoves(BoardOp op) =>
    op is MoveCard ? const OpRejection(reason: NackReason.forbidden) : null;

Future<void> _pumpFor(WidgetTester tester, int milliseconds) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

bool _buttonEnabled(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  return button.onPressed != null;
}

int _textFieldNodes(SemanticsNode node) {
  var count = node.flagsCollection.isTextField ? 1 : 0;
  node.visitChildren((child) {
    count += _textFieldNodes(child);
    return true;
  });
  return count;
}

void main() {
  group('nack inside the sheet', () {
    testWidgets('forbidden is visible above the modal route', (tester) async {
      await pumpBoard(tester, rejectWhen: _rejectMoves);
      await openCardSheet(tester);
      expect(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.text('Нет прав на это действие.'),
        ),
        findsNothing,
      );

      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      await _pumpFor(tester, 300);

      expect(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.text('Нет прав на это действие.'),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 3));
      expect(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.text('Нет прав на это действие.'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a description conflict shows the banner, not the strip', (
      tester,
    ) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'theirs',
        actorId: DemoIds.maxim,
      );
      await tester.enterText(descriptionField, 'mine');
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await openCardSheet(tester);

      expect(find.byType(ConflictBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CardSheet),
          matching: find.text('Карточку уже изменил другой участник.'),
        ),
        findsNothing,
      );
      expect(tester.widget<TextField>(descriptionField).readOnly, isFalse);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('title typed when the card becomes locked', () {
    testWidgets('is committed, not thrown away', (tester) async {
      await pumpBoard(tester, rejectWhen: _rejectMoves);
      await openCardSheet(tester);
      await tester.tap(find.text(_title).last);
      await tester.pump();
      await tester.enterText(titleField, 'Typed during lock');

      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      await _pumpFor(tester, 300);
      await tester.pump(const Duration(milliseconds: 300));

      expect(titleField, findsNothing);
      expect(
        containerOf(tester).read(boardViewProvider).cardById(_card)!.title,
        'Typed during lock',
      );
      expect(find.text('Typed during lock'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });

  group('conflict that waits for the actual version', () {
    testWidgets('buttons are disabled with a hint until the event arrives', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 200),
        announceConflicts: false,
      );
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'theirs',
        actorId: DemoIds.maxim,
      );
      await tester.enterText(descriptionField, 'mine');
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await openCardSheet(tester);

      expect(find.byType(ConflictBanner), findsOneWidget);
      expect(find.text('Загружаем актуальную версию…'), findsOneWidget);
      expect(_buttonEnabled(tester, 'Перезаписать'), isFalse);
      expect(_buttonEnabled(tester, 'Отменить'), isFalse);
      expect(containerOf(tester).read(cardDraftsProvider)[_card]!.text, 'mine');

      gateway.publishCard(_card);
      await tester.pump();
      expect(find.text('Загружаем актуальную версию…'), findsNothing);
      expect(_buttonEnabled(tester, 'Перезаписать'), isTrue);
      expect(_buttonEnabled(tester, 'Отменить'), isTrue);

      await tester.tap(find.text('Перезаписать'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.serverBoard.cardById(_card)!.description, 'mine');
      expect(find.byType(ConflictBanner), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel after the event shows the actual server text', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 200),
        announceConflicts: false,
      );
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'theirs',
        actorId: DemoIds.maxim,
      );
      await tester.enterText(descriptionField, 'mine');
      await tester.pump();
      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await openCardSheet(tester);
      gateway.publishCard(_card);
      await tester.pump();
      await tester.tap(find.text('Отменить'));
      await tester.pump();
      expect(find.byType(ConflictBanner), findsNothing);
      expect(find.text('theirs'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('unsaved text of an archived card', () {
    testWidgets('is offered for copying', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
      await pumpBoard(tester);
      final container = containerOf(tester);
      container.read(cardDraftsProvider.notifier).edit(_card, 'precious');
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      await _pumpFor(tester, 300);

      expect(
        find.text('Карточка в архиве. Ваш текст не сохранён.'),
        findsOneWidget,
      );
      expect(find.text('Скопировать'), findsOneWidget);
      expect(container.read(lostDraftProvider), isNull);

      await tester.tap(find.text('Скопировать'));
      await tester.pump();
      expect(copied, 'precious');
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the open sheet closes and the notice stays', (tester) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'unsaved words');
      await tester.pump();
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .archiveCard(_card);
      await _pumpFor(tester, 800);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CardSheet), findsNothing);
      expect(
        find.text('Карточка в архиве. Ваш текст не сохранён.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility and style details', () {
    testWidgets('the description field exposes a single text field node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBoard(tester);
      await openCardSheet(tester);
      final root = tester.getSemantics(find.byType(CardSheet));
      expect(_textFieldNodes(root), 1);
      final node = tester.getSemantics(descriptionField);
      expect(node.label, contains('Описание'));
      handle.dispose();
    });

    testWidgets('the panel field uses line height 1.6', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(find.text(_title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CardDetailPanel), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(CardDetailPanel),
          matching: find.byType(TextField),
        ),
      );
      expect(field.style!.height, 1.6);
      expect(field.style!.fontSize, 14);
    });
  });
}
