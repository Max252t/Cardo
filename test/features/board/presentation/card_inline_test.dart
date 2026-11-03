import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/op_rejection.dart';
import 'package:cardo/features/board/domain/rejection_log.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_inline_state.dart';
import 'package:cardo/features/board/presentation/widgets/board_card_item.dart';
import 'package:cardo/features/board/presentation/widgets/card_composer.dart';
import 'package:cardo/features/board/presentation/widgets/card_inline_title_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';

Finder _item(String id) => find.byKey(ValueKey<String>('item-$id'));

Finder get _editorField => find.descendant(
  of: find.byType(CardInlineTitleEditor),
  matching: find.byType(TextField),
);

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.fling(
    find.byType(BoardCardItem).first,
    const Offset(0, -2500),
    3000,
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('Добавить карточку').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(CardComposer),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump();
  await tester.pump();
}

List<CreateCard> _creates(WidgetTester tester) {
  return [
    for (final item in containerOf(tester).read(boardNotifierProvider).pending)
      if (item.op is CreateCard) item.op as CreateCard,
  ];
}

void main() {
  group('rune limit and validation', () {
    test('formatter truncates by runes', () {
      const formatter = RuneLimitFormatter(3);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '😀😀😀😀'),
      );
      expect(result.text.runes.length, 3);
    });

    test('title validity trims, requires text, counts runes', () {
      expect(isValidCardTitle('   '), isFalse);
      expect(isValidCardTitle('  a  '), isTrue);
      expect(isValidCardTitle('😀' * 500), isTrue);
      expect(isValidCardTitle('😀' * 501), isFalse);
    });
  });

  group('composer', () {
    for (final entry in <String, Size>{
      'compact': compactSize,
      'medium': mediumSize,
      'expanded': expandedSize,
    }.entries) {
      testWidgets('${entry.key}: Enter creates trimmed card, stays open', (
        tester,
      ) async {
        await pumpBoard(tester, size: entry.value);
        await _openComposer(tester);
        expect(find.byType(CardComposer), findsOneWidget);
        await _type(tester, '   Первая   ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(_creates(tester).single.title, 'Первая');
        expect(find.byType(CardComposer), findsOneWidget);
        expect(find.text('Первая'), findsWidgets);
        await _type(tester, 'Вторая');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(_creates(tester).map((op) => op.title), ['Первая', 'Вторая']);
        await tester.pump(confirmDelay * 2);
        final column = containerOf(tester)
            .read(boardViewProvider)
            .cardsIn(DemoIds.backlog);
        expect(column.map((card) => card.title).toList().reversed.take(2), [
          'Вторая',
          'Первая',
        ]);
        await _finish(tester);
      });
    }

    testWidgets('empty and blank titles are not sent', (tester) async {
      await pumpBoard(tester);
      await _openComposer(tester);
      await _type(tester, '    ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_creates(tester), isEmpty);
      final add = find.widgetWithText(FilledButton, 'Добавить');
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      await _finish(tester);
    });

    testWidgets('over-long text is cut to 500 runes', (tester) async {
      await pumpBoard(tester);
      await _openComposer(tester);
      await _type(tester, 'я' * 600);
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      expect(_creates(tester).single.title.runes.length, 500);
      await _finish(tester);
    });

    testWidgets('description toggle sends description', (tester) async {
      await pumpBoard(tester);
      await _openComposer(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Описание'));
      await tester.pump();
      await tester.pump();
      final fields = find.descendant(
        of: find.byType(CardComposer),
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.first, 'Заголовок');
      await tester.enterText(fields.last, 'Подробности');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      final op = _creates(tester).single;
      expect(op.title, 'Заголовок');
      expect(op.description, 'Подробности');
      await _finish(tester);
    });

    testWidgets('cancel and Escape close without creating', (tester) async {
      await pumpBoard(tester);
      await _openComposer(tester);
      await _type(tester, 'Черновик');
      await tester.tap(find.text('Отмена'));
      await tester.pump();
      expect(find.byType(CardComposer), findsNothing);
      expect(_creates(tester), isEmpty);
      await tester.tap(find.text('Добавить карточку').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CardComposer), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(CardComposer), findsNothing);
      expect(_creates(tester), isEmpty);
      await _finish(tester);
    });

    testWidgets('draft survives scrolling the column away', (tester) async {
      await pumpBoard(tester);
      await _openComposer(tester);
      await _type(tester, 'Не потерять');
      await tester.drag(find.byType(CardComposer), const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.fling(_item('c-rate-limit'), const Offset(0, -1500), 3000);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Не потерять'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('server nack keeps the text in the rejection log', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is CreateCard
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await _openComposer(tester);
      await _type(tester, 'Потерянный текст');
      await tester.tap(find.widgetWithText(FilledButton, 'Добавить'));
      await tester.pump();
      await tester.pump(confirmDelay + const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      final log = containerOf(tester)
          .read(boardNotifierProvider)
          .rejections
          .entries;
      expect(log.single.kind, RejectedOpKind.create);
      expect(log.single.copyText, 'Потерянный текст');
      await _finish(tester);
    });

    testWidgets('viewer sees no add button, no composer', (tester) async {
      await pumpBoard(tester, role: BoardRole.viewer);
      expect(find.text('Добавить карточку'), findsNothing);
      expect(find.byType(CardComposer), findsNothing);
      await _finish(tester);
    });

    testWidgets('360x640 at text scale 2 has no overflow', (tester) async {
      await pumpBoard(tester, size: const Size(360, 640), textScale: 2);
      await _openComposer(tester);
      await _type(tester, 'Длинный заголовок для проверки переноса');
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('inline title edit', () {
    testWidgets('semantics action opens editor, save sends EditCardTitle', (
      tester,
    ) async {
      await pumpBoard(tester);
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .startEditing(DemoIds.rankCard, 'x');
      await tester.pump();
      await tester.pump();
      expect(find.byType(CardInlineTitleEditor), findsOneWidget);
      await tester.enterText(_editorField, '  Новый заголовок ');
      await tester.pump();
      await tester.tap(find.byTooltip('Сохранить заголовок'));
      await tester.pump();
      final ops = containerOf(tester)
          .read(boardNotifierProvider)
          .pending
          .map((item) => item.op)
          .whereType<EditCardTitle>()
          .toList();
      expect(ops.single.title, 'Новый заголовок');
      expect(find.byType(CardInlineTitleEditor), findsNothing);
      await _finish(tester);
    });

    testWidgets('cancel and Escape discard', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      final inline = containerOf(tester).read(cardInlineProvider.notifier);
      inline.startEditing(DemoIds.rankCard, 'x');
      await tester.pump();
      await tester.pump();
      await tester.enterText(_editorField, 'Другое');
      await tester.ensureVisible(find.byTooltip('Отменить правку'));
      await tester.pump();
      await tester.tap(find.byTooltip('Отменить правку'));
      await tester.pump();
      expect(find.byType(CardInlineTitleEditor), findsNothing);
      inline.startEditing(DemoIds.rankCard, 'x');
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(CardInlineTitleEditor), findsNothing);
      expect(
        containerOf(tester)
            .read(boardNotifierProvider)
            .pending
            .where((item) => item.op is EditCardTitle),
        isEmpty,
      );
      await _finish(tester);
    });

    testWidgets('viewer never gets the editor', (tester) async {
      await pumpBoard(tester, role: BoardRole.viewer);
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .startEditing(DemoIds.rankCard, 'x');
      await tester.pump();
      expect(find.byType(CardInlineTitleEditor), findsNothing);
      await _finish(tester);
    });

    testWidgets('panel pencil starts inline edit on the board', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(find.text('Fractional indexing для rank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Править заголовок на доске'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CardInlineTitleEditor), findsOneWidget);
      await _finish(tester);
    });
  });
}
