import 'dart:math' as math;

import '../../../core/models/board_role.dart';
import '../../../core/realtime/connection_status.dart';
import '../../../core/realtime/scheduler.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'demo_board_fixture.dart';
import 'fake/fake_board_server.dart';
import 'fake/server_ops.dart';
import 'realtime/board_sync_engine.dart';
import 'realtime/realtime_credentials.dart';
import 'server_board_gateway.dart';

export 'fake/fake_board_server.dart' show RejectPolicy;

class FakeBoardGateway extends ServerBoardGateway {
  factory FakeBoardGateway({
    BoardSnapshot? initial,
    required Duration confirmDelay,
    RejectPolicy? rejectWhen,
    bool announceConflicts = true,
    Scheduler scheduler = const SystemScheduler(),
    math.Random? random,
    DateTime Function()? now,
  }) {
    final base = initial ?? demoBoardSnapshot();
    final server = FakeBoardServer(
      initial: base.board,
      currentUserId: base.currentUser.userId,
      latency: confirmDelay,
      scheduler: scheduler,
      now: now,
      rejectWhen: rejectWhen,
      announceConflicts: announceConflicts,
      online: <PresenceUser>[
        for (final userId in base.presence.onlineUserIds)
          if (base.board.memberById(userId) case final member?)
            PresenceUser(
              userId: member.userId,
              name: member.name,
              avatarColor: member.avatarColor,
            ),
      ],
    );
    final snapshot = BoardSnapshot(
      board: base.board,
      currentUser: base.currentUser,
      boards: base.boards,
      presence: base.presence,
      connection: ConnectionStatus.syncing,
    );
    final engine = BoardSyncEngine(
      boardId: base.board.id,
      currentUser: base.currentUser,
      wsBaseUri: Uri(scheme: 'ws', host: 'fake.invalid'),
      transport: server,
      credentials: StaticCredentials(),
      catchUp: server,
      initialSeq: base.board.seq,
      scheduler: scheduler,
      now: now,
      random: random ?? math.Random(7),
    );
    return FakeBoardGateway._(server, snapshot, engine);
  }

  FakeBoardGateway._(
    this.server,
    BoardSnapshot snapshot,
    BoardSyncEngine engine,
  ) : super(snapshot, engine);

  final FakeBoardServer server;

  BoardModel get serverBoard => server.board;

  String get actorId => snapshot().currentUser.userId;

  static NackReason? validate(
    BoardModel board,
    BoardOp op, {
    BoardRole? role,
  }) => validateOp(board, op, role: role);

  void simulateRemoteMove({
    required String cardId,
    required String toColumnId,
    required String actorId,
    bool deliver = true,
  }) {
    final card = server.board.cardById(cardId);
    if (card == null) {
      return;
    }
    server.commitRemote(
      MoveCard(
        opId: 'remote-$cardId-${server.seq}',
        cardId: cardId,
        toColumnId: toColumnId,
        baseVersion: card.version,
      ),
      actorId: actorId,
      deliver: deliver,
    );
  }

  void simulateRemoteDescriptionEdit({
    required String cardId,
    required String text,
    required String actorId,
    bool deliver = false,
  }) {
    final card = server.board.cardById(cardId);
    if (card == null || card.archived) {
      return;
    }
    server.commitRemote(
      EditCardDescription(
        opId: 'remote-$cardId-${server.seq}',
        cardId: cardId,
        description: text,
        baseDescriptionVersion: card.descriptionVersion,
        actorId: actorId,
      ),
      actorId: actorId,
      deliver: deliver,
    );
  }

  void publishCard(String cardId) => server.flushHeld();
}
