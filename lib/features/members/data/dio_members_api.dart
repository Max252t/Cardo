import 'package:dio/dio.dart';

import '../../../core/models/board_role.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../../../core/result/result.dart';
import '../domain/board_invite.dart';
import '../domain/roster_member.dart';
import 'members_api.dart';
import 'members_dto.dart';

abstract final class MembersPaths {
  static String members(String boardId) => '${ApiPaths.board(boardId)}/members';

  static String member(String boardId, String userId) =>
      '${members(boardId)}/${Uri.encodeComponent(userId)}';

  static String invites(String boardId) => '${ApiPaths.board(boardId)}/invites';

  static String invite(String boardId, String inviteId) =>
      '${invites(boardId)}/${Uri.encodeComponent(inviteId)}';
}

class DioMembersApi implements MembersApi {
  DioMembersApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<RosterMember>, ApiFailure>> listMembers(String boardId) {
    return apiCall(() async {
      final response = await _dio.get<dynamic>(MembersPaths.members(boardId));
      return rosterFromJson(response.data);
    });
  }

  @override
  Future<Result<RosterMember, ApiFailure>> addMember(
    String boardId, {
    required String email,
    required BoardRole role,
  }) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        MembersPaths.members(boardId),
        data: addMemberBody(email: email, role: role),
      );
      return rosterMemberFromJson(response.data);
    });
  }

  @override
  Future<Result<RosterMember, ApiFailure>> changeRole(
    String boardId,
    String userId,
    BoardRole role,
  ) {
    return apiCall(() async {
      final response = await _dio.patch<dynamic>(
        MembersPaths.member(boardId, userId),
        data: changeRoleBody(role),
      );
      return rosterMemberFromJson(response.data);
    });
  }

  @override
  Future<Result<void, ApiFailure>> removeMember(String boardId, String userId) {
    return apiCall(() async {
      await _dio.delete<dynamic>(MembersPaths.member(boardId, userId));
    });
  }

  @override
  Future<Result<List<BoardInvite>, ApiFailure>> listInvites(String boardId) {
    return apiCall(() async {
      final response = await _dio.get<dynamic>(MembersPaths.invites(boardId));
      return inviteListFromJson(response.data);
    });
  }

  @override
  Future<Result<CreatedInvite, ApiFailure>> createInvite(
    String boardId, {
    required BoardRole role,
    Duration? expiresIn,
    int? maxUses,
  }) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        MembersPaths.invites(boardId),
        data: createInviteBody(
          role: role,
          expiresIn: expiresIn,
          maxUses: maxUses,
        ),
      );
      return createdInviteFromJson(response.data);
    });
  }

  @override
  Future<Result<void, ApiFailure>> revokeInvite(
    String boardId,
    String inviteId,
  ) {
    return apiCall(() async {
      await _dio.delete<dynamic>(MembersPaths.invite(boardId, inviteId));
    });
  }
}
