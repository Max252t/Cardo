import '../../../core/models/board_role.dart';
import '../../board/domain/board_model.dart';

class BoardInfo {
  const BoardInfo({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.seq,
  });

  final String id;
  final String title;
  final String ownerId;
  final BoardRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? seq;

  @override
  bool operator ==(Object other) {
    return other is BoardInfo &&
        other.id == id &&
        other.title == title &&
        other.ownerId == ownerId &&
        other.role == role &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.seq == seq;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, ownerId, role, createdAt, updatedAt, seq);

  @override
  String toString() => 'BoardInfo($id, $title, ${role.wireName})';
}

class ServerBoard {
  const ServerBoard({required this.info, required this.model});

  final BoardInfo info;
  final BoardModel model;
}

enum BoardTitleIssue { empty, tooLong }

abstract final class BoardLimits {
  static const int titleMax = 200;

  static BoardTitleIssue? validateTitle(String value) {
    final length = value.trim().runes.length;
    if (length == 0) {
      return BoardTitleIssue.empty;
    }
    return length > titleMax ? BoardTitleIssue.tooLong : null;
  }
}
