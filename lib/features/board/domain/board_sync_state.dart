import 'package:flutter/foundation.dart';

import '../../../core/realtime/connection_status.dart';
import 'apply_op.dart';
import 'board_model.dart';
import 'board_op.dart';

enum PendingOpStatus { queued, sent, rejected }

enum NackReason {
  versionConflict,
  notFound,
  forbidden,
  validationError,
  rateLimited,
  internal,
}

enum CardSyncStatus { confirmed, pending, rejected }

@immutable
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

@immutable
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

@immutable
class BoardSyncState {
  BoardSyncState({
    required this.confirmed,
    required this.lastSeq,
    required List<PendingOp> pending,
    required this.connection,
  }) : pending = List<PendingOp>.unmodifiable(pending);

  final BoardModel confirmed;
  final int lastSeq;
  final List<PendingOp> pending;
  final ConnectionStatus connection;

  BoardModel get view =>
      pending.fold(confirmed, (board, item) => applyOp(board, item.op));

  BoardModel get liveView => pending
      .where((item) => !item.isRejected)
      .fold(confirmed, (board, item) => applyOp(board, item.op));

  List<PendingOp> get rejected =>
      pending.where((item) => item.isRejected).toList(growable: false);

  CardSyncStatus cardStatus(String cardId) {
    var status = CardSyncStatus.confirmed;
    for (final item in pending) {
      if (item.op.cardId != cardId) {
        continue;
      }
      if (item.isRejected) {
        return CardSyncStatus.rejected;
      }
      status = CardSyncStatus.pending;
    }
    return status;
  }

  OpRejection? cardRejection(String cardId) {
    for (final item in pending) {
      if (item.op.cardId == cardId && item.isRejected) {
        return item.rejection;
      }
    }
    return null;
  }

  BoardSyncState copyWith({
    BoardModel? confirmed,
    int? lastSeq,
    List<PendingOp>? pending,
    ConnectionStatus? connection,
  }) {
    return BoardSyncState(
      confirmed: confirmed ?? this.confirmed,
      lastSeq: lastSeq ?? this.lastSeq,
      pending: pending ?? this.pending,
      connection: connection ?? this.connection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoardSyncState &&
        other.confirmed == confirmed &&
        other.lastSeq == lastSeq &&
        listEquals(other.pending, pending) &&
        other.connection == connection;
  }

  @override
  int get hashCode =>
      Object.hash(confirmed, lastSeq, Object.hashAll(pending), connection);

  @override
  String toString() =>
      'BoardSyncState(seq $lastSeq, ${pending.length} pending, '
      '${connection.name})';
}
