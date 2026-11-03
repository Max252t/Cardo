import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/ranking/rank.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/fake/server_ops.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/apply_event.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/seq_ordering.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String colA = 'col-a';
const String colB = 'col-b';
const String colC = 'col-c';

CardModel makeCard(
  String id,
  String columnId,
  String rank, {
  int version = 1,
  bool archived = false,
}) {
  return CardModel(
    id: id,
    columnId: columnId,
    title: 'Card $id',
    rank: rank,
    version: version,
    createdBy: 'u1',
    updatedBy: 'u1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    archived: archived,
  );
}

BoardModel makeBoard() {
  final ranksA = ranksSequence(3);
  final ranksB = ranksSequence(2);
  final columns = ranksSequence(3);
  return BoardModel(
    id: 'board',
    title: 'Board',
    seq: 10,
    columns: <ColumnModel>[
      ColumnModel(
        id: colA,
        title: 'A',
        rank: columns[0],
        version: 1,
        marker: ColumnMarker.backlog,
      ),
      ColumnModel(
        id: colB,
        title: 'B',
        rank: columns[1],
        version: 1,
        marker: ColumnMarker.inProgress,
      ),
      ColumnModel(
        id: colC,
        title: 'C',
        rank: columns[2],
        version: 1,
        marker: ColumnMarker.done,
      ),
    ],
    cards: <CardModel>[
      makeCard('a1', colA, ranksA[0]),
      makeCard('a2', colA, ranksA[1]),
      makeCard('a3', colA, ranksA[2]),
      makeCard('b1', colB, ranksB[0]),
      makeCard('b2', colB, ranksB[1], version: 4),
    ],
    members: const <BoardMember>[
      BoardMember(
        userId: 'u1',
        name: 'One',
        avatarColor: '#2D68F5',
        role: BoardRole.editor,
      ),
    ],
  );
}

List<String> ids(BoardModel board, String columnId) {
  return board.cardsIn(columnId).map((card) => card.id).toList();
}

MoveCard moveOp(
  String cardId,
  String toColumnId, {
  String? afterId,
  String? beforeId,
  int baseVersion = 1,
  String opId = 'op',
}) {
  return MoveCard(
    opId: opId,
    cardId: cardId,
    toColumnId: toColumnId,
    afterId: afterId,
    beforeId: beforeId,
    baseVersion: baseVersion,
  );
}

class IdSequence {
  int _next = 0;

  String call() => 'id-${_next++}';
}

ProviderContainer makeContainer({
  BoardGateway? gateway,
  BoardRole role = BoardRole.editor,
  BoardSyncConfig config = const BoardSyncConfig(
    nackHold: Duration(milliseconds: 100),
    retryDelay: Duration(milliseconds: 50),
    maxInternalRetries: 2,
  ),
  DateTime? now,
}) {
  final fake =
      gateway ??
      FakeBoardGateway(
        initial: demoBoardSnapshot(currentUserRole: role),
        confirmDelay: Duration.zero,
      );
  final ids = IdSequence();
  final container = ProviderContainer(
    overrides: [
      boardGatewayProvider.overrideWithValue(fake),
      idGeneratorProvider.overrideWithValue(ids.call),
      nowProvider.overrideWithValue(() => now ?? DateTime.utc(2026, 1, 1, 12)),
      boardSyncConfigProvider.overrideWithValue(config),
    ],
  );
  return container;
}

OpRejection rejection(NackReason reason) => OpRejection(reason: reason);

class GatewayCall {
  GatewayCall(this.gateway, this.op);

  final ControlledGateway gateway;
  final BoardOp op;

  void confirm(int seq) => gateway.confirm(op, seq);

  void reject(NackReason reason, {int? atSeq}) =>
      gateway.reject(op, reason, atSeq: atSeq);

  void rejectWith(OpRejection rejection) => gateway.rejectWith(op, rejection);
}

class ControlledGateway implements BoardGateway {
  ControlledGateway({BoardSnapshot? initial})
    : _snapshot = initial ?? demoBoardSnapshot() {
    _server = _snapshot.board;
    _ordering = SeqOrdering(_snapshot.board.seq);
  }

  final BoardSnapshot _snapshot;
  final List<GatewayCall> calls = <GatewayCall>[];
  final StreamController<SyncSignal> _signals =
      StreamController<SyncSignal>.broadcast(sync: true);
  late BoardModel _server;
  late final SeqOrdering _ordering;
  SendOutcome nextOutcome = SendOutcome.sent;
  int connects = 0;
  int closes = 0;
  int retries = 0;

  @override
  BoardSnapshot snapshot() => _snapshot;

  @override
  Stream<SyncSignal> get signals => _signals.stream;

  @override
  Stream<ProtocolIssue> get issues => const Stream<ProtocolIssue>.empty();

  @override
  void connect() => connects++;

  @override
  SendOutcome send(BoardOp op) {
    final outcome = nextOutcome;
    if (outcome == SendOutcome.sent) {
      calls.add(GatewayCall(this, op));
    }
    return outcome;
  }

  @override
  void retryNow() => retries++;

  @override
  Future<void> close() async => closes++;

  @override
  Future<void> dispose() => _signals.close();

  void emit(SyncSignal signal) => _signals.add(signal);

  void push(BoardEvent event) {
    final intake = _ordering.accept(event);
    for (final ready in intake.ready) {
      _server = applyEvent(_server, ready);
    }
    if (intake.duplicateOpIds.isNotEmpty) {
      emit(DuplicatesSignal(intake.duplicateOpIds));
    }
    if (intake.ready.isNotEmpty) {
      emit(EventsSignal(intake.ready));
    }
  }

  void confirm(BoardOp op, int seq) {
    final verdict = judgeOp(
      _server,
      op,
      seq: seq,
      actorId: _snapshot.currentUser.userId,
      now: DateTime.utc(2026, 1, 1, 12),
    );
    if (verdict is! OpAccepted) {
      throw StateError('operation $op is not acceptable on the server');
    }
    push(verdict.event);
  }

  void reject(BoardOp op, NackReason reason, {int? atSeq}) {
    rejectWith(op, OpRejection(reason: reason, atSeq: atSeq));
  }

  void rejectWith(BoardOp op, OpRejection rejection) {
    emit(
      NackSignal(
        opId: op.opId,
        rejection: rejection.withSeq(_ordering.lastSeq),
      ),
    );
  }

  void pushDescription(
    String cardId,
    String text, {
    required int descriptionVersion,
    String actorId = DemoIds.maxim,
    int? seq,
  }) {
    final card = _server.cardById(cardId)!;
    push(
      CardEditedEvent(
        seq: seq ?? _ordering.lastSeq + 1,
        serverTs: demoReferenceTime,
        actorId: actorId,
        cardId: cardId,
        description: text,
        version: card.version + 1,
        descriptionVersion: descriptionVersion,
      ),
    );
  }
}

CardModel demoCard(String cardId) => demoBoard().cardById(cardId)!;
