import '../../../../core/models/board_role.dart';
import '../../domain/apply_op.dart';
import '../../domain/board_event.dart';
import '../../domain/board_model.dart';
import '../../domain/board_op.dart';
import '../../domain/board_sync_state.dart';
import '../../domain/op_limits.dart';

sealed class OpVerdict {
  const OpVerdict();
}

final class OpAccepted extends OpVerdict {
  const OpAccepted(this.event);

  final BoardEvent event;
}

final class OpRefused extends OpVerdict {
  const OpRefused(this.reason, {this.limit});

  final NackReason reason;
  final int? limit;
}

NackReason? validateOp(BoardModel board, BoardOp op, {BoardRole? role}) {
  if (role != null && !role.canEdit) {
    return NackReason.forbidden;
  }
  switch (op) {
    case MoveCard():
      final card = board.cardById(op.cardId);
      if (card == null || card.archived) {
        return NackReason.notFound;
      }
      if (board.columnById(op.toColumnId) == null) {
        return NackReason.notFound;
      }
      if (card.version != op.baseVersion) {
        return NackReason.versionConflict;
      }
      return null;
    case CreateCard():
      if (board.columnById(op.columnId) == null) {
        return NackReason.notFound;
      }
      if (op.title.runes.length > CardLimits.titleMaxLength ||
          op.description.runes.length > CardLimits.descriptionMaxLength) {
        return NackReason.validationError;
      }
      return null;
    case EditCardTitle():
      final card = board.cardById(op.cardId);
      if (card == null || card.archived) {
        return NackReason.notFound;
      }
      return op.title.runes.length > CardLimits.titleMaxLength
          ? NackReason.validationError
          : null;
    case EditCardDescription():
      final card = board.cardById(op.cardId);
      if (card == null || card.archived) {
        return NackReason.notFound;
      }
      if (op.description.runes.length > CardLimits.descriptionMaxLength) {
        return NackReason.validationError;
      }
      if (card.descriptionVersion != op.baseDescriptionVersion) {
        return NackReason.versionConflict;
      }
      return null;
    case ArchiveCard():
      final card = board.cardById(op.cardId);
      return card == null || card.archived ? NackReason.notFound : null;
    case CreateColumn():
      return op.title.runes.length > ColumnLimits.titleMaxLength
          ? NackReason.validationError
          : null;
    case RenameColumn():
      if (board.columnById(op.columnId) == null) {
        return NackReason.notFound;
      }
      return op.title.runes.length > ColumnLimits.titleMaxLength
          ? NackReason.validationError
          : null;
    case MoveColumn():
      final column = board.columnById(op.columnId);
      if (column == null) {
        return NackReason.notFound;
      }
      return column.version != op.baseVersion
          ? NackReason.versionConflict
          : null;
    case ArchiveColumn():
      return board.columnById(op.columnId) == null ? NackReason.notFound : null;
  }
}

OpVerdict judgeOp(
  BoardModel board,
  BoardOp op, {
  required int seq,
  required String actorId,
  required DateTime now,
  BoardRole? role,
}) {
  final reason = validateOp(board, op, role: role);
  if (reason != null) {
    return OpRefused(
      reason,
      limit: reason == NackReason.validationError ? textLimitOf(op) : null,
    );
  }
  return OpAccepted(_eventFor(board, op, seq: seq, actorId: actorId, now: now));
}

BoardEvent _eventFor(
  BoardModel board,
  BoardOp op, {
  required int seq,
  required String actorId,
  required DateTime now,
}) {
  switch (op) {
    case CreateCard():
      final target = board.cardsIn(op.columnId);
      final index = resolveInsertIndex(
        target,
        afterId: op.afterId,
        beforeId: op.beforeId,
      );
      return CardCreatedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        card: CardModel(
          id: op.cardId,
          columnId: op.columnId,
          title: op.title,
          description: op.description,
          rank: rankAtIndex(target, index),
          createdBy: actorId,
          updatedBy: actorId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    case EditCardTitle():
      final card = board.cardById(op.cardId)!;
      return CardEditedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        cardId: op.cardId,
        title: op.title,
        version: card.version + 1,
        descriptionVersion: card.descriptionVersion,
      );
    case EditCardDescription():
      final card = board.cardById(op.cardId)!;
      return CardEditedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        cardId: op.cardId,
        description: op.description,
        version: card.version + 1,
        descriptionVersion: card.descriptionVersion + 1,
      );
    case MoveCard():
      final card = board.cardById(op.cardId)!;
      final current = board.cardsIn(op.toColumnId);
      final target = current.where((other) => other.id != card.id).toList();
      final index = resolveInsertIndex(
        target,
        afterId: op.afterId,
        beforeId: op.beforeId,
      );
      final unchanged =
          card.columnId == op.toColumnId &&
          current.indexWhere((c) => c.id == card.id) == index;
      return CardMovedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        cardId: op.cardId,
        fromColumnId: card.columnId,
        toColumnId: op.toColumnId,
        rank: unchanged ? card.rank : rankAtIndex(target, index),
        version: card.version + 1,
      );
    case ArchiveCard():
      final card = board.cardById(op.cardId)!;
      return CardArchivedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        cardId: op.cardId,
        columnId: card.columnId,
        version: card.version + 1,
      );
    case CreateColumn():
      final created = applyOp(board, op).columnById(op.columnId)!;
      return ColumnCreatedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        column: created,
      );
    case RenameColumn():
      final column = board.columnById(op.columnId)!;
      return ColumnRenamedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        columnId: op.columnId,
        title: op.title,
        version: column.version + 1,
      );
    case MoveColumn():
      final moved = applyOp(board, op).columnById(op.columnId)!;
      return ColumnMovedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        columnId: op.columnId,
        rank: moved.rank,
        version: moved.version,
      );
    case ArchiveColumn():
      final column = board.columnById(op.columnId)!;
      return ColumnArchivedEvent(
        seq: seq,
        serverTs: now,
        actorId: actorId,
        opId: op.opId,
        columnId: op.columnId,
        cardIds: <String>[
          for (final card in board.cards)
            if (card.columnId == op.columnId && !card.archived) card.id,
        ],
        version: column.version + 1,
      );
  }
}
