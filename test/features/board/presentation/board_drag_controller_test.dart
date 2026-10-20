import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

BoardDragState _drag({
  String card = 'c',
  String from = 'x',
  String target = 'x',
  int index = 0,
}) {
  return BoardDragState(
    cardId: card,
    fromColumnId: from,
    targetColumnId: target,
    targetIndex: index,
  );
}

ProviderContainer _container(ControlledGateway gateway) {
  final container = makeContainer(gateway: gateway);
  container.listen(boardNotifierProvider, (previous, next) {});
  return container;
}

void main() {
  group('hoverIndexForCard', () {
    test('without a drag the index is the card index', () {
      expect(hoverIndexForCard(current: null, columnId: 'x', cardIndex: 3), 3);
    });

    test('another column keeps the card index', () {
      expect(
        hoverIndexForCard(
          current: _drag(target: 'y', index: 1),
          columnId: 'x',
          cardIndex: 3,
        ),
        3,
      );
    });

    test('placeholder above the hovered card moves below it', () {
      expect(
        hoverIndexForCard(
          current: _drag(index: 2),
          columnId: 'x',
          cardIndex: 2,
        ),
        3,
      );
      expect(
        hoverIndexForCard(
          current: _drag(index: 0),
          columnId: 'x',
          cardIndex: 4,
        ),
        5,
      );
    });

    test('placeholder below the hovered card moves above it', () {
      expect(
        hoverIndexForCard(
          current: _drag(index: 4),
          columnId: 'x',
          cardIndex: 1,
        ),
        1,
      );
    });

    test('hovering the card just above the placeholder swaps above it', () {
      expect(
        hoverIndexForCard(
          current: _drag(index: 3),
          columnId: 'x',
          cardIndex: 2,
        ),
        2,
      );
    });
  });

  group('BoardDragState', () {
    test('retarget keeps the source and replaces the target', () {
      final next = _drag(from: 'a', target: 'a', index: 1).retarget('b', 4);
      expect(next.cardId, 'c');
      expect(next.fromColumnId, 'a');
      expect(next.targetColumnId, 'b');
      expect(next.targetIndex, 4);
    });

    test('value equality', () {
      expect(_drag(), _drag());
      expect(_drag().hashCode, _drag().hashCode);
      expect(_drag(index: 1), isNot(_drag()));
      const data = CardDragData(cardId: 'c', fromColumnId: 'x');
      expect(data, const CardDragData(cardId: 'c', fromColumnId: 'x'));
      expect(
        data.hashCode,
        const CardDragData(cardId: 'c', fromColumnId: 'x').hashCode,
      );
    });
  });

  group('BoardDragController', () {
    late ControlledGateway gateway;
    late ProviderContainer container;
    late BoardDragController controller;

    setUp(() {
      gateway = ControlledGateway();
      container = _container(gateway);
      controller = container.read(boardDragProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('starts idle', () {
      expect(container.read(boardDragProvider), isNull);
    });

    test('start targets the source slot', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      expect(
        container.read(boardDragProvider),
        BoardDragState(
          cardId: DemoIds.rankCard,
          fromColumnId: DemoIds.inProgress,
          targetColumnId: DemoIds.inProgress,
          targetIndex: 1,
        ),
      );
    });

    test('hover and hoverEnd are ignored without a drag', () {
      controller.hoverCard(columnId: DemoIds.review, cardIndex: 1);
      controller.hoverEnd(columnId: DemoIds.review, length: 3);
      expect(container.read(boardDragProvider), isNull);
    });

    test('hovering a card in another column targets its index', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverCard(columnId: DemoIds.review, cardIndex: 2);
      final state = container.read(boardDragProvider)!;
      expect(state.targetColumnId, DemoIds.review);
      expect(state.targetIndex, 2);
      expect(state.fromColumnId, DemoIds.inProgress);
    });

    test('hoverEnd targets the end of the column', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      final state = container.read(boardDragProvider)!;
      expect(state.targetColumnId, DemoIds.done);
      expect(state.targetIndex, 12);
    });

    test('identical hover does not emit a new state', () {
      var emissions = 0;
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      container.listen(boardDragProvider, (previous, next) => emissions++);
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      expect(emissions, 1);
    });

    test('placeholder does not jump while the pointer stays on one card', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.review,
        index: 0,
      );
      controller.hoverCard(columnId: DemoIds.review, cardIndex: 1);
      final settled = container.read(boardDragProvider)!.targetIndex;
      expect(settled, 2);
      final seen = <int>{settled};
      container.listen(
        boardDragProvider,
        (previous, next) => seen.add(next!.targetIndex),
      );
      controller.hoverEnd(columnId: DemoIds.review, length: 2);
      expect(container.read(boardDragProvider)!.targetIndex, 2);
      expect(seen, <int>{2});
    });

    test('drop to another column creates a move with neighbours', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverCard(columnId: DemoIds.review, cardIndex: 1);
      controller.drop();
      expect(container.read(boardDragProvider), isNull);
      final pending = container.read(boardNotifierProvider).pending;
      expect(pending.length, 1);
      final op = pending.single.op as MoveCard;
      expect(op.cardId, DemoIds.rankCard);
      expect(op.toColumnId, DemoIds.review);
      expect(op.afterId, 'c-refresh');
      expect(op.beforeId, 'c-presence');
      expect(op.baseVersion, 3);
    });

    test('drop to the end of a column anchors on the last card', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      controller.drop();
      final op =
          container.read(boardNotifierProvider).pending.single.op as MoveCard;
      expect(op.afterId, 'c-roles');
      expect(op.beforeId, isNull);
    });

    test('drop to an empty target slot index zero', () {
      controller.start(cardId: 'c-audit', columnId: DemoIds.backlog, index: 5);
      controller.hoverCard(columnId: DemoIds.done, cardIndex: 0);
      controller.drop();
      final op =
          container.read(boardNotifierProvider).pending.single.op as MoveCard;
      expect(op.afterId, isNull);
      expect(op.beforeId, 'c-migrations');
    });

    test('reorder downward inside a column', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverCard(columnId: DemoIds.inProgress, cardIndex: 2);
      expect(container.read(boardDragProvider)!.targetIndex, 3);
      controller.drop();
      final op =
          container.read(boardNotifierProvider).pending.single.op as MoveCard;
      expect(op.afterId, DemoIds.syncStateCard);
      expect(op.beforeId, isNull);
    });

    test('reorder upward inside a column', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverCard(columnId: DemoIds.inProgress, cardIndex: 0);
      expect(container.read(boardDragProvider)!.targetIndex, 0);
      controller.drop();
      final op =
          container.read(boardNotifierProvider).pending.single.op as MoveCard;
      expect(op.afterId, isNull);
      expect(op.beforeId, DemoIds.handshakeCard);
    });

    test('drop on the original slot creates no operation', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.drop();
      expect(container.read(boardDragProvider), isNull);
      expect(container.read(boardNotifierProvider).pending, isEmpty);
    });

    test('cancel clears the drag without an operation', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverEnd(columnId: DemoIds.done, length: 12);
      controller.cancel();
      expect(container.read(boardDragProvider), isNull);
      expect(container.read(boardNotifierProvider).pending, isEmpty);
    });

    test('hoverStart targets index zero in the source column', () {
      controller.start(
        cardId: DemoIds.handshakeCard,
        columnId: DemoIds.inProgress,
        index: 0,
      );
      controller.hoverCard(columnId: DemoIds.inProgress, cardIndex: 1);
      controller.hoverStart(columnId: DemoIds.inProgress);
      final state = container.read(boardDragProvider)!;
      expect(state.targetColumnId, DemoIds.inProgress);
      expect(state.targetIndex, 0);
      controller.drop();
      expect(container.read(boardNotifierProvider).pending, isEmpty);
    });

    test('hoverStart keeps the first slot when it is already the target', () {
      controller.start(
        cardId: DemoIds.handshakeCard,
        columnId: DemoIds.inProgress,
        index: 0,
      );
      controller.hoverStart(columnId: DemoIds.inProgress);
      expect(container.read(boardDragProvider)!.targetIndex, 0);
      controller.hoverCard(columnId: DemoIds.inProgress, cardIndex: 0);
      expect(container.read(boardDragProvider)!.targetIndex, 1);
      controller.hoverStart(columnId: DemoIds.inProgress);
      expect(container.read(boardDragProvider)!.targetIndex, 0);
    });

    test('hoverStart in another column targets its first slot', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      controller.hoverStart(columnId: DemoIds.review);
      controller.drop();
      final op = container.read(boardNotifierProvider).pending.single.op;
      expect(op, isA<MoveCard>());
      final move = op as MoveCard;
      expect(move.toColumnId, DemoIds.review);
      expect(move.afterId, isNull);
      expect(move.beforeId, 'c-refresh');
    });

    test('hoverStart is ignored without a drag', () {
      controller.hoverStart(columnId: DemoIds.review);
      expect(container.read(boardDragProvider), isNull);
    });

    test('drag is cancelled when the dragged card becomes rejected', () async {
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(
            cardId: DemoIds.rankCard,
            toColumnId: DemoIds.review,
          );
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.review,
        index: 3,
      );
      gateway.calls.single.completer.complete(
        OpRejected(rejection(NackReason.versionConflict)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(boardDragProvider), isNull);
      controller.drop();
      expect(container.read(boardNotifierProvider).pending, hasLength(1));
    });

    test('start is refused for a rejected card', () async {
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(
            cardId: DemoIds.rankCard,
            toColumnId: DemoIds.review,
          );
      gateway.calls.single.completer.complete(
        OpRejected(rejection(NackReason.versionConflict)),
      );
      await Future<void>.delayed(Duration.zero);
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.review,
        index: 3,
      );
      expect(container.read(boardDragProvider), isNull);
    });

    test('start is refused for an unknown card', () {
      controller.start(cardId: 'missing', columnId: DemoIds.review, index: 0);
      expect(container.read(boardDragProvider), isNull);
    });

    test('drag is cancelled when the dragged card is archived', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      container
          .read(boardNotifierProvider.notifier)
          .archiveCard(DemoIds.rankCard);
      expect(container.read(boardDragProvider), isNull);
    });

    test('drag survives unrelated board changes', () {
      controller.start(
        cardId: DemoIds.rankCard,
        columnId: DemoIds.inProgress,
        index: 1,
      );
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: 'c-audit', toColumnId: DemoIds.done);
      expect(container.read(boardDragProvider), isNotNull);
    });

    test('cancel and drop without a drag are harmless', () {
      controller.cancel();
      controller.drop();
      expect(container.read(boardDragProvider), isNull);
      expect(container.read(boardNotifierProvider).pending, isEmpty);
    });
  });
}
