import 'dart:async';

import '../domain/apply_op.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'board_gateway.dart';
import 'demo_board_fixture.dart';

typedef RejectPolicy = OpRejection? Function(BoardOp op);

class FakeBoardGateway implements BoardRemoteFeed {
  FakeBoardGateway({
    BoardSnapshot? initial,
    required this.confirmDelay,
    this.rejectWhen,
    this.announceConflicts = true,
  }) : _initial = initial ?? demoBoardSnapshot() {
    _server = _initial.board;
  }

  final BoardSnapshot _initial;
  final Duration confirmDelay;
  final RejectPolicy? rejectWhen;
  final bool announceConflicts;
  final Map<String, OpOutcome> _processed = <String, OpOutcome>{};
  late BoardModel _server;
  final StreamController<RemoteCardUpdate> _remote =
      StreamController<RemoteCardUpdate>.broadcast(sync: true);

  @override
  Stream<RemoteCardUpdate> get remoteUpdates => _remote.stream;

  Future<void> dispose() => _remote.close();

  BoardModel get serverBoard => _server;

  @override
  BoardSnapshot snapshot() {
    return BoardSnapshot(
      board: _server,
      currentUser: _initial.currentUser,
      boards: _initial.boards,
      presence: _initial.presence,
      connection: _initial.connection,
    );
  }

  @override
  Future<OpOutcome> submit(BoardOp op) async {
    await Future<void>.delayed(confirmDelay);
    final forced = rejectWhen?.call(op);
    if (forced != null) {
      return OpRejected(forced.withSeq(_server.seq));
    }
    final replay = _processed[op.opId];
    if (replay != null) {
      return replay;
    }
    final outcome = _process(op);
    _processed[op.opId] = outcome;
    return outcome;
  }

  OpOutcome _process(BoardOp op) {
    final reason = validate(_server, op);
    if (reason != null) {
      if (announceConflicts) {
        _announceConflict(op, reason);
      }
      return OpRejected(
        OpRejection(
          reason: reason,
          atSeq: _server.seq,
          actorId: reason == NackReason.versionConflict
              ? _conflictActor(op)
              : null,
          limit: reason == NackReason.validationError ? _limitOf(op) : null,
        ),
      );
    }
    final seq = _server.seq + 1;
    _server = applyOp(_server, op).copyWith(seq: seq);
    if (op is MoveCard) {
      _movers[op.cardId] = actorId;
    }
    if (op is EditCardDescription) {
      _describers[op.cardId] = actorId;
    }
    return OpConfirmed(seq: seq);
  }

  final Map<String, String> _movers = <String, String>{};
  final Map<String, String> _describers = <String, String>{};

  void _announceConflict(BoardOp op, NackReason reason) {
    if (op is! EditCardDescription || reason != NackReason.versionConflict) {
      return;
    }
    final author = _conflictActor(op);
    if (author != null) {
      _publish(op.cardId, author);
    }
  }

  void publishCard(String cardId) {
    final card = _server.cardById(cardId);
    final author = _describers[cardId] ?? card?.updatedBy;
    if (author != null) {
      _publish(cardId, author);
    }
  }

  void _publish(String cardId, String actorId) {
    final card = _server.cardById(cardId);
    if (card != null) {
      _remote.add(
        RemoteCardUpdate(card: card, seq: _server.seq, actorId: actorId),
      );
    }
  }

  static int _limitOf(BoardOp op) {
    return op is EditCardDescription
        ? CardLimits.descriptionMaxLength
        : CardLimits.titleMaxLength;
  }

  String? _conflictActor(BoardOp op) {
    if (op is EditCardDescription) {
      return _describers[op.cardId] ?? _server.cardById(op.cardId)?.updatedBy;
    }
    return _lastMover(op.cardId);
  }

  String get actorId => _initial.currentUser.userId;

  String? _lastMover(String cardId) {
    return _movers[cardId] ?? _server.cardById(cardId)?.updatedBy;
  }

  void simulateRemoteMove({
    required String cardId,
    required String toColumnId,
    required String actorId,
  }) {
    final card = _server.cardById(cardId);
    if (card == null) {
      return;
    }
    final op = MoveCard(
      opId: 'remote-$cardId-${_server.seq}',
      cardId: cardId,
      toColumnId: toColumnId,
      baseVersion: card.version,
    );
    _server = applyOp(_server, op).copyWith(seq: _server.seq + 1);
    _movers[cardId] = actorId;
  }

  void simulateRemoteDescriptionEdit({
    required String cardId,
    required String text,
    required String actorId,
    bool deliver = false,
  }) {
    final card = _server.cardById(cardId);
    if (card == null || card.archived) {
      return;
    }
    final op = EditCardDescription(
      opId: 'remote-$cardId-${_server.seq}',
      cardId: cardId,
      description: text,
      baseDescriptionVersion: card.descriptionVersion,
      actorId: actorId,
    );
    _server = applyOp(_server, op).copyWith(seq: _server.seq + 1);
    _describers[cardId] = actorId;
    if (deliver) {
      _publish(cardId, actorId);
    }
  }

  static NackReason? validate(BoardModel board, BoardOp op) {
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
        if (op.title.length > CardLimits.titleMaxLength) {
          return NackReason.validationError;
        }
        return null;
      case EditCardTitle():
        final card = board.cardById(op.cardId);
        if (card == null || card.archived) {
          return NackReason.notFound;
        }
        return op.title.length > CardLimits.titleMaxLength
            ? NackReason.validationError
            : null;
      case EditCardDescription():
        final card = board.cardById(op.cardId);
        if (card == null || card.archived) {
          return NackReason.notFound;
        }
        if (op.description.length > CardLimits.descriptionMaxLength) {
          return NackReason.validationError;
        }
        if (card.descriptionVersion != op.baseDescriptionVersion) {
          return NackReason.versionConflict;
        }
        return null;
      case ArchiveCard():
        return board.cardById(op.cardId) == null ? NackReason.notFound : null;
    }
  }
}
