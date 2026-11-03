import 'dart:math' as math;

import '../../../core/network/api_failure.dart';
import '../../../core/realtime/connection_status.dart';
import '../../../core/realtime/realtime_policy.dart';
import '../../../core/realtime/scheduler.dart';
import '../../../core/result/result.dart';
import '../../boards/data/boards_api.dart';
import '../../boards/domain/board_info.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import 'board_gateway.dart';
import 'realtime/board_sync_engine.dart';
import 'realtime/protocol_issue.dart';
import 'realtime/realtime_credentials.dart';
import 'realtime/realtime_transport.dart';
import 'realtime/server_snapshot.dart';
import 'sync_signal.dart';

class RealtimeSettings {
  const RealtimeSettings({
    required this.transport,
    required this.credentials,
    required this.wsBaseUri,
    this.scheduler = const SystemScheduler(),
    this.now,
    this.random,
    this.clientName = RealtimePolicy.clientName,
  });

  final RealtimeTransport transport;
  final RealtimeCredentials credentials;
  final Uri wsBaseUri;
  final Scheduler scheduler;
  final DateTime Function()? now;
  final math.Random? random;
  final String clientName;
}

class ServerBoardGateway implements BoardGateway {
  ServerBoardGateway(this._snapshot, this._engine);

  final BoardSnapshot _snapshot;
  final BoardSyncEngine _engine;

  static Future<Result<ServerBoardGateway, ApiFailure>> load({
    required BoardsApi api,
    required String boardId,
    required CurrentUser currentUser,
    required RealtimeSettings realtime,
  }) async {
    final (board, list) = await (api.getBoard(boardId), api.listBoards()).wait;
    switch (board) {
      case Failure<ServerBoard, ApiFailure>(:final failure):
        return Failure<ServerBoardGateway, ApiFailure>(failure);
      case Success<ServerBoard, ApiFailure>(:final value):
        final others = list.valueOrNull ?? const <BoardInfo>[];
        final snapshot = buildSnapshot(
          board: value,
          boards: others,
          currentUser: currentUser,
        );
        return Success<ServerBoardGateway, ApiFailure>(
          ServerBoardGateway(
            snapshot,
            BoardSyncEngine(
              boardId: boardId,
              currentUser: currentUser,
              wsBaseUri: realtime.wsBaseUri,
              transport: realtime.transport,
              credentials: realtime.credentials,
              catchUp: api,
              initialSeq: snapshot.board.seq,
              scheduler: realtime.scheduler,
              now: realtime.now,
              random: realtime.random,
              clientName: realtime.clientName,
            ),
          ),
        );
    }
  }

  static BoardSnapshot buildSnapshot({
    required ServerBoard board,
    required List<BoardInfo> boards,
    required CurrentUser currentUser,
  }) {
    final summaries = <BoardSummary>[
      for (final item in boards)
        BoardSummary(id: item.id, title: item.title, colorHex: ''),
    ];
    if (!summaries.any((summary) => summary.id == board.info.id)) {
      summaries.insert(
        0,
        BoardSummary(id: board.info.id, title: board.info.title, colorHex: ''),
      );
    }
    return BoardSnapshot(
      board: boardModelFor(board, currentUser),
      currentUser: currentUser,
      boards: summaries,
      presence: BoardPresence(onlineUserIds: const <String>[]),
      connection: ConnectionStatus.offline,
    );
  }

  BoardSyncEngine get engine => _engine;

  @override
  BoardSnapshot snapshot() => _snapshot;

  @override
  Stream<SyncSignal> get signals => _engine.signals;

  @override
  Stream<ProtocolIssue> get issues => _engine.issues;

  @override
  void connect() => _engine.start();

  @override
  SendOutcome send(BoardOp op) => _engine.send(op);

  @override
  void retryNow() => _engine.retryNow();

  @override
  Future<void> close() => _engine.close();

  @override
  Future<void> dispose() => _engine.dispose();
}
