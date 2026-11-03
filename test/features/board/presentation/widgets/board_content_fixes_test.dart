import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_inline_state.dart';
import 'package:cardo/features/board/presentation/widgets/board_card_item.dart';
import 'package:cardo/features/board/presentation/widgets/board_column_header.dart';
import 'package:cardo/features/board/presentation/widgets/card_composer.dart';
import 'package:cardo/features/board/presentation/widgets/card_inline_title_editor.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/column_menu_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/column_tabs.dart';
import 'package:cardo/features/board/presentation/widgets/compact_board.dart';
import 'package:cardo/features/board/presentation/widgets/compact_board_parts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_board.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

FakeBoardGateway _gateway({Duration? delay}) => FakeBoardGateway(
  initial: demoBoardSnapshot(),
  confirmDelay: delay ?? const Duration(milliseconds: 50),
);

BoardSyncState _state(WidgetTester tester) =>
    containerOf(tester).read(boardNotifierProvider);

Future<String> _createColumn(WidgetTester tester, String title) async {
  final before = _state(tester).liveView.orderedColumns
      .map((column) => column.id)
      .toSet();
  final chip = find.text('Колонка');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(find.byType(TextField).last, title);
  await tester.pump();
  await tester.tap(find.byIcon(LucideIcons.check));
  await _settle(tester);
  return _state(tester).liveView.orderedColumns
      .map((column) => column.id)
      .firstWhere((id) => !before.contains(id));
}

Finder get _composerField => find.descendant(
  of: find.byType(CardComposer),
  matching: find.byType(TextField),
);

Finder get _composerSubmit => find.descendant(
  of: find.byType(CardComposer),
  matching: find.byType(FilledButton),
);

