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
  return _indexByAnchors(
    ordered.map((card) => card.id).toList(),
    afterId: afterId,
    beforeId: beforeId,
  );
}

int _indexByAnchors(List<String> ids, {String? afterId, String? beforeId}) {
  final afterIndex = afterId == null ? -1 : ids.indexOf(afterId);
  if (afterIndex >= 0) {
    return afterIndex + 1;
  }
  final beforeIndex = beforeId == null ? -1 : ids.indexOf(beforeId);
  if (beforeIndex >= 0) {
    return beforeIndex;
  }
  return ids.length;
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
    CreateColumn() => _createColumn(board, op),
    RenameColumn() => _renameColumn(board, op),
    MoveColumn() => _moveColumn(board, op),
    ArchiveColumn() => _archiveColumn(board, op),
  };
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

String _columnRankAt(List<ColumnModel> ordered, int index) {
  final clamped = index.clamp(0, ordered.length);
  final previous = clamped > 0 ? ordered[clamped - 1].rank : null;
  final next = clamped < ordered.length ? ordered[clamped].rank : null;
  if (previous != null && next != null && compareRanks(previous, next) >= 0) {
    return rankBetween(previous, null);
  }
  return rankBetween(previous, next);
}

BoardModel _createColumn(BoardModel board, CreateColumn op) {
  if (board.columnById(op.columnId) != null) {
    return board;
  }
  final ordered = board.orderedColumns;
  final index = _indexByAnchors(
    ordered.map((column) => column.id).toList(),
    afterId: op.afterId,
    beforeId: op.beforeId,
  );
  final column = ColumnModel(
    id: op.columnId,
    title: op.title,
    rank: _columnRankAt(ordered, index),
    version: 1,
    marker: ColumnMarker.backlog,
  );
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[...board.columns, column]),
  );
}

BoardModel _replaceColumn(
  BoardModel board,
  String columnId,
  ColumnModel Function(ColumnModel column) change,
) {
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[
      for (final column in board.columns)
        column.id == columnId ? change(column) : column,
    ]),
  );
}

BoardModel _renameColumn(BoardModel board, RenameColumn op) {
  final column = board.columnById(op.columnId);
  if (column == null) {
    return board;
  }
  return _replaceColumn(
    board,
    op.columnId,
    (current) =>
        current.copyWith(title: op.title, version: current.version + 1),
  );
}

BoardModel _moveColumn(BoardModel board, MoveColumn op) {
  final column = board.columnById(op.columnId);
  if (column == null) {
    return board;
  }
  final others = board.orderedColumns
      .where((other) => other.id != op.columnId)
      .toList();
  final index = _indexByAnchors(
    others.map((other) => other.id).toList(),
    afterId: op.afterId,
    beforeId: op.beforeId,
  );
  return _replaceColumn(
    board,
    op.columnId,
    (current) => current.copyWith(
      rank: _columnRankAt(others, index),
      version: current.version + 1,
    ),
  );
}

BoardModel _archiveColumn(BoardModel board, ArchiveColumn op) {
  if (board.columnById(op.columnId) == null) {
    return board;
  }
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[
      for (final column in board.columns)
        if (column.id != op.columnId) column,
    ]),
    cards: <CardModel>[
      for (final card in board.cards)
        card.columnId == op.columnId ? card.copyWith(archived: true) : card,
    ],
  );
}

bool canApplyOp(BoardModel board, BoardOp op) {
  return switch (op) {
    MoveCard() =>
      board.activeCard(op.cardId) != null &&
          board.columnById(op.toColumnId) != null,
    CreateCard() =>
      board.cardById(op.cardId) == null &&
          board.columnById(op.columnId) != null,
    EditCardTitle() => board.activeCard(op.cardId) != null,
    EditCardDescription() => board.activeCard(op.cardId) != null,
    ArchiveCard() => board.activeCard(op.cardId) != null,
    CreateColumn() => board.columnById(op.columnId) == null,
    RenameColumn() => board.columnById(op.columnId) != null,
    MoveColumn() => board.columnById(op.columnId) != null,
    ArchiveColumn() => board.columnById(op.columnId) != null,
  };
}
