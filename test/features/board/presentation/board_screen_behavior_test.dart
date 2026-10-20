import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/board_column.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';

final Finder _rankTitle = find.text('Fractional indexing для rank');

Finder _addButton(String columnId) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is BoardColumnView && w.data.column.id == columnId,
    ),
    matching: find.text('Добавить карточку'),
  );
}

Future<void> _scrollToFooter(WidgetTester tester) async {
  await tester.fling(_item('c-rate-limit'), const Offset(0, -1500), 3000);
  await tester.pump(const Duration(seconds: 1));
}

Finder _item(String cardId) => find.byKey(ValueKey<String>('item-$cardId'));

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

BoardSyncState _state(WidgetTester tester) {
  return containerOf(tester).read(boardNotifierProvider);
}

Map<String, int> _customActions(WidgetTester tester, Finder finder) {
  final data = tester.getSemantics(finder).getSemanticsData();
  final ids = data.customSemanticsActionIds ?? const <int>[];
  return <String, int>{
    for (final id in ids) CustomSemanticsAction.getAction(id)!.label!: id,
  };
}

void main() {
  const viewerBanner =
      'Вы наблюдатель: можно смотреть, но не менять. '
      'Права выдаёт владелец — Максим.';

  final sizes = <String, Size>{
    'compact': compactSize,
    'medium': mediumSize,
    'expanded': expandedSize,
  };

  group('viewer', () {
    for (final entry in sizes.entries) {
      testWidgets('${entry.key}: banner, no add buttons, no draggables', (
        tester,
      ) async {
        await pumpBoard(tester, size: entry.value, role: BoardRole.viewer);
        expect(find.text(viewerBanner), findsOneWidget);
        expect(find.text('Добавить карточку'), findsNothing);
        expect(find.text('Колонка'), findsNothing);
        expect(find.byTooltip('Меню доски'), findsNothing);
        expect(find.text('Пригласить'), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is LongPressDraggable),
          findsNothing,
        );
        expect(find.byType(DragTarget<CardDragData>), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key}: editor sees the add button and draggables', (
        tester,
      ) async {
        await pumpBoard(tester, size: entry.value);
        expect(find.text(viewerBanner), findsNothing);
        expect(find.text('Добавить карточку'), findsWidgets);
        expect(
          find.byWidgetPredicate((w) => w is LongPressDraggable),
          findsWidgets,
        );
      });
    }

    testWidgets('long press does not start a drag', (tester) async {
      await pumpBoard(tester, size: expandedSize, role: BoardRole.viewer);
      final gesture = await tester.startGesture(
        tester.getCenter(_item(DemoIds.rankCard)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump();
      expect(find.byType(CardDropPlaceholder), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(_state(tester).pending, isEmpty);
      await _finish(tester);
    });

    testWidgets('can still open the detail panel', (tester) async {
      await pumpBoard(tester, size: expandedSize, role: BoardRole.viewer);
      await tester.tap(find.text('Fractional indexing для rank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Закрыть'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('cards expose no move actions', (tester) async {
      await pumpBoard(tester, role: BoardRole.viewer);
      final handle = tester.ensureSemantics();
      expect(
        _customActions(
          tester,
          find.text('Rate limit на логин: 5 попыток в минуту'),
        ),
        isEmpty,
      );
      handle.dispose();
      await _finish(tester);
    });
  });

  group('nack feedback', () {
    testWidgets('version conflict: snackbar with dismiss and rejected card', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(confirmDelay: confirmDelay);
      await pumpBoard(tester, size: expandedSize, gateway: gateway);
      gateway.simulateRemoteMove(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.done,
        actorId: DemoIds.maxim,
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: DemoIds.rankCard, toColumnId: DemoIds.review);
      await tester.pump();
      expect(find.text('В очереди'), findsOneWidget);

      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Карточку уже переместил Максим.'), findsNWidgets(2));
      expect(find.text('Понятно'), findsOneWidget);
      expect(find.text('Не применено'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Карточку уже переместил Максим.'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Понятно'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Не применено'), findsNothing);
      expect(_state(tester).pending, isEmpty);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('compact: version conflict snackbar names the author', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(confirmDelay: confirmDelay);
      await pumpBoard(tester, gateway: gateway);
      gateway.simulateRemoteMove(
        cardId: 'c-audit',
        toColumnId: DemoIds.done,
        actorId: DemoIds.maxim,
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.review);
      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Карточку уже переместил Максим.'), findsOneWidget);
      expect(find.text('Понятно'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('forbidden: snackbar without dismiss', (tester) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => const OpRejection(reason: NackReason.forbidden),
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-rate-limit', toColumnId: DemoIds.review);
      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Нет прав на это действие.'), findsOneWidget);
      expect(find.text('Понятно'), findsNothing);
      await _finish(tester);
    });

    testWidgets('internal: retry message, then the final one', (tester) async {
      await pumpBoard(
        tester,
        rejectWhen: (op) => const OpRejection(reason: NackReason.internal),
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-rate-limit', toColumnId: DemoIds.review);
      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Не удалось сохранить. Пробуем ещё раз…'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(confirmDelay + const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(confirmDelay + const Duration(milliseconds: 350));
      expect(find.text('Не удалось сохранить изменение.'), findsOneWidget);
      expect(_state(tester).pending.single.isRejected, isTrue);
      await _finish(tester);
    });

    testWidgets('rejected cards are not draggable', (tester) async {
      await pumpBoard(
        tester,
        size: expandedSize,
        rejectWhen: (op) => const OpRejection(reason: NackReason.notFound),
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-rate-limit', toColumnId: DemoIds.review);
      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Не применено'), findsOneWidget);
      expect(
        find.descendant(
          of: _item('c-rate-limit'),
          matching: find.byWidgetPredicate((w) => w is LongPressDraggable),
        ),
        findsNothing,
      );
      await _finish(tester);
    });
  });

  group('semantics', () {
    testWidgets('card exposes move actions for the other columns', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final handle = tester.ensureSemantics();
      final actions = _customActions(tester, _rankTitle);
      expect(actions.keys.toSet(), <String>{
        'Переместить в «Бэклог»',
        'Переместить в «Ревью»',
        'Переместить в «Готово»',
      });
      handle.dispose();
      await _finish(tester);
    });

    testWidgets('performing the custom action queues a move to the end', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final handle = tester.ensureSemantics();
      final actions = _customActions(tester, _rankTitle);
      final node = tester.getSemantics(_rankTitle);
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        actions['Переместить в «Готово»'],
      );
      await tester.pump();
      final op = _state(tester).pending.single.op as MoveCard;
      expect(op.cardId, DemoIds.rankCard);
      expect(op.toColumnId, DemoIds.done);
      expect(op.afterId, 'c-roles');
      expect(op.beforeId, isNull);
      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_state(tester).pending, isEmpty);
      handle.dispose();
      await _finish(tester);
    });

    testWidgets('card carries the drag hint', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      final handle = tester.ensureSemantics();
      final data = tester.getSemantics(_rankTitle).getSemanticsData();
      expect(data.hint, contains('Удерживайте, чтобы перетащить'));
      handle.dispose();
      await _finish(tester);
    });

    testWidgets('columns are labelled', (tester) async {
      await pumpBoard(tester, size: mediumSize);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Колонка «Бэклог»'), findsOneWidget);
      handle.dispose();
      await _finish(tester);
    });
  });

  group('actions', () {
    testWidgets('add card dialog queues and confirms a new card', (
      tester,
    ) async {
      await pumpBoard(tester);
      await _scrollToFooter(tester);
      await tester.tap(_addButton(DemoIds.backlog));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Новая карточка'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Проверить nack');
      await tester.pump();
      await tester.tap(find.text('Добавить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final op = _state(tester).pending.single.op as CreateCard;
      expect(op.title, 'Проверить nack');
      expect(op.columnId, DemoIds.backlog);
      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_state(tester).pending, isEmpty);
      expect(
        containerOf(tester)
            .read(boardViewProvider)
            .cardsIn(DemoIds.backlog)
            .last
            .title,
        'Проверить nack',
      );
      await _finish(tester);
    });

    testWidgets('cancelling the dialog creates nothing', (tester) async {
      await pumpBoard(tester);
      await _scrollToFooter(tester);
      await tester.tap(_addButton(DemoIds.backlog));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Отменить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_state(tester).pending, isEmpty);
      await _finish(tester);
    });

    testWidgets('detail panel Move menu moves the card', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(find.text('Fractional indexing для rank'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Переместить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Переместить в «Ревью»'));
      await tester.pump();
      final op = _state(tester).pending.single.op as MoveCard;
      expect(op.cardId, DemoIds.rankCard);
      expect(op.toColumnId, DemoIds.review);
      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_state(tester).pending, isEmpty);
      await _finish(tester);
    });

    testWidgets('panel disables Move and Archive while the card is rejected', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        size: expandedSize,
        rejectWhen: (op) => const OpRejection(
          reason: NackReason.versionConflict,
          actorId: DemoIds.maxim,
        ),
      );
      await tester.tap(_rankTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      bool moveEnabled() => tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Переместить'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .enabled;
      bool archiveEnabled() =>
          tester
              .widget<IconButton>(
                find
                    .ancestor(
                      of: find.byTooltip('В архив'),
                      matching: find.byType(IconButton),
                    )
                    .first,
              )
              .onPressed !=
          null;
      expect(moveEnabled(), isTrue);
      expect(archiveEnabled(), isTrue);

      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(
            cardId: DemoIds.rankCard,
            toColumnId: DemoIds.review,
          );
      await tester.pump();
      await tester.pump(confirmDelay + const Duration(milliseconds: 50));
      await tester.pump();
      expect(
        _state(tester).cardStatus(DemoIds.rankCard),
        CardSyncStatus.rejected,
      );
      expect(moveEnabled(), isFalse);
      expect(archiveEnabled(), isFalse);

      await tester.pump(const Duration(seconds: 3));
      expect(_state(tester).pending, isEmpty);
      expect(moveEnabled(), isTrue);
      expect(archiveEnabled(), isTrue);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('placeholder actions show the coming soon snackbar', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(find.text('Участники'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Появится в следующих версиях'), findsOneWidget);
      await _finish(tester);
    });
  });
}
