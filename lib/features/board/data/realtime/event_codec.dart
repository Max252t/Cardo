import '../../../../core/models/board_role.dart';
import '../../../../core/network/json_fields.dart';
import '../../domain/board_event.dart';
import '../../domain/board_model.dart';

BoardRole _role(Map<String, dynamic> json, String key) {
  final role = BoardRole.tryParse(readString(json, key));
  if (role == null) {
    throw FormatException('Unknown role in "$key"');
  }
  return role;
}

DateTime _millis(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

BoardEvent decodeEvent(Map<String, dynamic> envelope) {
  final type = readString(envelope, 'type');
  final seq = readInt(envelope, 'seq');
  final serverTs = _millis(readInt(envelope, 'server_ts'));
  final opId = readOptionalString(envelope, 'op_id');
  final payloadRaw = envelope['payload'];
  final p = payloadRaw is Map<String, dynamic>
      ? payloadRaw
      : const <String, dynamic>{};
  final actor = readOptionalString(p, 'actor_id');
  String actorId() {
    if (actor == null || actor.isEmpty) {
      throw const FormatException('Missing actor_id');
    }
    return actor;
  }

  switch (type) {
    case 'card.created':
      return CardCreatedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        card: CardModel(
          id: readNonEmptyString(p, 'id'),
          columnId: readNonEmptyString(p, 'column_id'),
          title: readString(p, 'title'),
          description: readString(p, 'description'),
          rank: readNonEmptyString(p, 'rank'),
          version: readInt(p, 'version'),
          descriptionVersion: readInt(p, 'description_version'),
          createdBy: readNonEmptyString(p, 'created_by'),
          updatedBy: readNonEmptyString(p, 'updated_by'),
          createdAt: readDate(p, 'created_at'),
          updatedAt: readDate(p, 'updated_at'),
        ),
      );
    case 'card.edited':
      return CardEditedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        cardId: readNonEmptyString(p, 'card_id'),
        title: readOptionalString(p, 'title'),
        description: readOptionalString(p, 'description'),
        version: readInt(p, 'version'),
        descriptionVersion: readInt(p, 'description_version'),
      );
    case 'card.moved':
      return CardMovedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        cardId: readNonEmptyString(p, 'card_id'),
        fromColumnId: readNonEmptyString(p, 'from_column_id'),
        toColumnId: readNonEmptyString(p, 'to_column_id'),
        rank: readNonEmptyString(p, 'rank'),
        version: readInt(p, 'version'),
      );
    case 'card.archived':
      return CardArchivedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        cardId: readNonEmptyString(p, 'card_id'),
        columnId: readNonEmptyString(p, 'column_id'),
        version: readInt(p, 'version'),
      );
    case 'column.created':
      return ColumnCreatedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        column: ColumnModel(
          id: readNonEmptyString(p, 'id'),
          title: readString(p, 'title'),
          rank: readNonEmptyString(p, 'rank'),
          version: readInt(p, 'version'),
          marker: ColumnMarker.backlog,
        ),
      );
    case 'column.renamed':
      return ColumnRenamedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        columnId: readNonEmptyString(p, 'column_id'),
        title: readString(p, 'title'),
        version: readInt(p, 'version'),
      );
    case 'column.moved':
      return ColumnMovedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        columnId: readNonEmptyString(p, 'column_id'),
        rank: readNonEmptyString(p, 'rank'),
        version: readInt(p, 'version'),
      );
    case 'column.archived':
      return ColumnArchivedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        columnId: readNonEmptyString(p, 'column_id'),
        cardIds: readStringList(p, 'card_ids'),
        version: readInt(p, 'version'),
      );
    case 'column.rebalanced':
      return ColumnRebalancedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        columnId: readNonEmptyString(p, 'column_id'),
        cards: <CardRankEntry>[
          for (final item in readObjectList(p, 'cards'))
            (
              cardId: readNonEmptyString(item, 'card_id'),
              rank: readNonEmptyString(item, 'rank'),
            ),
        ],
      );
    case 'columns.rebalanced':
      return ColumnsRebalancedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        columns: <ColumnRankEntry>[
          for (final item in readObjectList(p, 'columns'))
            (
              columnId: readNonEmptyString(item, 'column_id'),
              rank: readNonEmptyString(item, 'rank'),
            ),
        ],
      );
    case 'board.renamed':
      return BoardRenamedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        title: readString(p, 'title'),
      );
    case 'board.deleted':
      return BoardDeletedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
      );
    case 'member.added':
      return MemberAddedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        userId: readNonEmptyString(p, 'user_id'),
        displayName: readString(p, 'display_name'),
        avatarColor: readString(p, 'avatar_color'),
        role: _role(p, 'role'),
      );
    case 'member.role_changed':
      return MemberRoleChangedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        userId: readNonEmptyString(p, 'user_id'),
        role: _role(p, 'role'),
      );
    case 'member.removed':
      return MemberRemovedEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        actorId: actorId(),
        userId: readNonEmptyString(p, 'user_id'),
      );
    default:
      return UnknownBoardEvent(
        seq: seq,
        serverTs: serverTs,
        opId: opId,
        unknownType: type,
      );
  }
}

