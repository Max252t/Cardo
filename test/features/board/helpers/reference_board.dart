import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/ranking/rank.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';

class RefCard {
  RefCard({
    required this.id,
    required this.columnId,
    required this.title,
    required this.description,
    required this.rank,
    required this.version,
    required this.descriptionVersion,
  });

  final String id;
  String columnId;
  String title;
  String description;
  String rank;
  int version;
  int descriptionVersion;
  bool archived = false;
}

class RefColumn {
  RefColumn({
    required this.id,
    required this.title,
    required this.rank,
    required this.version,
  });

  final String id;
  String title;
  String rank;
  int version;
}

class ReferenceBoard {
  ReferenceBoard.from(BoardModel initial)
    : title = initial.title,
      seq = initial.seq {
    for (final card in initial.cards) {
      final ref = RefCard(
        id: card.id,
        columnId: card.columnId,
        title: card.title,
        description: card.description,
        rank: card.rank,
        version: card.version,
        descriptionVersion: card.descriptionVersion,
      );
      ref.archived = card.archived;
      cards[card.id] = ref;
    }
    for (final column in initial.columns) {
      columns[column.id] = RefColumn(
        id: column.id,
        title: column.title,
        rank: column.rank,
        version: column.version,
      );
    }
    for (final member in initial.members) {
      roles[member.userId] = member.role;
    }
  }

  String title;
  int seq;
  final Map<String, RefCard> cards = <String, RefCard>{};
  final Map<String, RefColumn> columns = <String, RefColumn>{};
  final Map<String, BoardRole> roles = <String, BoardRole>{};
  final Map<String, int> appliedOps = <String, int>{};
  final Set<String> everArchivedCards = <String>{};
  final Set<String> everRemovedColumns = <String>{};
  int rebalances = 0;
  int columnEvents = 0;
  int memberEvents = 0;

  void apply(BoardEvent event) {
    if (event.seq != seq + 1) {
      throw StateError('reference board expected seq ${seq + 1}, got $event');
    }
    seq = event.seq;
    final opId = event.opId;
    if (opId != null) {
      appliedOps[opId] = event.seq;
    }
    switch (event) {
      case CardCreatedEvent():
        final card = event.card;
        cards[card.id] = RefCard(
          id: card.id,
          columnId: card.columnId,
          title: card.title,
          description: card.description,
          rank: card.rank,
          version: card.version,
          descriptionVersion: card.descriptionVersion,
        );
      case CardEditedEvent():
        final card = cards[event.cardId];
        if (card != null) {
          card.title = event.title ?? card.title;
          card.description = event.description ?? card.description;
          card.version = event.version;
          card.descriptionVersion = event.descriptionVersion;
        }
      case CardMovedEvent():
        final card = cards[event.cardId];
        if (card != null) {
          card.columnId = event.toColumnId;
          card.rank = event.rank;
          card.version = event.version;
        }
      case CardArchivedEvent():
        final card = cards[event.cardId];
        if (card != null) {
          card.archived = true;
          card.version = event.version;
          everArchivedCards.add(card.id);
        }
      case ColumnCreatedEvent():
        columnEvents++;
        final column = event.column;
        columns[column.id] = RefColumn(
          id: column.id,
          title: column.title,
          rank: column.rank,
          version: column.version,
        );
      case ColumnRenamedEvent():
        columnEvents++;
        final column = columns[event.columnId];
        if (column != null) {
          column.title = event.title;
          column.version = event.version;
        }
      case ColumnMovedEvent():
        columnEvents++;
        final column = columns[event.columnId];
        if (column != null) {
          column.rank = event.rank;
          column.version = event.version;
        }
      case ColumnArchivedEvent():
        columnEvents++;
        columns.remove(event.columnId);
        everRemovedColumns.add(event.columnId);
        for (final id in event.cardIds) {
          final card = cards[id];
          if (card != null) {
            card.archived = true;
            everArchivedCards.add(id);
          }
        }
        for (final card in cards.values) {
          if (card.columnId == event.columnId && !card.archived) {
            throw StateError('column archived with active card ${card.id}');
          }
        }
      case ColumnRebalancedEvent():
        rebalances++;
        for (final entry in event.cards) {
          final card = cards[entry.cardId];
          if (card != null) {
            card.rank = entry.rank;
          }
        }
      case ColumnsRebalancedEvent():
        rebalances++;
        for (final entry in event.columns) {
          final column = columns[entry.columnId];
          if (column != null) {
            column.rank = entry.rank;
          }
        }
      case BoardRenamedEvent():
        title = event.title;
      case BoardDeletedEvent():
      case UnknownBoardEvent():
        break;
      case MemberAddedEvent():
        memberEvents++;
        roles[event.userId] = event.role;
      case MemberRoleChangedEvent():
        memberEvents++;
        if (roles.containsKey(event.userId)) {
          roles[event.userId] = event.role;
        }
      case MemberRemovedEvent():
        memberEvents++;
        roles.remove(event.userId);
    }
  }

