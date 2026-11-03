import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';

final DateTime eventTime = DateTime.utc(2026, 2, 3, 4, 5, 6);

BoardRenamedEvent renamed(
  int seq, {
  String? opId,
  String? title,
  String actorId = 'u2',
}) {
  return BoardRenamedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    title: title ?? 'title-$seq',
    opId: opId,
  );
}

CardCreatedEvent cardCreated(
  int seq,
  String id,
  String columnId,
  String rank, {
  String? opId,
  String title = 'New card',
  String description = '',
  int version = 1,
  int descriptionVersion = 1,
  String actorId = 'u2',
}) {
  return CardCreatedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    opId: opId,
    card: CardModel(
      id: id,
      columnId: columnId,
      title: title,
      description: description,
      rank: rank,
      version: version,
      descriptionVersion: descriptionVersion,
      createdBy: actorId,
      updatedBy: actorId,
      createdAt: eventTime,
      updatedAt: eventTime,
    ),
  );
}

CardEditedEvent cardEdited(
  int seq,
  String cardId, {
  String? title,
  String? description,
  int version = 2,
  int descriptionVersion = 1,
  String? opId,
  String actorId = 'u2',
}) {
  return CardEditedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    opId: opId,
    cardId: cardId,
    title: title,
    description: description,
    version: version,
    descriptionVersion: descriptionVersion,
  );
}

CardMovedEvent cardMoved(
  int seq,
  String cardId,
  String from,
  String to,
  String rank, {
  int version = 2,
  String? opId,
  String actorId = 'u2',
}) {
  return CardMovedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    opId: opId,
    cardId: cardId,
    fromColumnId: from,
    toColumnId: to,
    rank: rank,
    version: version,
  );
}

CardArchivedEvent cardArchived(
  int seq,
  String cardId,
  String columnId, {
  int version = 2,
  String? opId,
  String actorId = 'u2',
}) {
  return CardArchivedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    opId: opId,
    cardId: cardId,
    columnId: columnId,
    version: version,
  );
}

ColumnCreatedEvent columnCreated(
  int seq,
  String id,
  String rank, {
  String title = 'Fresh',
  int version = 1,
  String? opId,
  String actorId = 'u2',
}) {
  return ColumnCreatedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: actorId,
    opId: opId,
    column: ColumnModel(
      id: id,
      title: title,
      rank: rank,
      version: version,
      marker: ColumnMarker.backlog,
    ),
  );
}

MemberAddedEvent memberAdded(
  int seq,
  String userId, {
  BoardRole role = BoardRole.editor,
  String name = 'Newcomer',
  String color = '#112233',
  String? opId,
}) {
  return MemberAddedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: 'u2',
    opId: opId,
    userId: userId,
    displayName: name,
    avatarColor: color,
    role: role,
  );
}

MemberRoleChangedEvent roleChanged(int seq, String userId, BoardRole role) {
  return MemberRoleChangedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: 'u2',
    userId: userId,
    role: role,
  );
}

MemberRemovedEvent memberRemoved(int seq, String userId) {
  return MemberRemovedEvent(
    seq: seq,
    serverTs: eventTime,
    actorId: 'u2',
    userId: userId,
  );
}

List<BoardEvent> oneOfEachEvent({int firstSeq = 1}) {
  var seq = firstSeq;
  int next() => seq++;
  return <BoardEvent>[
    cardCreated(next(), 'n1', 'col-a', 'm', opId: 'o1', description: 'D'),
    cardEdited(
      next(),
      'n1',
      title: 'T',
      description: 'Desc',
      version: 3,
      descriptionVersion: 2,
      opId: 'o2',
    ),
    cardMoved(next(), 'n1', 'col-a', 'col-b', 'n', version: 4, opId: 'o3'),
    cardArchived(next(), 'n1', 'col-b', version: 5, opId: 'o4'),
    columnCreated(next(), 'col-n', 'z', title: 'Nova', opId: 'o5'),
    ColumnRenamedEvent(
      seq: next(),
      serverTs: eventTime,
      actorId: 'u2',
      opId: 'o6',
      columnId: 'col-n',
      title: 'Nova 2',
      version: 2,
    ),
    ColumnMovedEvent(
      seq: next(),
      serverTs: eventTime,
      actorId: 'u2',
      opId: 'o7',
      columnId: 'col-n',
      rank: 'zz',
      version: 3,
    ),
    ColumnArchivedEvent(
      seq: next(),
      serverTs: eventTime,
      actorId: 'u2',
      opId: 'o8',
      columnId: 'col-n',
      cardIds: const <String>['x1', 'x2'],
      version: 4,
    ),
    ColumnRebalancedEvent(
      seq: next(),
      serverTs: eventTime,
      actorId: 'u2',
      columnId: 'col-a',
      cards: const <CardRankEntry>[
        (cardId: 'a1', rank: 'g'),
        (cardId: 'a2', rank: 'p'),
      ],
    ),
    ColumnsRebalancedEvent(
      seq: next(),
      serverTs: eventTime,
      actorId: 'u2',
      columns: const <ColumnRankEntry>[
        (columnId: 'col-a', rank: 'g'),
        (columnId: 'col-b', rank: 'p'),
      ],
    ),
    renamed(next(), title: 'Renamed'),
    BoardDeletedEvent(seq: next(), serverTs: eventTime, actorId: 'u2'),
    memberAdded(next(), 'u3', role: BoardRole.viewer, opId: 'o9'),
    roleChanged(next(), 'u3', BoardRole.editor),
    memberRemoved(next(), 'u3'),
  ];
}
