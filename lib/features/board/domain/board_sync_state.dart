import '../../../core/equality/collection_equality.dart';
import '../../../core/realtime/connection_status.dart';
import 'apply_event.dart';
import 'apply_op.dart';
import 'board_event.dart';
import 'board_model.dart';
import 'board_op.dart';
import 'op_rejection.dart';
import 'reconnect_batch.dart';
import 'rejection_log.dart';

export 'op_rejection.dart';
export 'reconnect_batch.dart';
export 'rejection_log.dart';

enum PendingOpStatus { queued, sent, rejected }

enum BoardEndReason {
  removed,
  boardDeleted,
  accessLost,
  sessionEnded,
  unsupported,
}

enum CardSyncStatus { confirmed, pending, rejected }

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
    this.rejections = const RejectionLog.empty(),
    this.batch,
    this.summary,
  }) : pending = List<PendingOp>.unmodifiable(pending),
       abandoned = Set<String>.unmodifiable(abandoned);

  final BoardModel confirmed;
  final int lastSeq;
  final List<PendingOp> pending;
  final ConnectionStatus connection;
  final int? reconnectSeconds;
  final BoardEndReason? ended;
  final Set<String> abandoned;
  final RejectionLog rejections;
  final ReconnectBatch? batch;
  final SyncSummary? summary;

  int get waitingCount => pending.where((item) => !item.isRejected).length;

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

  bool dependsOnRejectedColumnCreate(BoardOp op) => pending.any((item) {
    final other = item.op;
    return item.isRejected &&
        other is CreateColumn &&
        other.opId != op.opId &&
        op.referencesColumn(other.columnId);
  });

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
    final droppedColumns = <String>{};
    for (final item in pending) {
      if (!item.isRejected && now.difference(item.createdAt) > maxAge) {
        dropped.add(item.opId);
        final op = item.op;
        if (op is CreateCard) {
          droppedCards.add(op.cardId);
        }
        if (op is CreateColumn) {
          droppedColumns.add(op.columnId);
        }
      }
    }
    if (dropped.isEmpty) {
      return this;
    }
    final kept = <PendingOp>[];
    final gone = <String>{...dropped};
    final logged = <RejectedOp>[];
    final before = view;
    for (final item in pending) {
      final cardId = item.op.cardId;
      final stale = dropped.contains(item.opId);
      final orphan =
          (cardId != null && droppedCards.contains(cardId)) ||
          droppedColumns.any(item.op.referencesColumn);
      if (stale || orphan) {
        gone.add(item.opId);
        if (!item.isDescriptionConflict) {
          logged.add(
            describeRejected(
              item.op,
              confirmed,
              before,
              dropCause: stale ? DropCause.stale : DropCause.targetGone,
            ),
          );
        }
      } else {
        kept.add(item);
      }
    }
    return copyWith(
      pending: kept,
      abandoned: <String>{...abandoned, ...gone},
      rejections: rejections.add(logged),
    );
  }

  BoardSyncState rebased() {
    var board = confirmed;
    final kept = <PendingOp>[];
    final gone = <String>{};
    final logged = <RejectedOp>[];
    final before = view;
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
        logged.add(
          describeRejected(
            item.op,
            confirmed,
            before,
            dropCause: DropCause.targetGone,
          ),
        );
      }
    }
    return gone.isEmpty
        ? this
        : copyWith(
            pending: kept,
            abandoned: <String>{...abandoned, ...gone},
            rejections: rejections.add(logged),
          );
  }

  BoardSyncState withRejectionLogged(String opId) {
    final item = pendingById(opId);
    if (item == null || !item.isRejected || item.isDescriptionConflict) {
      return this;
    }
    final op = item.op;
    final entries = <RejectedOp>[
      describeRejected(op, confirmed, view, rejection: item.rejection),
    ];
    if (op is CreateCard || op is CreateColumn) {
      for (final other in pending) {
        final dependent = switch (op) {
          CreateCard() => other.op.cardId == op.cardId,
          CreateColumn() => other.op.referencesColumn(op.columnId),
          _ => false,
        };
        if (other.opId != opId && !other.isRejected && dependent) {
          entries.add(
            describeRejected(
              other.op,
              confirmed,
              view,
              dropCause: DropCause.targetGone,
            ),
          );
        }
      }
    }
    return copyWith(rejections: rejections.add(entries))._capped();
  }

  Set<String> get _protectedIds => <String>{
    ...?batch?.ids,
    ...?summary?.failedIds,
  };

  BoardSyncState _capped() {
    final next = rejections.capped(_protectedIds);
    return identical(next, rejections) ? this : copyWith(rejections: next);
  }

  BoardSyncState afterReady(
    DateTime now,
    Duration maxAge, {
    bool reconnect = true,
  }) {
    final queued = <String>[
      for (final item in pending)
        if (!item.isRejected) item.opId,
    ];
    final next = withoutStale(now, maxAge).rebased();
    final tracked = reconnect
        ? queued
        : <String>[
            for (final id in queued)
              if (next.pendingById(id) == null) id,
          ];
    if (tracked.isEmpty) {
      return next._capped();
    }
    return next
        .copyWith(batch: batch?.merge(tracked) ?? ReconnectBatch(ids: tracked))
        .settleBatch();
  }

  BoardSyncState afterSnapshot(BoardModel board) {
    final queued = <String>[
      for (final item in pending)
        if (!item.isRejected) item.opId,
    ];
    final next = replaceConfirmed(board).rebased();
    final dropped = <String>[
      for (final id in queued)
        if (next.pendingById(id) == null) id,
    ];
    if (dropped.isEmpty) {
      return next._capped();
    }
    return next
        .copyWith(
          batch: next.batch?.merge(dropped) ?? ReconnectBatch(ids: dropped),
        )
        .settleBatch();
  }

  bool _unresolved(String opId) {
    final item = pendingById(opId);
    if (item == null || item.isRejected) {
      return false;
    }
    final cardId = item.op.cardId;
    return (cardId == null || !hasRejectedCreate(cardId)) &&
        !dependsOnRejectedColumnCreate(item.op);
  }

  BoardSyncState settleBatch() {
    final current = batch;
    if (current == null) {
      return this;
    }
    if (current.ids.any(_unresolved)) {
      final noted = current.withHeld(_heldIn(current));
      return identical(noted, current) ? this : copyWith(batch: noted);
    }
    final failed = <String>[
      for (final id in current.ids)
        if (rejections.contains(id)) id,
    ];
    final held = <String>{...current.held, ..._heldIn(current)};
    final saved = current.ids
        .where((id) => !held.contains(id) && !rejections.contains(id))
        .length;
    final existing = summary;
    return copyWith(
      clearBatch: true,
      summary: failed.isEmpty
          ? existing
          : existing == null
          ? SyncSummary(failedIds: failed, savedCount: saved)
          : existing.merge(failed, saved),
    )._capped();
  }

  Iterable<String> _heldIn(ReconnectBatch current) sync* {
    for (final id in current.ids) {
      if (pendingById(id)?.isDescriptionConflict ?? false) {
        yield id;
      }
    }
  }

  BoardSyncState dismissedSummary() {
    return summary == null ? this : copyWith(clearSummary: true);
  }

  BoardSyncState acknowledgedRejections() {
    if (summary == null && rejections.isEmpty) {
      return this;
    }
    return copyWith(
      clearSummary: true,
      rejections: rejections.only(<String>{...?batch?.ids}),
    );
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
    RejectionLog? rejections,
    ReconnectBatch? batch,
    bool clearBatch = false,
    SyncSummary? summary,
    bool clearSummary = false,
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
      rejections: rejections ?? this.rejections,
      batch: clearBatch ? null : batch ?? this.batch,
      summary: clearSummary ? null : summary ?? this.summary,
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
        other.abandoned.containsAll(abandoned) &&
        other.rejections == rejections &&
        other.batch == batch &&
        other.summary == summary;
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
    rejections,
    batch,
    summary,
  );

  @override
  String toString() =>
      'BoardSyncState(seq $lastSeq, ${pending.length} pending, '
      '${connection.name})';
}
