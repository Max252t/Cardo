import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_sync_state.dart';
import 'board_providers.dart';

bool isCardDraggable(BoardSyncState state, String cardId) {
  final card = state.liveView.cardById(cardId);
  return card != null &&
      !card.archived &&
      state.cardStatus(cardId) != CardSyncStatus.rejected;
}

@immutable
class CardDragData {
  const CardDragData({required this.cardId, required this.fromColumnId});

  final String cardId;
  final String fromColumnId;

  @override
  bool operator ==(Object other) {
    return other is CardDragData &&
        other.cardId == cardId &&
        other.fromColumnId == fromColumnId;
  }

  @override
  int get hashCode => Object.hash(cardId, fromColumnId);
}

@immutable
class BoardDragState {
  const BoardDragState({
    required this.cardId,
    required this.fromColumnId,
    required this.targetColumnId,
    required this.targetIndex,
  });

  final String cardId;
  final String fromColumnId;
  final String targetColumnId;
  final int targetIndex;

  BoardDragState retarget(String columnId, int index) {
    return BoardDragState(
      cardId: cardId,
      fromColumnId: fromColumnId,
      targetColumnId: columnId,
      targetIndex: index,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoardDragState &&
        other.cardId == cardId &&
        other.fromColumnId == fromColumnId &&
        other.targetColumnId == targetColumnId &&
        other.targetIndex == targetIndex;
  }

  @override
  int get hashCode =>
      Object.hash(cardId, fromColumnId, targetColumnId, targetIndex);

  @override
  String toString() =>
      'BoardDragState($cardId from $fromColumnId -> '
      '$targetColumnId[$targetIndex])';
}

int hoverIndexForCard({
  required BoardDragState? current,
  required String columnId,
  required int cardIndex,
}) {
  final sameColumn = current != null && current.targetColumnId == columnId;
  if (sameColumn && current.targetIndex <= cardIndex) {
    return cardIndex + 1;
  }
  return cardIndex;
}

class BoardDragController extends Notifier<BoardDragState?> {
  @override
  BoardDragState? build() {
    ref.listen<BoardSyncState>(boardNotifierProvider, (previous, next) {
      final current = state;
      if (current != null && !isCardDraggable(next, current.cardId)) {
        state = null;
      }
    });
    return null;
  }

  void start({
    required String cardId,
    required String columnId,
    required int index,
  }) {
    if (!isCardDraggable(ref.read(boardNotifierProvider), cardId)) {
      state = null;
      return;
    }
    state = BoardDragState(
      cardId: cardId,
      fromColumnId: columnId,
      targetColumnId: columnId,
      targetIndex: index,
    );
  }

  void hoverCard({required String columnId, required int cardIndex}) {
    final current = state;
    if (current == null) {
      return;
    }
    _retarget(
      current,
      columnId,
      hoverIndexForCard(
        current: current,
        columnId: columnId,
        cardIndex: cardIndex,
      ),
    );
  }

  void hoverStart({required String columnId}) {
    final current = state;
    if (current == null) {
      return;
    }
    _retarget(current, columnId, 0);
  }

  void hoverEnd({required String columnId, required int length}) {
    final current = state;
    if (current == null) {
      return;
    }
    _retarget(current, columnId, length);
  }

  void _retarget(BoardDragState current, String columnId, int index) {
    final next = current.retarget(columnId, index);
    if (next != current) {
      state = next;
    }
  }

  void drop() {
    final current = state;
    state = null;
    if (current == null) {
      return;
    }
    ref
        .read(boardNotifierProvider.notifier)
        .moveCardToIndex(
          cardId: current.cardId,
          toColumnId: current.targetColumnId,
          index: current.targetIndex,
        );
  }

  void cancel() {
    if (state != null) {
      state = null;
    }
  }
}

final boardDragProvider =
    NotifierProvider<BoardDragController, BoardDragState?>(
      BoardDragController.new,
    );
