import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../../../core/result/result.dart';
import '../domain/board_info.dart';
import 'boards_api.dart';
import 'boards_dto.dart';

class DioBoardsApi implements BoardsApi {
  DioBoardsApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<BoardInfo>, ApiFailure>> listBoards() {
    return apiCall(() async {
      final response = await _dio.get<dynamic>(ApiPaths.boards);
      return boardListFromJson(response.data);
    });
  }

  @override
  Future<Result<BoardInfo, ApiFailure>> createBoard(String title) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        ApiPaths.boards,
        data: <String, String>{'title': title},
      );
      return boardInfoFromJson(response.data);
    });
  }

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId) {
    return apiCall(() async {
      final response = await _dio.get<dynamic>(ApiPaths.board(boardId));
      return serverBoardFromJson(response.data);
    });
  }
}
