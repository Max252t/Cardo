import '../../../core/models/board_role.dart';

class RosterMember {
  const RosterMember({
    required this.userId,
    required this.name,
    required this.avatarColor,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String name;
  final String avatarColor;
  final BoardRole role;
  final DateTime joinedAt;

  @override
  bool operator ==(Object other) {
    return other is RosterMember &&
        other.userId == userId &&
        other.name == name &&
        other.avatarColor == avatarColor &&
        other.role == role &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode => Object.hash(userId, name, avatarColor, role, joinedAt);
}
