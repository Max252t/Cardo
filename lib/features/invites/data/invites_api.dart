import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../boards/domain/board_info.dart';

abstract interface class InvitesApi {
  Future<Result<BoardInfo, ApiFailure>> acceptInvite(String token);
}
