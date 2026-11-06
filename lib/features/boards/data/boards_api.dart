import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../board/data/realtime/board_catch_up.dart';
import '../domain/board_info.dart';

abstract interface class BoardsApi implements BoardCatchUpSource {
  Future<Result<List<BoardInfo>, ApiFailure>> listBoards();

  Future<Result<BoardInfo, ApiFailure>> createBoard(String title);

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId);
}
