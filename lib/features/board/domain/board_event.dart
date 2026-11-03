import '../../../core/equality/collection_equality.dart';
import '../../../core/models/board_role.dart';
import 'board_model.dart';

sealed class BoardEvent {
  const BoardEvent({
    required this.seq,
    required this.serverTs,
    required this.actorId,
    this.opId,
  });

  final int seq;
  final String? opId;
  final DateTime serverTs;
  final String actorId;

  String get type;

  List<Object?> get fields;

  @override
  bool operator ==(Object other) {
    return other is BoardEvent &&
        other.runtimeType == runtimeType &&
        other.seq == seq &&
        other.opId == opId &&
        other.serverTs == serverTs &&
        other.actorId == actorId &&
        listEquals(other.fields, fields);
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    seq,
    opId,
    serverTs,
    actorId,
    Object.hashAll(fields),
  );

  @override
  String toString() => '$type(seq $seq, op $opId)';
}

final class CardCreatedEvent extends BoardEvent {
  const CardCreatedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.card,
    super.opId,
  });

  final CardModel card;

  @override
  String get type => 'card.created';

  @override
  List<Object?> get fields => <Object?>[card];
}

final class CardEditedEvent extends BoardEvent {
  const CardEditedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.cardId,
    required this.version,
    required this.descriptionVersion,
    this.title,
    this.description,
    super.opId,
  });

  final String cardId;
  final String? title;
  final String? description;
  final int version;
  final int descriptionVersion;

  @override
  String get type => 'card.edited';

  @override
  List<Object?> get fields => <Object?>[
    cardId,
    title,
    description,
    version,
    descriptionVersion,
  ];
}

final class CardMovedEvent extends BoardEvent {
  const CardMovedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.cardId,
    required this.fromColumnId,
    required this.toColumnId,
    required this.rank,
    required this.version,
    super.opId,
  });

  final String cardId;
  final String fromColumnId;
  final String toColumnId;
  final String rank;
  final int version;

  @override
  String get type => 'card.moved';

  @override
  List<Object?> get fields => <Object?>[
    cardId,
    fromColumnId,
    toColumnId,
    rank,
    version,
  ];
}

final class CardArchivedEvent extends BoardEvent {
  const CardArchivedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.cardId,
    required this.columnId,
    required this.version,
    super.opId,
  });

  final String cardId;
  final String columnId;
  final int version;

  @override
  String get type => 'card.archived';

  @override
  List<Object?> get fields => <Object?>[cardId, columnId, version];
}

final class ColumnCreatedEvent extends BoardEvent {
  const ColumnCreatedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.column,
    super.opId,
  });

  final ColumnModel column;

  @override
  String get type => 'column.created';

  @override
  List<Object?> get fields => <Object?>[column];
}

final class ColumnRenamedEvent extends BoardEvent {
  const ColumnRenamedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.columnId,
    required this.title,
    required this.version,
    super.opId,
  });

  final String columnId;
  final String title;
  final int version;

  @override
  String get type => 'column.renamed';

  @override
  List<Object?> get fields => <Object?>[columnId, title, version];
}

final class ColumnMovedEvent extends BoardEvent {
  const ColumnMovedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.columnId,
    required this.rank,
    required this.version,
    super.opId,
  });

  final String columnId;
  final String rank;
  final int version;

  @override
  String get type => 'column.moved';

  @override
  List<Object?> get fields => <Object?>[columnId, rank, version];
}

final class ColumnArchivedEvent extends BoardEvent {
  const ColumnArchivedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.columnId,
    required this.cardIds,
    required this.version,
    super.opId,
  });

  final String columnId;
  final List<String> cardIds;
  final int version;

  @override
  String get type => 'column.archived';

  @override
  List<Object?> get fields => <Object?>[columnId, ...cardIds, version];
}

typedef CardRankEntry = ({String cardId, String rank});

typedef ColumnRankEntry = ({String columnId, String rank});

final class ColumnRebalancedEvent extends BoardEvent {
  const ColumnRebalancedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.columnId,
    required this.cards,
    super.opId,
  });

  final String columnId;
  final List<CardRankEntry> cards;

  @override
  String get type => 'column.rebalanced';

  @override
  List<Object?> get fields => <Object?>[columnId, ...cards];
}

final class ColumnsRebalancedEvent extends BoardEvent {
  const ColumnsRebalancedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.columns,
    super.opId,
  });

  final List<ColumnRankEntry> columns;

  @override
  String get type => 'columns.rebalanced';

  @override
  List<Object?> get fields => <Object?>[...columns];
}

final class BoardRenamedEvent extends BoardEvent {
  const BoardRenamedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.title,
    super.opId,
  });

  final String title;

  @override
  String get type => 'board.renamed';

  @override
  List<Object?> get fields => <Object?>[title];
}

final class BoardDeletedEvent extends BoardEvent {
  const BoardDeletedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    super.opId,
  });

  @override
  String get type => 'board.deleted';

  @override
  List<Object?> get fields => const <Object?>[];
}

final class MemberAddedEvent extends BoardEvent {
  const MemberAddedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.userId,
    required this.displayName,
    required this.avatarColor,
    required this.role,
    super.opId,
  });

  final String userId;
  final String displayName;
  final String avatarColor;
  final BoardRole role;

  @override
  String get type => 'member.added';

  @override
  List<Object?> get fields => <Object?>[userId, displayName, avatarColor, role];
}

final class MemberRoleChangedEvent extends BoardEvent {
  const MemberRoleChangedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.userId,
    required this.role,
    super.opId,
  });

  final String userId;
  final BoardRole role;

  @override
  String get type => 'member.role_changed';

  @override
  List<Object?> get fields => <Object?>[userId, role];
}

final class MemberRemovedEvent extends BoardEvent {
  const MemberRemovedEvent({
    required super.seq,
    required super.serverTs,
    required super.actorId,
    required this.userId,
    super.opId,
  });

  final String userId;

  @override
  String get type => 'member.removed';

  @override
  List<Object?> get fields => <Object?>[userId];
}

final class UnknownBoardEvent extends BoardEvent {
  const UnknownBoardEvent({
    required super.seq,
    required super.serverTs,
    required this.unknownType,
    super.opId,
  }) : super(actorId: '');

  final String unknownType;

  @override
  String get type => unknownType;

  @override
  List<Object?> get fields => <Object?>[unknownType];
}

class EventsPage {
  EventsPage({
    required List<BoardEvent> events,
    required this.seq,
    required this.hasMore,
  }) : events = List<BoardEvent>.unmodifiable(events);

  final List<BoardEvent> events;
  final int seq;
  final bool hasMore;
}
