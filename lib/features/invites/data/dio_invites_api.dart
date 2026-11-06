import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../boards/data/boards_dto.dart';
import '../../boards/domain/board_info.dart';
import 'invites_api.dart';

String _acceptPath(String token) =>
    '/api/invites/${Uri.encodeComponent(token)}/accept';

class DioInvitesApi implements InvitesApi {
  DioInvitesApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<BoardInfo, ApiFailure>> acceptInvite(String token) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(_acceptPath(token));
      return boardInfoFromJson(response.data);
    });
  }
}