  List<RefCard> activeCardsIn(String columnId) {
    final list =
        cards.values
            .where((card) => card.columnId == columnId && !card.archived)
            .toList()
          ..sort(_byRank);
    return list;
  }

  List<RefColumn> get orderedColumns =>
      columns.values.toList()..sort((a, b) => a.rank.compareTo(b.rank));

  RefCard? activeCard(String id) {
    final card = cards[id];
    return card == null || card.archived ? null : card;
  }

  NackReason? verdict(BoardOp op, String actorId) {
    final role = roles[actorId];
    if (role == null) {
      return NackReason.forbidden;
    }
    if (!role.canEdit) {
      return NackReason.forbidden;
    }
    switch (op) {
      case CreateCard():
        if (!columns.containsKey(op.columnId)) {
          return NackReason.notFound;
        }
        if (cards.containsKey(op.cardId)) {
          return NackReason.validationError;
        }
        return null;
      case EditCardTitle():
        return activeCard(op.cardId) == null ? NackReason.notFound : null;
      case EditCardDescription():
        final card = activeCard(op.cardId);
        if (card == null) {
          return NackReason.notFound;
        }
        return card.descriptionVersion == op.baseDescriptionVersion
            ? null
            : NackReason.versionConflict;
      case MoveCard():
        final card = activeCard(op.cardId);
        if (card == null || !columns.containsKey(op.toColumnId)) {
          return NackReason.notFound;
        }
        return card.version == op.baseVersion
            ? null
            : NackReason.versionConflict;
      case ArchiveCard():
        return activeCard(op.cardId) == null ? NackReason.notFound : null;
      case CreateColumn():
        return columns.containsKey(op.columnId)
            ? NackReason.validationError
            : null;
      case RenameColumn():
        return columns.containsKey(op.columnId) ? null : NackReason.notFound;
      case MoveColumn():
        final column = columns[op.columnId];
        if (column == null) {
          return NackReason.notFound;
        }
        return column.version == op.baseVersion
            ? null
            : NackReason.versionConflict;
      case ArchiveColumn():
        return columns.containsKey(op.columnId) ? null : NackReason.notFound;
    }
  }

  List<String> signature() {
    final lines = <String>['title:$title', 'seq:$seq'];
    for (final column in orderedColumns) {
      lines.add(
        'col ${column.id} ${column.title} ${column.rank} v${column.version}',
      );
      for (final card in activeCardsIn(column.id)) {
        lines.add(
          _cardLine(
            card.id,
            card.title,
            card.description,
            card.rank,
            card.version,
            card.descriptionVersion,
          ),
        );
      }
    }
    final ids = roles.keys.toList()..sort();
    for (final id in ids) {
      lines.add('member $id ${roles[id]!.wireName}');
    }
    return lines;
  }

  static int _byRank(RefCard a, RefCard b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.id.compareTo(b.id);
  }
}

String _cardLine(
  String id,
  String title,
  String description,
  String rank,
  int version,
  int descriptionVersion,
) {
  return '  card $id "$title" "$description" $rank v$version d$descriptionVersion';
}

List<String> signatureOf(BoardModel board) {
  final lines = <String>['title:${board.title}', 'seq:${board.seq}'];
  final columns = List<ColumnModel>.of(board.columns)
    ..sort((a, b) => compareRanks(a.rank, b.rank));
  for (final column in columns) {
    lines.add(
      'col ${column.id} ${column.title} ${column.rank} v${column.version}',
    );
    for (final card in board.cardsIn(column.id)) {
      lines.add(
        _cardLine(
          card.id,
          card.title,
          card.description,
          card.rank,
          card.version,
          card.descriptionVersion,
        ),
      );
    }
  }
  final members = List<BoardMember>.of(board.members)
    ..sort((a, b) => a.userId.compareTo(b.userId));
  for (final member in members) {
    lines.add('member ${member.userId} ${member.role.wireName}');
  }
  return lines;
}
