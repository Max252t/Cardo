import 'board_event.dart';
import 'board_model.dart';

BoardModel applyEvent(BoardModel board, BoardEvent event) {
  return _apply(board, event).copyWith(seq: event.seq);
}

BoardModel applyEvents(BoardModel board, Iterable<BoardEvent> events) {
  return events.fold(board, applyEvent);
}

BoardModel _apply(BoardModel board, BoardEvent event) {
  return switch (event) {
    CardCreatedEvent() => _cardCreated(board, event),
    CardEditedEvent() => _cardEdited(board, event),
    CardMovedEvent() => _cardMoved(board, event),
    CardArchivedEvent() => _cardArchived(board, event),
    ColumnCreatedEvent() => _columnCreated(board, event),
    ColumnRenamedEvent() => _columnRenamed(board, event),
    ColumnMovedEvent() => _columnMoved(board, event),
    ColumnArchivedEvent() => _columnArchived(board, event),
    ColumnRebalancedEvent() => _columnRebalanced(board, event),
    ColumnsRebalancedEvent() => _columnsRebalanced(board, event),
    BoardRenamedEvent() => board.copyWith(title: event.title),
    BoardDeletedEvent() => board,
    MemberAddedEvent() => _memberAdded(board, event),
    MemberRoleChangedEvent() => _memberRoleChanged(board, event),
    MemberRemovedEvent() => board.copyWith(
      members: <BoardMember>[
        for (final member in board.members)
          if (member.userId != event.userId) member,
      ],
    ),
    UnknownBoardEvent() => board,
  };
}

BoardModel _replaceCard(
  BoardModel board,
  String cardId,
  CardModel Function(CardModel card) change,
) {
  if (board.cardById(cardId) == null) {
    return board;
  }
  return board.copyWith(
    cards: <CardModel>[
      for (final card in board.cards) card.id == cardId ? change(card) : card,
    ],
  );
}

BoardModel _cardCreated(BoardModel board, CardCreatedEvent event) {
  final exists = board.cardById(event.card.id) != null;
  return board.copyWith(
    cards: exists
        ? <CardModel>[
            for (final card in board.cards)
              card.id == event.card.id ? event.card : card,
          ]
        : <CardModel>[...board.cards, event.card],
  );
}

BoardModel _cardEdited(BoardModel board, CardEditedEvent event) {
  return _replaceCard(
    board,
    event.cardId,
    (card) => card.copyWith(
      title: event.title,
      description: event.description,
      version: event.version,
      descriptionVersion: event.descriptionVersion,
      updatedBy: event.actorId,
      updatedAt: event.serverTs,
    ),
  );
}

BoardModel _cardMoved(BoardModel board, CardMovedEvent event) {
  return _replaceCard(
    board,
    event.cardId,
    (card) => card.copyWith(
      columnId: event.toColumnId,
      rank: event.rank,
      version: event.version,
      updatedBy: event.actorId,
      updatedAt: event.serverTs,
    ),
  );
}

BoardModel _cardArchived(BoardModel board, CardArchivedEvent event) {
  return _replaceCard(
    board,
    event.cardId,
    (card) => card.copyWith(
      archived: true,
      version: event.version,
      updatedBy: event.actorId,
      updatedAt: event.serverTs,
    ),
  );
}

BoardModel _columnCreated(BoardModel board, ColumnCreatedEvent event) {
  final others = <ColumnModel>[
    for (final column in board.columns)
      if (column.id != event.column.id) column,
  ];
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[...others, event.column]),
  );
}

BoardModel _replaceColumn(
  BoardModel board,
  String columnId,
  ColumnModel Function(ColumnModel column) change,
) {
  if (board.columnById(columnId) == null) {
    return board;
  }
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[
      for (final column in board.columns)
        column.id == columnId ? change(column) : column,
    ]),
  );
}

BoardModel _columnRenamed(BoardModel board, ColumnRenamedEvent event) {
  return _replaceColumn(
    board,
    event.columnId,
    (column) => column.copyWith(title: event.title, version: event.version),
  );
}

BoardModel _columnMoved(BoardModel board, ColumnMovedEvent event) {
  return _replaceColumn(
    board,
    event.columnId,
    (column) => column.copyWith(rank: event.rank, version: event.version),
  );
}

BoardModel _columnArchived(BoardModel board, ColumnArchivedEvent event) {
  if (board.columnById(event.columnId) == null) {
    return board;
  }
  final archivedIds = event.cardIds.toSet();
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[
      for (final column in board.columns)
        if (column.id != event.columnId) column,
    ]),
    cards: <CardModel>[
      for (final card in board.cards)
        archivedIds.contains(card.id) || card.columnId == event.columnId
            ? card.copyWith(archived: true)
            : card,
    ],
  );
}

BoardModel _columnRebalanced(BoardModel board, ColumnRebalancedEvent event) {
  final ranks = <String, String>{
    for (final entry in event.cards) entry.cardId: entry.rank,
  };
  return board.copyWith(
    cards: <CardModel>[
      for (final card in board.cards)
        ranks.containsKey(card.id) ? card.copyWith(rank: ranks[card.id]) : card,
    ],
  );
}

BoardModel _columnsRebalanced(BoardModel board, ColumnsRebalancedEvent event) {
  final ranks = <String, String>{
    for (final entry in event.columns) entry.columnId: entry.rank,
  };
  return board.copyWith(
    columns: withColumnMarkers(<ColumnModel>[
      for (final column in board.columns)
        ranks.containsKey(column.id)
            ? column.copyWith(rank: ranks[column.id])
            : column,
    ]),
  );
}

BoardModel _memberAdded(BoardModel board, MemberAddedEvent event) {
  final member = BoardMember(
    userId: event.userId,
    name: event.displayName,
    avatarColor: event.avatarColor,
    role: event.role,
  );
  final exists = board.memberById(event.userId) != null;
  return board.copyWith(
    members: exists
        ? <BoardMember>[
            for (final other in board.members)
              other.userId == event.userId ? member : other,
          ]
        : <BoardMember>[...board.members, member],
  );
}

BoardModel _memberRoleChanged(BoardModel board, MemberRoleChangedEvent event) {
  return board.copyWith(
    members: <BoardMember>[
      for (final member in board.members)
        member.userId == event.userId
            ? member.copyWith(role: event.role)
            : member,
    ],
  );
}
