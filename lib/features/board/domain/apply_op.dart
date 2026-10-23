import '../../../core/ranking/rank.dart';
import 'board_model.dart';
import 'board_op.dart';

class CardAnchors {
  const CardAnchors({this.afterId, this.beforeId});

  final String? afterId;
  final String? beforeId;

  @override
  bool operator ==(Object other) {
    return other is CardAnchors &&
        other.afterId == afterId &&
        other.beforeId == beforeId;
  }

  @override
  int get hashCode => Object.hash(afterId, beforeId);

  @override
  String toString() => 'CardAnchors(after $afterId, before $beforeId)';
}

CardAnchors anchorsAt(List<CardModel> ordered, int index) {
  final clamped = index.clamp(0, ordered.length);
  return CardAnchors(
    afterId: clamped > 0 ? ordered[clamped - 1].id : null,
    beforeId: clamped < ordered.length ? ordered[clamped].id : null,
  );
}

int resolveInsertIndex(
  List<CardModel> ordered, {
  String? afterId,
  String? beforeId,
}) {
  final afterIndex = afterId == null
      ? -1
      : ordered.indexWhere((card) => card.id == afterId);
  if (afterIndex >= 0) {
    return afterIndex + 1;
  }
  final beforeIndex = beforeId == null
      ? -1
      : ordered.indexWhere((card) => card.id == beforeId);
  if (beforeIndex >= 0) {
    return beforeIndex;
  }
  return ordered.length;
}

String rankAtIndex(List<CardModel> ordered, int index) {
  final clamped = index.clamp(0, ordered.length);
  final previous = clamped > 0 ? ordered[clamped - 1].rank : null;
  final next = clamped < ordered.length ? ordered[clamped].rank : null;
  if (previous != null && next != null && compareRanks(previous, next) >= 0) {
    return rankBetween(previous, null);
  }
  return rankBetween(previous, next);
}

BoardModel applyOp(BoardModel board, BoardOp op) {
  return switch (op) {
    MoveCard() => _move(board, op),
    CreateCard() => _create(board, op),
    EditCardTitle() => _editTitle(board, op),
    EditCardDescription() => _editDescription(board, op),
    ArchiveCard() => _archive(board, op),
  };
}

BoardModel applyRemoteCard(BoardModel board, CardModel remote) {
  final card = board.cardById(remote.id);
  if (card == null || card.archived) {
    return board;
  }
  return _replaceCard(
    board,
    card.copyWith(
      description: remote.description,
      descriptionVersion: remote.descriptionVersion,
      updatedBy: remote.updatedBy,
      updatedAt: remote.updatedAt,
      version: remote.version > card.version ? remote.version : card.version,
    ),
  );
}

BoardModel applyOps(BoardModel board, Iterable<BoardOp> ops) {
  return ops.fold(board, applyOp);
}

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

BoardModel _replaceCard(BoardModel board, CardModel updated) {
  return board.copyWith(
    cards: <CardModel>[
      for (final card in board.cards) card.id == updated.id ? updated : card,
    ],
  );
}

BoardModel _move(BoardModel board, MoveCard op) {
  final card = board.cardById(op.cardId);
  if (card == null || card.archived) {
    return board;
  }
  if (board.columnById(op.toColumnId) == null) {
    return board;
  }
  final target = board
      .cardsIn(op.toColumnId)
      .where((other) => other.id != card.id)
      .toList();
  final index = resolveInsertIndex(
    target,
    afterId: op.afterId,
    beforeId: op.beforeId,
  );
  final unchanged =
      card.columnId == op.toColumnId &&
      board.cardsIn(op.toColumnId).indexWhere((c) => c.id == card.id) == index;
  return _replaceCard(
    board,
    card.copyWith(
      columnId: op.toColumnId,
      rank: unchanged ? card.rank : rankAtIndex(target, index),
      version: card.version + 1,
    ),
  );
}

BoardModel _create(BoardModel board, CreateCard op) {
  if (board.cardById(op.cardId) != null) {
    return board;
  }
  if (board.columnById(op.columnId) == null) {
    return board;
  }
  final target = board.cardsIn(op.columnId);
  final index = resolveInsertIndex(
    target,
    afterId: op.afterId,
    beforeId: op.beforeId,
  );
  final card = CardModel(
    id: op.cardId,
    columnId: op.columnId,
    title: op.title,
    description: op.description,
    rank: rankAtIndex(target, index),
    createdBy: op.actorId,
    updatedBy: op.actorId,
    createdAt: op.at ?? _epoch,
    updatedAt: op.at ?? _epoch,
  );
  return board.copyWith(cards: <CardModel>[...board.cards, card]);
}

BoardModel _editTitle(BoardModel board, EditCardTitle op) {
  final card = board.cardById(op.cardId);
  if (card == null || card.archived) {
    return board;
  }
  return _replaceCard(
    board,
    card.copyWith(
      title: op.title,
      updatedBy: op.actorId,
      updatedAt: op.at ?? card.updatedAt,
      version: card.version + 1,
    ),
  );
}

BoardModel _editDescription(BoardModel board, EditCardDescription op) {
  final card = board.cardById(op.cardId);
  if (card == null || card.archived) {
    return board;
  }
  return _replaceCard(
    board,
    card.copyWith(
      description: op.description,
      updatedBy: op.actorId,
      updatedAt: op.at ?? card.updatedAt,
      version: card.version + 1,
      descriptionVersion: card.descriptionVersion + 1,
    ),
  );
}

BoardModel _archive(BoardModel board, ArchiveCard op) {
  final card = board.cardById(op.cardId);
  if (card == null || card.archived) {
    return board;
  }
  return _replaceCard(board, card.copyWith(archived: true));
}