Future<void> _openComposerInLastColumn(WidgetTester tester) async {
  final add = find.text('Добавить карточку');
  await tester.ensureVisible(add.last);
  await tester.pump();
  await tester.tap(add.last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

EditableText _composerEditable(WidgetTester tester) {
  return tester.widget<EditableText>(
    find
        .descendant(
          of: find.byType(CardComposer),
          matching: find.byType(EditableText),
        )
        .first,
  );
}

int _dots(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

List<String> _tabs(WidgetTester tester) => [
  for (final view in containerOf(tester).read(boardColumnsProvider))
    view.column.title,
];

void main() {
  group('wide drop into an empty column', () {
    for (final shift in <Offset>[Offset.zero, const Offset(1, 1)]) {
      testWidgets(
        'a drop on the add button lands in the column (shift $shift)',
        (tester) async {
          await pumpBoard(tester, size: expandedSize, gateway: _gateway());
          final columns = _state(tester).liveView.orderedColumns;
          final notifier = containerOf(tester)
              .read(boardNotifierProvider.notifier);
          notifier.archiveColumn(columns[2].id);
          notifier.archiveColumn(columns[3].id);
          await _settle(tester);
          final columnId = await _createColumn(tester, 'Новая');
          await tester.pump(const Duration(seconds: 1));
          final add = tester.getCenter(find.text('Добавить карточку').last);

          final card = find.byType(BoardCardItem).first;
          final cardId = tester.widget<BoardCardItem>(card).data.card.id;
          final gesture = await tester.startGesture(tester.getCenter(card));
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 50),
          );
          await gesture.moveTo(add);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            containerOf(tester).read(boardDragProvider)?.targetColumnId,
            columnId,
          );
          if (shift != Offset.zero) {
            await gesture.moveBy(shift);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          await gesture.up();
          await tester.pump();
          await _settle(tester);

          expect(_state(tester).liveView.cardById(cardId)!.columnId, columnId);
          await _finish(tester);
        },
      );
    }
  });

  group('composer geometry on compact', () {
    Future<void> openAndCheck(WidgetTester tester) async {
      await tester.fling(
        find.byType(BoardCardItem).first,
        const Offset(0, -2500),
        3000,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Добавить карточку').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      final submit = tester.getRect(_composerSubmit);
      final fadeTop = tester.getTopLeft(find.byType(BottomFade)).dy;
      expect(submit.bottom, lessThanOrEqualTo(fadeTop));
    }

    testWidgets('the submit button stays above the bottom fade', (
      tester,
    ) async {
      await pumpBoard(tester);
      await openAndCheck(tester);
      await _finish(tester);
    });

    testWidgets('and above it when the keyboard opens after the composer', (
      tester,
    ) async {
      await pumpBoard(tester);
      addTearDown(tester.view.resetViewInsets);
      await tester.fling(
        find.byType(BoardCardItem).first,
        const Offset(0, -2500),
        3000,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Добавить карточку').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(const Duration(seconds: 1));
      final submit = tester.getRect(_composerSubmit);
      final fadeTop = tester.getTopLeft(find.byType(BottomFade)).dy;
      expect(submit.bottom, lessThanOrEqualTo(fadeTop));
      await _finish(tester);
    });

    testWidgets('typing a long description keeps the button visible', (
      tester,
    ) async {
      await pumpBoard(tester);
      await openAndCheck(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CardComposer),
          matching: find.text('Описание'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        _composerField.last,
        List.filled(8, 'строка').join('\n'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(const Duration(seconds: 1));
      final submit = tester.getRect(_composerSubmit);
      final fadeTop = tester.getTopLeft(find.byType(BottomFade)).dy;
      expect(submit.bottom, lessThanOrEqualTo(fadeTop));
      await _finish(tester);
    });
  });

  group('text is counted in code points', () {
    testWidgets('6000 emoji in a description make a card', (tester) async {
      await pumpBoard(tester);
      final container = containerOf(tester);
      final notifier = container.read(boardNotifierProvider.notifier);
      final column = _state(tester).liveView.orderedColumns.first.id;
      final before = _state(tester).pending.length;

      final created = notifier.createCard(
        columnId: column,
        title: 'T',
        description: '😀' * 6000,
      );

      expect(created, isTrue);
      expect(_state(tester).pending.length, before + 1);
      await _finish(tester);
    });

    testWidgets('10001 code points are refused and reported', (tester) async {
      await pumpBoard(tester);
      final notifier = containerOf(tester).read(boardNotifierProvider.notifier);
      final column = _state(tester).liveView.orderedColumns.first.id;
      final before = _state(tester).pending.length;

      final created = notifier.createCard(
        columnId: column,
        title: 'T',
        description: '😀' * 10001,
      );

      expect(created, isFalse);
      expect(_state(tester).pending.length, before);
      await _finish(tester);
    });

    testWidgets('editing a description of 6000 emoji is accepted', (
      tester,
    ) async {
      await pumpBoard(tester);
      final notifier = containerOf(tester).read(boardNotifierProvider.notifier);
      final card = _state(tester).liveView.cardsIn(DemoIds.backlog).first;

      final opId = notifier.editCardDescription(
        cardId: card.id,
        description: '😀' * 6000,
        baseDescriptionVersion: card.descriptionVersion,
      );

      expect(opId, isNotNull);
      await _finish(tester);
    });

    testWidgets('a submit into a rejected column keeps what was typed', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 50),
        rejectWhen: (op) => op is CreateColumn
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await pumpBoard(tester, gateway: gateway);
      final notifier = containerOf(tester).read(boardNotifierProvider.notifier);
      final columnId = notifier.createColumn('Плохая')!;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(_state(tester).liveView.columnById(columnId), isNull);
      final tab = find.widgetWithText(ColumnTab, 'Плохая');
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 600));
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .openComposer(columnId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(_composerField.first, 'Не терять');
      await tester.pump();
      final pending = _state(tester).pending.length;

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(_state(tester).pending.length, pending);
      expect(_composerEditable(tester).controller.text, 'Не терять');
      expect(
        containerOf(tester).read(cardInlineProvider).composerTitle,
        'Не терять',
      );
      await _finish(tester);
    });
  });

  group('drafts per column', () {
    testWidgets('opening another column keeps the first draft', (tester) async {
      await pumpBoard(tester);
      final inline = containerOf(tester).read(cardInlineProvider.notifier);

      inline.openComposer('a');
      inline.setComposer(title: 'typed', description: 'body');
      inline.toggleComposerDescription();
      inline.openComposer('b');

      var state = containerOf(tester).read(cardInlineProvider);
      expect(state.composerColumnId, 'b');
      expect(state.composerTitle, '');
      expect(state.composerDescription, '');
      expect(state.composerDescriptionOpen, isFalse);

      inline.setComposer(title: 'other');
      inline.openComposer('a');
      state = containerOf(tester).read(cardInlineProvider);
      expect(state.composerTitle, 'typed');
      expect(state.composerDescription, 'body');
      expect(state.composerDescriptionOpen, isTrue);

      inline.openComposer('b');
      expect(
        containerOf(tester).read(cardInlineProvider).composerTitle,
        'other',
      );
      await _finish(tester);
    });

    testWidgets('cancelling drops only the open draft', (tester) async {
      await pumpBoard(tester);
      final inline = containerOf(tester).read(cardInlineProvider.notifier);
      inline.openComposer('a');
      inline.setComposer(title: 'kept');
      inline.openComposer('b');
      inline.setComposer(title: 'dropped');
      inline.closeComposer();

      inline.openComposer('b');
      expect(containerOf(tester).read(cardInlineProvider).composerTitle, '');
      inline.openComposer('a');
      expect(
        containerOf(tester).read(cardInlineProvider).composerTitle,
        'kept',
      );
      await _finish(tester);
    });

    testWidgets('the form in the second column starts empty on screen', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final columns = _state(tester).liveView.orderedColumns;
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .openComposer(columns.first.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(_composerField.first, 'первая');
      await tester.pump();

      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .openComposer(columns[1].id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_composerEditable(tester).controller.text, '');

      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .openComposer(columns.first.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_composerEditable(tester).controller.text, 'первая');
      await _finish(tester);
    });
  });

  group('column sheet', () {
    testWidgets('closes when the role drops to viewer', (tester) async {
      final gateway = _gateway();
      await pumpBoard(tester, gateway: gateway);
      await tester.tap(find.byType(ColumnMenuButton).hitTestable().first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ColumnMenuSheet), findsOneWidget);

      gateway.server.changeRole(
        containerOf(tester).read(currentUserProvider).userId,
        BoardRole.viewer,
      );
      await _settle(tester);

      expect(find.byType(ColumnMenuSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('closes when the selected column is archived remotely', (
      tester,
    ) async {
      final gateway = _gateway();
      await pumpBoard(tester, gateway: gateway);
      final columns = _state(tester).liveView.orderedColumns;
      final tab = find.widgetWithText(ColumnTab, columns[2].title);
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await _settle(tester);
      await tester.tap(find.byType(ColumnMenuButton).hitTestable().first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ColumnMenuSheet), findsOneWidget);

      gateway.server.commitRemote(
        ArchiveColumn(opId: 'remote-archive', columnId: columns[2].id),
        actorId: 'u2',
        deliver: true,
      );
      await _settle(tester);

      expect(find.byType(ColumnMenuSheet), findsNothing);
      expect(_tabs(tester), isNot(contains(columns[2].title)));
      expect(_dots(tester), lessThan(_tabs(tester).length));
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('stays open when a column is created remotely', (tester) async {
      final gateway = _gateway();
      await pumpBoard(tester, gateway: gateway);
      final columns = _state(tester).liveView.orderedColumns;
      final tab = find.widgetWithText(ColumnTab, columns[1].title);
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await _settle(tester);
      final selected = _tabs(tester)[_dots(tester)];
      await tester.tap(find.byType(ColumnMenuButton).hitTestable().first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      gateway.server.commitRemote(
        const CreateColumn(
          opId: 'remote-create',
          columnId: 'remote-col',
          title: 'Remote',
          afterId: DemoIds.done,
        ),
        actorId: 'u2',
        deliver: true,
      );
      await _settle(tester);

      expect(find.byType(ColumnMenuSheet), findsOneWidget);
      expect(_tabs(tester), contains('Remote'));
      expect(_tabs(tester)[_dots(tester)], selected);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('single-line titles', () {
    testWidgets('a pasted line break in the composer title becomes a space', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .openComposer(_state(tester).liveView.orderedColumns.first.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(_composerField.first, 'a\nb\tc');
      await tester.pump();

      expect(_composerEditable(tester).controller.text, 'a b c');
      expect(
        containerOf(tester).read(cardInlineProvider).composerTitle,
        'a b c',
      );
      await _finish(tester);
    });

    testWidgets('the composer description keeps its line breaks', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final inline = containerOf(tester).read(cardInlineProvider.notifier);
      inline.openComposer(_state(tester).liveView.orderedColumns.first.id);
      inline.toggleComposerDescription();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(_composerField.last, 'a\nb');
      await tester.pump();

      expect(
        containerOf(tester).read(cardInlineProvider).composerDescription,
        'a\nb',
      );
      await _finish(tester);
    });

    testWidgets('the inline title editor replaces line breaks', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      final card = _state(tester).liveView.cardsIn(DemoIds.backlog).first;
      containerOf(tester)
          .read(cardInlineProvider.notifier)
          .startEditing(card.id, card.title);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final field = find.descendant(
        of: find.byType(CardInlineTitleEditor),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'x\ny');
      await tester.pump();

      expect(containerOf(tester).read(cardInlineProvider).editingTitle, 'x y');
      await _finish(tester);
    });
  });

  group('empty column composer', () {
    testWidgets('the form and focus stay after the first card', (tester) async {
      await pumpBoard(tester, gateway: _gateway());
      final columnId = await _createColumn(tester, 'Новая');
      await _openComposerInLastColumn(tester);
      expect(find.byType(CardComposer), findsOneWidget);

      await tester.enterText(_composerField.first, 'первая');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await _settle(tester);

      expect(_state(tester).liveView.cardsIn(columnId), hasLength(1));
      expect(find.byType(CardComposer), findsOneWidget);
      expect(_composerEditable(tester).controller.text, '');
      expect(_composerEditable(tester).focusNode.hasFocus, isTrue);
      await _finish(tester);
    });
  });

  group('card sheet on compact', () {
    testWidgets('the pencil starts the title edit on the board', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.tap(find.byType(BoardCardItem).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CardSheet), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.pencil));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(CardSheet), findsNothing);
      final field = find.descendant(
        of: find.byType(CardInlineTitleEditor),
        matching: find.byType(EditableText),
      );
      expect(field, findsOneWidget);
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });
}
