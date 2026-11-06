import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/equality/collection_equality.dart';
import '../../../core/models/board_role.dart';
import '../../../shared/widgets/avatar_identity.dart';
import '../../board/presentation/board_providers.dart';

@immutable
class MemberRowView {
  const MemberRowView({
    required this.userId,
    required this.identity,
    required this.role,
    required this.isSelf,
    required this.online,
    required this.canManage,
    this.email,
  });

  final String userId;
  final AvatarIdentity identity;
  final BoardRole role;
  final bool isSelf;
  final bool online;
  final bool canManage;
  final String? email;

  @override
  bool operator ==(Object other) {
    return other is MemberRowView &&
        other.userId == userId &&
        other.identity == identity &&
        other.role == role &&
        other.isSelf == isSelf &&
        other.online == online &&
        other.canManage == canManage &&
        other.email == email;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identity, role, isSelf, online, canManage, email);
}

@immutable
class MembersView {
  MembersView({
    required this.boardId,
    required this.boardTitle,
    required this.isOwner,
    required List<MemberRowView> rows,
  }) : rows = List<MemberRowView>.unmodifiable(rows);

  final String boardId;
  final String boardTitle;
  final bool isOwner;
  final List<MemberRowView> rows;

  int get total => rows.length;

  int get onlineCount => rows.where((row) => row.online).length;

  @override
  bool operator ==(Object other) {
    return other is MembersView &&
        other.boardId == boardId &&
        other.boardTitle == boardTitle &&
        other.isOwner == isOwner &&
        listEquals(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(boardId, boardTitle, isOwner, hashList(rows));
}

final membersViewProvider = Provider<MembersView>(
  (ref) {
    final board = ref.watch(boardViewProvider);
    final user = ref.watch(currentUserProvider);
    final presence = ref.watch(boardPresenceProvider);
    final isOwner = board.memberById(user.userId)?.role == BoardRole.owner;
    final ordered = <MemberRowView>[
      for (final member in board.members)
        MemberRowView(
          userId: member.userId,
          identity: AvatarIdentity(
            name: member.name,
            colorHex: member.avatarColor,
          ),
          role: member.role,
          isSelf: member.userId == user.userId,
          online:
              member.userId == user.userId ||
              presence.onlineUserIds.contains(member.userId),
          canManage:
              isOwner &&
              member.userId != user.userId &&
              member.role != BoardRole.owner,
          email: member.userId == user.userId ? user.email : null,
        ),
    ];
    final rows = <MemberRowView>[
      ...ordered.where((row) => row.role == BoardRole.owner),
      ...ordered.where((row) => row.role != BoardRole.owner),
    ];
    return MembersView(
      boardId: board.id,
      boardTitle: board.title,
      isOwner: isOwner,
      rows: rows,
    );
  },
  dependencies: [boardViewProvider, currentUserProvider, boardPresenceProvider],
);
