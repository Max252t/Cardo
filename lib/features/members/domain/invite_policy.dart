import '../../../core/models/board_role.dart';

abstract final class InvitePolicy {
  static const List<BoardRole> assignableRoles = <BoardRole>[
    BoardRole.editor,
    BoardRole.viewer,
  ];

  static const BoardRole defaultRole = BoardRole.editor;
  static const Duration defaultLifetime = Duration(days: 7);
  static const int defaultMaxUses = 5;
}
