import '../../../core/network/api_failure.dart';
import '../../../core/realtime/connection_status.dart';
import '../../../core/result/result.dart';
import '../../boards/data/boards_api.dart';
import '../../boards/domain/board_info.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import 'board_gateway.dart';

class RestBoardGateway implements BoardGateway {
  RestBoardGateway._(this._snapshot);

  final BoardSnapshot _snapshot;

  static Future<Result<RestBoardGateway, ApiFailure>> load({
    required BoardsApi api,
    required String boardId,
    required CurrentUser currentUser,
  }) async {
    final (board, list) = await (api.getBoard(boardId), api.listBoards()).wait;
    switch (board) {
      case Failure<ServerBoard, ApiFailure>(:final failure):
        return Failure<RestBoardGateway, ApiFailure>(failure);
      case Success<ServerBoard, ApiFailure>(:final value):
        final others = list.valueOrNull ?? const <BoardInfo>[];
        return Success<RestBoardGateway, ApiFailure>(
          RestBoardGateway._(
            buildSnapshot(
              board: value,
              boards: others,
              currentUser: currentUser,
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
      board: _withCurrentMember(board, currentUser),
      currentUser: currentUser,
      boards: summaries,
      presence: BoardPresence(onlineUserIds: const <String>[]),
      connection: ConnectionStatus.offline,
    );
  }

  static BoardModel _withCurrentMember(
    ServerBoard board,
    CurrentUser currentUser,
  ) {
    final role = board.info.role;
    final members = <BoardMember>[
      for (final member in board.model.members)
        member.userId == currentUser.userId
            ? member.copyWith(role: role)
            : member,
    ];
    if (!members.any((member) => member.userId == currentUser.userId)) {
      members.add(
        BoardMember(
          userId: currentUser.userId,
          name: currentUser.name,
          avatarColor: currentUser.avatarColor,
          role: role,
        ),
      );
    }
    return board.model.copyWith(members: members);
  }

  @override
  BoardSnapshot snapshot() => _snapshot;

  @override
  Future<OpOutcome> submit(BoardOp op) async {
    throw UnsupportedError(
      'Board operations are not sent before realtime sync',
    );
  }
}
