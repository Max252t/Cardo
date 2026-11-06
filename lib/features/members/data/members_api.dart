import '../../../core/models/board_role.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/board_invite.dart';
import '../domain/roster_member.dart';

abstract interface class MembersApi {
  Future<Result<List<RosterMember>, ApiFailure>> listMembers(String boardId);

  Future<Result<RosterMember, ApiFailure>> addMember(
    String boardId, {
    required String email,
    required BoardRole role,
  });

  Future<Result<RosterMember, ApiFailure>> changeRole(
    String boardId,
    String userId,
    BoardRole role,
  );

  Future<Result<void, ApiFailure>> removeMember(String boardId, String userId);

  Future<Result<List<BoardInvite>, ApiFailure>> listInvites(String boardId);

  Future<Result<CreatedInvite, ApiFailure>> createInvite(
    String boardId, {
    required BoardRole role,
    Duration? expiresIn,
    int? maxUses,
  });

  Future<Result<void, ApiFailure>> revokeInvite(
    String boardId,
    String inviteId,
  );
}
