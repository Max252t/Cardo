import '../../../core/models/board_role.dart';
import '../../../core/network/json_fields.dart';
import '../domain/board_invite.dart';
import '../domain/roster_member.dart';

BoardRole _readRole(Map<String, dynamic> json, String key) {
  final role = BoardRole.tryParse(readString(json, key));
  if (role == null) {
    throw FormatException('Unknown role in "$key"');
  }
  return role;
}

RosterMember rosterMemberFromJson(Object? raw) {
  final json = asJsonMap(raw, 'member');
  return RosterMember(
    userId: readNonEmptyString(json, 'user_id'),
    name: readString(json, 'display_name'),
    avatarColor: readString(json, 'avatar_color'),
    role: _readRole(json, 'role'),
    joinedAt: readDate(json, 'joined_at'),
  );
}

List<RosterMember> rosterFromJson(Object? raw) {
  final json = asJsonMap(raw, 'member list');
  return <RosterMember>[
    for (final item in readObjectList(json, 'members'))
      rosterMemberFromJson(item),
  ];
}

BoardInvite inviteFromJson(Object? raw) {
  final json = asJsonMap(raw, 'invite');
  return BoardInvite(
    id: readNonEmptyString(json, 'id'),
    role: _readRole(json, 'role'),
    expiresAt: readDate(json, 'expires_at'),
    maxUses: readInt(json, 'max_uses'),
    uses: readInt(json, 'uses'),
  );
}

List<BoardInvite> inviteListFromJson(Object? raw) {
  final json = asJsonMap(raw, 'invite list');
  return <BoardInvite>[
    for (final item in readObjectList(json, 'invites')) inviteFromJson(item),
  ];
}

CreatedInvite createdInviteFromJson(Object? raw) {
  final json = asJsonMap(raw, 'created invite');
  return CreatedInvite(
    invite: inviteFromJson(json),
    token: readNonEmptyString(json, 'token'),
  );
}

Map<String, Object> addMemberBody({
  required String email,
  required BoardRole role,
}) => <String, Object>{'email': email, 'role': role.wireName};

Map<String, Object> changeRoleBody(BoardRole role) => <String, Object>{
  'role': role.wireName,
};

Map<String, Object> createInviteBody({
  required BoardRole role,
  Duration? expiresIn,
  int? maxUses,
}) => <String, Object>{
  'role': role.wireName,
  'expires_in': ?expiresIn?.inSeconds,
  'max_uses': ?maxUses,
};