const Set<String> knownEventTypes = <String>{
  'card.created',
  'card.edited',
  'card.moved',
  'card.archived',
  'column.created',
  'column.renamed',
  'column.moved',
  'column.archived',
  'column.rebalanced',
  'columns.rebalanced',
  'board.renamed',
  'board.deleted',
  'member.added',
  'member.role_changed',
  'member.removed',
};

String _iso(DateTime value) => value.toUtc().toIso8601String();

Map<String, Object?> encodeEventPayload(BoardEvent event) {
  return switch (event) {
    CardCreatedEvent(:final card) => <String, Object?>{
      'id': card.id,
      'column_id': card.columnId,
      'title': card.title,
      'description': card.description,
      'rank': card.rank,
      'version': card.version,
      'description_version': card.descriptionVersion,
      'created_by': card.createdBy,
      'updated_by': card.updatedBy,
      'created_at': _iso(card.createdAt),
      'updated_at': _iso(card.updatedAt),
      'actor_id': event.actorId,
    },
    CardEditedEvent() => <String, Object?>{
      'card_id': event.cardId,
      'title': ?event.title,
      'description': ?event.description,
      'version': event.version,
      'description_version': event.descriptionVersion,
      'actor_id': event.actorId,
    },
    CardMovedEvent() => <String, Object?>{
      'card_id': event.cardId,
      'from_column_id': event.fromColumnId,
      'to_column_id': event.toColumnId,
      'rank': event.rank,
      'version': event.version,
      'actor_id': event.actorId,
    },
    CardArchivedEvent() => <String, Object?>{
      'card_id': event.cardId,
      'column_id': event.columnId,
      'version': event.version,
      'actor_id': event.actorId,
    },
    ColumnCreatedEvent(:final column) => <String, Object?>{
      'id': column.id,
      'title': column.title,
      'rank': column.rank,
      'version': column.version,
      'actor_id': event.actorId,
    },
    ColumnRenamedEvent() => <String, Object?>{
      'column_id': event.columnId,
      'title': event.title,
      'version': event.version,
      'actor_id': event.actorId,
    },
    ColumnMovedEvent() => <String, Object?>{
      'column_id': event.columnId,
      'rank': event.rank,
      'version': event.version,
      'actor_id': event.actorId,
    },
    ColumnArchivedEvent() => <String, Object?>{
      'column_id': event.columnId,
      'card_ids': event.cardIds,
      'version': event.version,
      'actor_id': event.actorId,
    },
    ColumnRebalancedEvent() => <String, Object?>{
      'column_id': event.columnId,
      'cards': <Object?>[
        for (final entry in event.cards)
          <String, Object?>{'card_id': entry.cardId, 'rank': entry.rank},
      ],
      'actor_id': event.actorId,
    },
    ColumnsRebalancedEvent() => <String, Object?>{
      'columns': <Object?>[
        for (final entry in event.columns)
          <String, Object?>{'column_id': entry.columnId, 'rank': entry.rank},
      ],
      'actor_id': event.actorId,
    },
    BoardRenamedEvent() => <String, Object?>{
      'title': event.title,
      'actor_id': event.actorId,
    },
    BoardDeletedEvent() => <String, Object?>{'actor_id': event.actorId},
    MemberAddedEvent() => <String, Object?>{
      'user_id': event.userId,
      'display_name': event.displayName,
      'avatar_color': event.avatarColor,
      'role': event.role.wireName,
      'actor_id': event.actorId,
    },
    MemberRoleChangedEvent() => <String, Object?>{
      'user_id': event.userId,
      'role': event.role.wireName,
      'actor_id': event.actorId,
    },
    MemberRemovedEvent() => <String, Object?>{
      'user_id': event.userId,
      'actor_id': event.actorId,
    },
    UnknownBoardEvent() => const <String, Object?>{},
  };
}

Map<String, Object?> encodeEventEnvelope(BoardEvent event) {
  return <String, Object?>{
    'v': 1,
    'type': event.type,
    'op_id': ?event.opId,
    'seq': event.seq,
    'server_ts': event.serverTs.millisecondsSinceEpoch,
    'payload': encodeEventPayload(event),
  };
}
