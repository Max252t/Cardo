import '../../../core/equality/collection_equality.dart';
import '../../../core/realtime/connection_status.dart';
import 'apply_event.dart';
import 'apply_op.dart';
import 'board_event.dart';
import 'board_model.dart';
import 'board_op.dart';

enum PendingOpStatus { queued, sent, rejected }

enum NackReason {
  versionConflict,
  notFound,
  forbidden,
  validationError,
  rateLimited,
  resyncRequired,
  internal,
}

enum BoardEndReason {
  removed,
  boardDeleted,
  accessLost,
  sessionEnded,
  unsupported,
}

enum CardSyncStatus { confirmed, pending, rejected }

class OpRejection {
  const OpRejection({
    required this.reason,
    this.atSeq,
    this.actorId,
    this.limit,
  });

  final NackReason reason;
  final int? atSeq;
  final String? actorId;
  final int? limit;

  OpRejection withSeq(int seq) {
    return OpRejection(
      reason: reason,
      atSeq: atSeq ?? seq,
      actorId: actorId,
      limit: limit,
    );
  }

  OpRejection withActor(String? actor) {
    return OpRejection(
      reason: reason,
      atSeq: atSeq,
      actorId: actor,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OpRejection &&
        other.reason == reason &&
        other.atSeq == atSeq &&
        other.actorId == actorId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(reason, atSeq, actorId, limit);

  @override
  String toString() => 'OpRejection(${reason.name}, at $atSeq)';
}

class PendingOp {
  const PendingOp({
    required this.op,
    required this.status,
    required this.createdAt,
    this.rejection,
    this.failedAttempts = 0,
  });

  final BoardOp op;
  final PendingOpStatus status;
  final DateTime createdAt;
  final OpRejection? rejection;
  final int failedAttempts;

  String get opId => op.opId;

  bool get isRejected => status == PendingOpStatus.rejected;

  bool get isDescriptionConflict =>
      isRejected &&
      op is EditCardDescription &&
      rejection?.reason == NackReason.versionConflict;

  bool get isBlocking => isRejected && !isDescriptionConflict;

  PendingOp copyWith({
    BoardOp? op,
    PendingOpStatus? status,
    DateTime? createdAt,
    OpRejection? rejection,
    int? failedAttempts,
  }) {
    return PendingOp(
      op: op ?? this.op,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rejection: rejection ?? this.rejection,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PendingOp &&
        other.op == op &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.rejection == rejection &&
        other.failedAttempts == failedAttempts;
  }

  @override
  int get hashCode =>
      Object.hash(op, status, createdAt, rejection, failedAttempts);

  @override
  String toString() => 'PendingOp($op, ${status.name})';
}

class BoardSyncState {
  BoardSyncState({
    required this.confirmed,
    required this.lastSeq,
    required List<PendingOp> pending,
    required this.connection,
    this.reconnectSeconds,
    this.ended,
    Set<String> abandoned = const <String>{},
  }) : pending = List<PendingOp>.unmodifiable(pending),
       abandoned = Set<String>.unmodifiable(abandoned);

  final BoardModel confirmed;
  final int lastSeq;
  final List<PendingOp> pending;
  final ConnectionStatus connection;
  final int? reconnectSeconds;
  final BoardEndReason? ended;
  final Set<String> abandoned;

  BoardModel get view =>
      pending.fold(confirmed, (board, item) => applyOp(board, item.op));

  BoardModel get liveView => pending
      .where((item) => !item.isRejected)
      .fold(confirmed, (board, item) => applyOp(board, item.op));

  List<PendingOp> get rejected =>
      pending.where((item) => item.isRejected).toList(growable: false);

  PendingOp? pendingById(String opId) {
    for (final item in pending) {
      if (item.opId == opId) {
        return item;
      }
    }
    return null;
  }

  PendingOp? _rejectedFor(String cardId, {bool blockingOnly = false}) {
    for (final item in pending) {
      if (item.op.cardId == cardId &&
          item.isRejected &&
          (!blockingOnly || item.isBlocking)) {
        return item;
      }
    }
    return null;
  }

  CardSyncStatus cardStatus(String cardId) {
    if (_rejectedFor(cardId) != null) {
      return CardSyncStatus.rejected;
    }
    return pending.any((item) => item.op.cardId == cardId)
        ? CardSyncStatus.pending
        : CardSyncStatus.confirmed;
  }

  OpRejection? blockingRejection(String cardId) =>
      _rejectedFor(cardId, blockingOnly: true)?.rejection;

  bool hasBlockingRejection(String cardId) =>
      _rejectedFor(cardId, blockingOnly: true) != null;

  OpRejection? cardRejection(String cardId) => _rejectedFor(cardId)?.rejection;

  bool hasRejectedCreate(String cardId) => pending.any(
    (item) =>
        item.isRejected && item.op is CreateCard && item.op.cardId == cardId,
  );

  BoardSyncState withoutOps(Set<String> opIds) {
    if (opIds.isEmpty || !pending.any((item) => opIds.contains(item.opId))) {
      return this;
    }
    return copyWith(
      pending: pending.where((item) => !opIds.contains(item.opId)).toList(),
    );
  }

  BoardSyncState applyServerEvents(List<BoardEvent> events) {
    if (events.isEmpty) {
      return this;
    }
    final resolved = <String>{for (final event in events) ?event.opId};
    final next = applyEvents(confirmed, events);
    return copyWith(
      confirmed: next,
      lastSeq: next.seq,
      pending: resolved.isEmpty
          ? pending
          : pending.where((item) => !resolved.contains(item.opId)).toList(),
    );
  }

  BoardSyncState replaceConfirmed(BoardModel board) {
    return copyWith(confirmed: board, lastSeq: board.seq);
  }

  BoardSyncState withoutStale(DateTime now, Duration maxAge) {
    final dropped = <String>{};
    final droppedCards = <String>{};
    for (final item in pending) {
      if (!item.isRejected && now.difference(item.createdAt) > maxAge) {
        dropped.add(item.opId);
        final op = item.op;
        if (op is CreateCard) {
          droppedCards.add(op.cardId);
        }
      }
    }
    if (dropped.isEmpty) {
      return this;
    }
    final kept = <PendingOp>[];
    final gone = <String>{...dropped};
    for (final item in pending) {
      final cardId = item.op.cardId;
      if (dropped.contains(item.opId) ||
          (cardId != null && droppedCards.contains(cardId))) {
        gone.add(item.opId);
      } else {
        kept.add(item);
      }
    }
    return copyWith(pending: kept, abandoned: <String>{...abandoned, ...gone});
  }

  BoardSyncState rebased() {
    var board = confirmed;
    final kept = <PendingOp>[];
    final gone = <String>{};
    for (final item in pending) {
      if (item.isRejected) {
        kept.add(item);
        continue;
      }
      if (canApplyOp(board, item.op)) {
        board = applyOp(board, item.op);
        kept.add(item);
      } else {
        gone.add(item.opId);
      }
    }
    return gone.isEmpty
        ? this
        : copyWith(pending: kept, abandoned: <String>{...abandoned, ...gone});
  }

  BoardSyncState copyWith({
    BoardModel? confirmed,
    int? lastSeq,
    List<PendingOp>? pending,
    ConnectionStatus? connection,
    int? reconnectSeconds,
    bool clearReconnectSeconds = false,
    BoardEndReason? ended,
    Set<String>? abandoned,
  }) {
    return BoardSyncState(
      confirmed: confirmed ?? this.confirmed,
      lastSeq: lastSeq ?? this.lastSeq,
      pending: pending ?? this.pending,
      connection: connection ?? this.connection,
      reconnectSeconds: clearReconnectSeconds
          ? null
          : reconnectSeconds ?? this.reconnectSeconds,
      ended: ended ?? this.ended,
      abandoned: abandoned ?? this.abandoned,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoardSyncState &&
        other.confirmed == confirmed &&
        other.lastSeq == lastSeq &&
        listEquals(other.pending, pending) &&
        other.connection == connection &&
        other.reconnectSeconds == reconnectSeconds &&
        other.ended == ended &&
        other.abandoned.length == abandoned.length &&
        other.abandoned.containsAll(abandoned);
  }

  @override
  int get hashCode => Object.hash(
    confirmed,
    lastSeq,
    Object.hashAll(pending),
    connection,
    reconnectSeconds,
    ended,
    abandoned.length,
  );

  @override
  String toString() =>
      'BoardSyncState(seq $lastSeq, ${pending.length} pending, '
      '${connection.name})';
}
