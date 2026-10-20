import '../domain/apply_op.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'board_gateway.dart';
import 'demo_board_fixture.dart';

typedef RejectPolicy = OpRejection? Function(BoardOp op);

class FakeBoardGateway implements BoardGateway {
  FakeBoardGateway({
    BoardSnapshot? initial,
    required this.confirmDelay,
    this.rejectWhen,
  }) : _initial = initial ?? demoBoardSnapshot() {
    _server = _initial.board;
  }

  final BoardSnapshot _initial;
  final Duration confirmDelay;
  final RejectPolicy? rejectWhen;
  late BoardModel _server;

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
    final reason = validate(_server, op);
    if (reason != null) {
      return OpRejected(
        OpRejection(
          reason: reason,
          atSeq: _server.seq,
          actorId: reason == NackReason.versionConflict
              ? _lastMover(op.cardId)
              : null,
          limit: reason == NackReason.validationError
              ? CardLimits.titleMaxLength
              : null,
        ),
      );
    }
    final seq = _server.seq + 1;
    _server = applyOp(_server, op).copyWith(seq: seq);
    if (op is MoveCard) {
      _movers[op.cardId] = actorId;
    }
    return OpConfirmed(seq: seq);
  }

  final Map<String, String> _movers = <String, String>{};

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
      case ArchiveCard():
        return board.cardById(op.cardId) == null ? NackReason.notFound : null;
    }
  }
}
