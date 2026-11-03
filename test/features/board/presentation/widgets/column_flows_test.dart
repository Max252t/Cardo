import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/board_column_header.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/column_menu_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/column_tabs.dart';
import 'package:cardo/features/board/presentation/widgets/compact_board.dart';
import 'package:cardo/features/board/presentation/widgets/new_column_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

BoardSyncState _state(WidgetTester tester) =>
    containerOf(tester).read(boardNotifierProvider);

List<String> _titles(WidgetTester tester) => [
  for (final column in _state(tester).liveView.orderedColumns) column.title,
];

int _dotsIndex(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

int _dotsCount(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).count;

Finder _menuButton(String columnId) => find.byWidgetPredicate(
  (widget) => widget is ColumnMenuButton && widget.column.id == columnId,
);

Finder get _nameInput => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is NewColumnField || widget is ColumnMenuSheet,
  ),
  matching: find.byType(TextField),
);

Future<void> _selectTab(WidgetTester tester, String title) async {
  final tab = find.widgetWithText(ColumnTab, title);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await _settle(tester);
}

Future<void> _openMenu(WidgetTester tester, String columnId) async {
  await tester.ensureVisible(_menuButton(columnId));
  await tester.tap(_menuButton(columnId));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(8, 8));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _create(WidgetTester tester, String title, String chip) async {
  final chipFinder = find.text(chip);
  await tester.ensureVisible(chipFinder);
  await tester.tap(chipFinder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(_nameInput, title);
  await tester.pump();
  await tester.tap(find.byIcon(LucideIcons.check));
  await _settle(tester);
}

void main() {
  group('new column on compact', () {
    testWidgets('the field in the tab row creates a column and opens it', (
      tester,
    ) async {
      await pumpBoard(tester);
      expect(_dotsCount(tester), 4);

      await _create(tester, '  Идеи  ', 'Колонка');

      expect(_titles(tester), [
        'Бэклог',
        'В работе',
        'Ревью',
        'Готово',
        'Идеи',
      ]);
      expect(_dotsCount(tester), 5);
      expect(_dotsIndex(tester), 4);
      expect(find.text('Колонка пуста', skipOffstage: false), findsOneWidget);
      expect(find.text('Добавить карточку'), findsWidgets);
      expect(find.byType(NewColumnField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(_state(tester).pending, isEmpty);
      expect(_state(tester).confirmed.orderedColumns.last.title, 'Идеи');
      await _finish(tester);
    });

    testWidgets('the check button is off until there is a name', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.ensureVisible(find.text('Колонка'));
      await tester.tap(find.text('Колонка'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NewColumnField), findsOneWidget);

      await tester.enterText(_nameInput, '   ');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.check));
      await tester.pump();
      expect(_state(tester).pending, isEmpty);
      expect(find.byType(NewColumnField), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(NewColumnField), findsNothing);
      await _finish(tester);
    });

    testWidgets('the confirm area is at least 44 points', (tester) async {
      await pumpBoard(tester);
      await tester.ensureVisible(find.text('Колонка'));
      await tester.tap(find.text('Колонка'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(_nameInput, 'А');
      await tester.pump();

      final size = tester.getSize(
        find.ancestor(
          of: find.byIcon(LucideIcons.check),
          matching: find.byType(InkResponse),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await _finish(tester);
    });

    testWidgets('a viewer has neither the field nor the menu', (tester) async {
      await pumpBoard(tester, role: BoardRole.viewer);
      expect(find.text('Колонка'), findsNothing);
      expect(find.byType(ColumnMenuButton), findsNothing);
      await _finish(tester);
    });

    testWidgets('a refused create shows the reason and drops the column', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is CreateColumn
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await _create(tester, 'Идеи', 'Колонка');
      await tester.pump(confirmDelay + const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Нет прав на это действие.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(_titles(tester), ['Бэклог', 'В работе', 'Ревью', 'Готово']);
      expect(_dotsCount(tester), 4);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('column menu on compact', () {
    testWidgets('rename is sent when the sheet closes', (tester) async {
      await pumpBoard(tester);
      await _openMenu(tester, DemoIds.backlog);
      expect(find.text('Название колонки'), findsOneWidget);

      await tester.enterText(_nameInput, '  План  ');
      await tester.pump();
      await _closeSheet(tester);

      expect(_titles(tester).first, 'План');
      expect(find.text('План'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });

    testWidgets('an unchanged name sends nothing', (tester) async {
      await pumpBoard(tester);
      await _openMenu(tester, DemoIds.backlog);
      await _closeSheet(tester);
      expect(_state(tester).pending, isEmpty);
      await _finish(tester);
    });

    testWidgets('move right keeps the same column selected', (tester) async {
      await pumpBoard(tester);
      await _openMenu(tester, DemoIds.backlog);

      final left = tester.widget<ColumnMenuItem>(
        find.widgetWithText(ColumnMenuItem, 'Сдвинуть левее'),
      );
      expect(left.onTap, isNull);

      await tester.tap(find.text('Сдвинуть правее'));
      await tester.pump();
      final op = _state(tester).pending.single.op as MoveColumn;
      expect(op.columnId, DemoIds.backlog);
      expect(op.afterId, DemoIds.inProgress);
      expect(op.beforeId, DemoIds.review);

      await _closeSheet(tester);
      await _settle(tester);
      expect(_titles(tester), ['В работе', 'Бэклог', 'Ревью', 'Готово']);
      expect(_dotsIndex(tester), 1);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });

    testWidgets('a column move refused by the server explains why', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => op is MoveColumn
            ? const OpRejection(reason: NackReason.versionConflict)
            : null,
      );
      await _openMenu(tester, DemoIds.backlog);
      await tester.tap(find.text('Сдвинуть правее'));
      await tester.pump(confirmDelay + const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Колонку уже переместил другой участник.'),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 4));
      await _finish(tester);
    });

    testWidgets('archive shows the card count and removes the column', (
      tester,
    ) async {
      await pumpBoard(tester);
      await _selectTab(tester, 'Ревью');
      await _settle(tester);
      expect(_dotsIndex(tester), 2);
      await _openMenu(tester, DemoIds.review);

      expect(find.text('Архивировать «Ревью»?'), findsOneWidget);
      expect(
        find.textContaining('3 карточки', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('В архив'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);

      await tester.tap(find.text('В архив'));
      await _settle(tester);

      expect(_titles(tester), ['Бэклог', 'В работе', 'Готово']);
      expect(_dotsCount(tester), 3);
      expect(_dotsIndex(tester), 2);
      expect(find.byType(ColumnMenuSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });

    testWidgets('archiving the last column keeps the page in range', (
      tester,
    ) async {
      await pumpBoard(tester);
      await _selectTab(tester, 'Готово');
      await _settle(tester);
      expect(_dotsIndex(tester), 3);
      await _openMenu(tester, DemoIds.done);
      await tester.tap(find.text('В архив'));
      await _settle(tester);

      expect(_dotsCount(tester), 3);
      expect(_dotsIndex(tester), 2);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });

    testWidgets('cancel leaves the column alone', (tester) async {
      await pumpBoard(tester);
      await _openMenu(tester, DemoIds.backlog);
      await tester.tap(find.text('Отмена'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_state(tester).pending, isEmpty);
      expect(find.byType(ColumnMenuSheet), findsNothing);
      await _finish(tester);
    });

    testWidgets('an open card sheet closes when its column is archived', (
      tester,
    ) async {
      await pumpBoard(tester);
      await openCardSheet(tester);
      expect(find.byType(CardSheet), findsOneWidget);

      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .archiveColumn(DemoIds.inProgress);
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);

      expect(find.byType(CardSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });
  });

  group('wide layouts', () {
    for (final size in <Size>[mediumSize, expandedSize]) {
      testWidgets('the + Column button works at ${size.width.toInt()}px', (
        tester,
      ) async {
        await pumpBoard(tester, size: size);
        expect(find.text('Колонка'), findsOneWidget);

        await tester.ensureVisible(find.text('Колонка'));
        await tester.tap(find.text('Колонка'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(_nameInput, 'Идеи');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);

        expect(_titles(tester).last, 'Идеи');
        expect(find.text('Идеи'), findsOneWidget);
        expect(find.byType(NewColumnField), findsNothing);
        expect(find.text('Колонка пуста', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
        await _finish(tester);
      });

      testWidgets('rename, move and archive from the menu at '
          '${size.width.toInt()}px', (tester) async {
        await pumpBoard(tester, size: size);
        await _openMenu(tester, DemoIds.review);
        await tester.enterText(_nameInput, 'QA');
        await tester.tap(find.text('Сдвинуть левее'));
        await tester.pump();
        await _closeSheet(tester);
        await _settle(tester);

        expect(_titles(tester), ['Бэклог', 'QA', 'В работе', 'Готово']);
        await _openMenu(tester, DemoIds.review);
        await tester.tap(find.text('В архив'));
        await _settle(tester);
        expect(_titles(tester), ['Бэклог', 'В работе', 'Готово']);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
        await _finish(tester);
      });

      testWidgets('a viewer sees no controls at ${size.width.toInt()}px', (
        tester,
      ) async {
        await pumpBoard(tester, size: size, role: BoardRole.viewer);
        expect(find.text('Колонка'), findsNothing);
        expect(find.byType(ColumnMenuButton), findsNothing);
        await _finish(tester);
      });
    }
  });

  group('small screen with large text', () {
    testWidgets('field and sheet fit on 360x640 at text scale 2', (
      tester,
    ) async {
      await pumpBoard(tester, size: const Size(360, 640), textScale: 2);
      await tester.ensureVisible(find.text('Колонка'));
      await tester.tap(find.text('Колонка'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byType(TextField),
        'Очень длинное имя колонки',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(LucideIcons.check));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      await _selectTab(tester, 'Бэклог');
      await _openMenu(tester, DemoIds.backlog);
      expect(find.text('В архив'), findsOneWidget);
      await tester.ensureVisible(find.text('В архив'));
      expect(tester.takeException(), isNull);
      await _closeSheet(tester);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });
  });

  group('english', () {
    testWidgets('texts of the new column, the menu and the archive block', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        locale: const Locale('en'),
        gateway: FakeBoardGateway(confirmDelay: confirmDelay),
      );
      await _create(tester, 'Ideas', 'Column');
      expect(find.text('Column is empty', skipOffstage: false), findsOneWidget);

      await _selectTab(tester, 'Ревью');
      await _openMenu(tester, DemoIds.review);
      expect(find.text('Column name'), findsOneWidget);
      expect(find.text('Move left'), findsOneWidget);
      expect(find.text('Move right'), findsOneWidget);
      expect(find.text('Archive “Ревью”?'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await _closeSheet(tester);
      await tester.pump(const Duration(seconds: 1));
      await _finish(tester);
    });
  });
}
