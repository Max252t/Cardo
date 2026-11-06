import '../../../boards/domain/board_info.dart';
import '../../domain/board_model.dart';
import '../../domain/board_session.dart';

BoardModel boardModelFor(ServerBoard board, CurrentUser currentUser) {
  final role = board.info.role;
  final members = <BoardMember>[
    for (final member in board.model.members)
      member.userId == currentUser.userId
          ? member.copyWith(role: role)
          : member,
  ];
  if (!members.any((member) => member.userId == currentUser.userId)) {
    members.add(
      BoardMember(
        userId: currentUser.userId,
        name: currentUser.name,
        avatarColor: currentUser.avatarColor,
        role: role,
      ),
    );
  }
  return board.model.copyWith(members: members);
}
