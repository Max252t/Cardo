import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/board_info.dart';

abstract interface class BoardsApi {
  Future<Result<List<BoardInfo>, ApiFailure>> listBoards();

  Future<Result<BoardInfo, ApiFailure>> createBoard(String title);

  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId);
}
