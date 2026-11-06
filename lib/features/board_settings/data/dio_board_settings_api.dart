import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../../../core/result/result.dart';
import '../../boards/data/boards_dto.dart';
import '../../boards/domain/board_info.dart';
import 'board_settings_api.dart';

String _memberPath(String boardId, String userId) =>
    '${ApiPaths.board(boardId)}/members/${Uri.encodeComponent(userId)}';

class DioBoardSettingsApi implements BoardSettingsApi {
  DioBoardSettingsApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<BoardInfo, ApiFailure>> renameBoard(
    String boardId,
    String title,
  ) {
    return apiCall(() async {
      final response = await _dio.patch<dynamic>(
        ApiPaths.board(boardId),
        data: <String, String>{'title': title},
      );
      return boardInfoFromJson(response.data);
    });
  }

  @override
  Future<Result<void, ApiFailure>> deleteBoard(String boardId) {
    return apiCall(() async {
      await _dio.delete<dynamic>(ApiPaths.board(boardId));
    });
  }

  @override
  Future<Result<void, ApiFailure>> leaveBoard(String boardId, String userId) {
    return apiCall(() async {
      await _dio.delete<dynamic>(_memberPath(boardId, userId));
    });
  }
}
