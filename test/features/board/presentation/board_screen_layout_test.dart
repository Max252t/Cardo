import 'dart:ui' show Tristate;

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/column_tabs.dart';
import 'package:cardo/features/board/presentation/widgets/compact_board.dart';
import 'package:cardo/features/board/presentation/widgets/scrolling_board.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';

void main() {
  final sizes = <String, Size>{
    'compact 375': compactSize,
    'medium 700': mediumSize,
    'expanded 1280': expandedSize,
  };

  for (final entry in sizes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in <double>[1.0, 2.0]) {
        testWidgets(
          'renders ${entry.key} ${brightness.name} x$scale without errors',
          (tester) async {
            await pumpBoard(
              tester,
              size: entry.value,
              brightness: brightness,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Запуск Cardo 1.0'), findsWidgets);
          },
        );
      }
    }
  }

  group('small heights at large text', () {
    const sizes = <Size>[Size(360, 640), Size(600, 500), Size(1024, 768)];
    for (final size in sizes) {
      for (final role in <BoardRole>[BoardRole.editor, BoardRole.viewer]) {
        for (final scale in <double>[1.0, 2.0]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} ${role.name} '
            'x$scale has no overflow',
            (tester) async {
              await pumpBoard(tester, size: size, role: role, textScale: scale);
              expect(tester.takeException(), isNull);
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull);
              expect(find.text('Запуск Cardo 1.0'), findsWidgets);
            },
          );
        }
      }
    }
  });

  group('compact', () {
    testWidgets('shows tabs, page view and page dots', (tester) async {
      await pumpBoard(tester);
      expect(find.byType(ColumnTabs), findsOneWidget);
      expect(find.byType(ColumnTab), findsNWidgets(4));
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(PageDots), findsOneWidget);
      expect(find.bySemanticsLabel('Колонка 1 из 4'), findsOneWidget);
      expect(find.text('Бэклог'), findsWidgets);
      expect(find.text('Добавить карточку'), findsWidgets);
      expect(find.text(AppLocalizationsRu().boardSeq(1284)), findsNothing);
    });

    testWidgets('next column peeks from the right edge', (tester) async {
      await pumpBoard(tester);
      final first = tester.getRect(
        find.byKey(const ValueKey<String>('item-c-rate-limit')),
      );
      expect(first.right, lessThan(375 - 16));
      expect(
        find.text('Handshake: last_seq → дельта или снапшот'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a tab selects the column and updates dots', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.ensureVisible(find.byType(ColumnTab).at(2));
      await tester.pump();
      await tester.tap(find.byType(ColumnTab).at(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.bySemanticsLabel('Колонка 3 из 4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('item-c-refresh')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('swiping the page view changes the selected tab', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.bySemanticsLabel('Колонка 2 из 4'), findsOneWidget);
    });

    testWidgets('tab semantics expose selected state', (tester) async {
      await pumpBoard(tester);
      final handle = tester.ensureSemantics();
      bool selected(int index) =>
          tester
              .getSemantics(find.byType(ColumnTab).at(index))
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(selected(0), isTrue);
      expect(selected(1), isFalse);
      await tester.tap(find.byType(ColumnTab).at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(selected(0), isFalse);
      expect(selected(1), isTrue);
      handle.dispose();
    });

    testWidgets('tapping a card opens a preview sheet', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Rate limit на логин: 5 попыток в минуту'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Описания пока нет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('medium', () {
    testWidgets('scrolls columns horizontally without tabs', (tester) async {
      await pumpBoard(tester, size: mediumSize);
      expect(find.byType(ColumnTabs), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(PageDots), findsNothing);
      expect(find.byType(ScrollingBoard), findsOneWidget);
      final scrollable = find.descendant(
        of: find.byType(ScrollingBoard),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsWidgets);
      expect(find.text('Бэклог'), findsOneWidget);
      expect(tester.getRect(find.text('Готово')).left, greaterThan(700));
      await tester.dragFrom(const Offset(500, 300), const Offset(-900, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.text('Готово')).left, lessThan(700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('has no sidebar and no detail panel', (tester) async {
      await pumpBoard(tester, size: mediumSize);
      expect(find.text('Новая доска'), findsNothing);
      expect(find.text('Поиск'), findsNothing);
    });

    testWidgets('boundary widths pick the right layout', (tester) async {
      await pumpBoard(tester, size: const Size(599, 800));
      expect(find.byType(ColumnTabs), findsOneWidget);
      await pumpBoard(tester, size: const Size(600, 800));
      expect(find.byType(ColumnTabs), findsNothing);
      expect(find.byType(ScrollingBoard), findsOneWidget);
      await pumpBoard(tester, size: const Size(839, 800));
      expect(find.text('Новая доска'), findsNothing);
      await pumpBoard(tester, size: const Size(840, 800));
      expect(find.text('Новая доска'), findsOneWidget);
    });
  });

  group('expanded', () {
    testWidgets('shows sidebar, header with seq, columns and no tabs', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      expect(find.byType(ColumnTabs), findsNothing);
      expect(find.text('Поиск'), findsOneWidget);
      expect(find.text('ДОСКИ'), findsOneWidget);
      expect(find.text('Новая доска'), findsOneWidget);
      expect(find.text('Контент-план, ноябрь'), findsOneWidget);
      expect(find.text('Ремонт кухни'), findsOneWidget);
      expect(find.text('В сети'), findsWidgets);
      expect(find.text(AppLocalizationsRu().boardSeq(1284)), findsOneWidget);
      expect(find.text('Участники'), findsOneWidget);
      expect(find.text('Пригласить'), findsOneWidget);
      expect(find.text('Колонка'), findsOneWidget);
      expect(find.text('Бэклог'), findsOneWidget);
      expect(find.text('Елена'), findsWidgets);
    });

    testWidgets('detail panel opens on card tap and closes', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      expect(find.text('Сохранить'), findsNothing);
      await tester.tap(find.text('Fractional indexing для rank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Сохранить'), findsOneWidget);
      expect(find.text('Переместить'), findsOneWidget);
      expect(find.byTooltip('В архив'), findsOneWidget);
      expect(find.text('Создал Аня'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      expect(containerOf(tester).read(selectedCardIdProvider), 'c-rank');

      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Сохранить'), findsNothing);
      expect(containerOf(tester).read(selectedCardIdProvider), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching cards swaps panel content', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(find.text('Fractional indexing для rank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('v3'), findsOneWidget);
      await tester.tap(find.text('Handshake: last_seq → дельта или снапшот'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('v14'), findsOneWidget);
      expect(find.text('v3'), findsNothing);
    });

    testWidgets('detail panel renders at text scale 2 in both themes', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpBoard(
          tester,
          size: expandedSize,
          textScale: 2,
          brightness: brightness,
        );
        containerOf(tester)
            .read(selectedCardIdProvider.notifier)
            .select('c-rank');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
