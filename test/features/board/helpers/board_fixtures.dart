import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/ranking/rank.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
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
  GatewayCall(this.op);

  final BoardOp op;
  final Completer<OpOutcome> completer = Completer<OpOutcome>();
}

class ControlledGateway implements BoardGateway {
  ControlledGateway({BoardSnapshot? initial})
    : _snapshot = initial ?? demoBoardSnapshot();

  final BoardSnapshot _snapshot;
  final List<GatewayCall> calls = <GatewayCall>[];

  @override
  BoardSnapshot snapshot() => _snapshot;

  @override
  Future<OpOutcome> submit(BoardOp op) {
    final call = GatewayCall(op);
    calls.add(call);
    return call.completer.future;
  }
}
