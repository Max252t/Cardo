import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../boards/domain/board_info.dart';

abstract interface class BoardSettingsApi {
  Future<Result<BoardInfo, ApiFailure>> renameBoard(
    String boardId,
    String title,
  );

  Future<Result<void, ApiFailure>> deleteBoard(String boardId);

  Future<Result<void, ApiFailure>> leaveBoard(String boardId, String userId);
}
