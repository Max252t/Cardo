import '../../../core/models/board_role.dart';

class BoardInvite {
  const BoardInvite({
    required this.id,
    required this.role,
    required this.expiresAt,
    required this.maxUses,
    required this.uses,
  });

  final String id;
  final BoardRole role;
  final DateTime expiresAt;
  final int maxUses;
  final int uses;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  @override
  bool operator ==(Object other) {
    return other is BoardInvite &&
        other.id == id &&
        other.role == role &&
        other.expiresAt == expiresAt &&
        other.maxUses == maxUses &&
        other.uses == uses;
  }

  @override
  int get hashCode => Object.hash(id, role, expiresAt, maxUses, uses);
}

class CreatedInvite {
  const CreatedInvite({required this.invite, required this.token});

  final BoardInvite invite;
  final String token;

  @override
  String toString() => 'CreatedInvite(${invite.id})';
}
