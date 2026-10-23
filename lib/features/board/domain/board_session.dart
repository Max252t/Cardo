import '../../../core/equality/collection_equality.dart';
import '../../../core/realtime/connection_status.dart';
import 'board_model.dart';
import 'board_sync_state.dart';

class CurrentUser {
  const CurrentUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarColor,
  });

  final String userId;
  final String name;
  final String email;
  final String avatarColor;

  @override
  bool operator ==(Object other) {
    return other is CurrentUser &&
        other.userId == userId &&
        other.name == name &&
        other.email == email &&
        other.avatarColor == avatarColor;
  }

  @override
  int get hashCode => Object.hash(userId, name, email, avatarColor);
}

class BoardSummary {
  const BoardSummary({
    required this.id,
    required this.title,
    required this.colorHex,
  });

  final String id;
  final String title;
  final String colorHex;

  @override
  bool operator ==(Object other) {
    return other is BoardSummary &&
        other.id == id &&
        other.title == title &&
        other.colorHex == colorHex;
  }

  @override
  int get hashCode => Object.hash(id, title, colorHex);
}

class BoardPresence {
  BoardPresence({
    required List<String> onlineUserIds,
    Map<String, String> editingByCard = const <String, String>{},
  }) : onlineUserIds = List<String>.unmodifiable(onlineUserIds),
       editingByCard = Map<String, String>.unmodifiable(editingByCard);

  final List<String> onlineUserIds;
  final Map<String, String> editingByCard;

  @override
  bool operator ==(Object other) {
    return other is BoardPresence &&
        listEquals(other.onlineUserIds, onlineUserIds) &&
        mapEquals(other.editingByCard, editingByCard);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(onlineUserIds),
    Object.hashAllUnordered(
      editingByCard.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

class BoardSnapshot {
  BoardSnapshot({
    required this.board,
    required this.currentUser,
    required List<BoardSummary> boards,
    required this.presence,
    this.connection = ConnectionStatus.connected,
  }) : boards = List<BoardSummary>.unmodifiable(boards);

  final BoardModel board;
  final CurrentUser currentUser;
  final List<BoardSummary> boards;
  final BoardPresence presence;
  final ConnectionStatus connection;

  @override
  bool operator ==(Object other) {
    return other is BoardSnapshot &&
        other.board == board &&
        other.currentUser == currentUser &&
        listEquals(other.boards, boards) &&
        other.presence == presence &&
        other.connection == connection;
  }

  @override
  int get hashCode => Object.hash(
    board,
    currentUser,
    Object.hashAll(boards),
    presence,
    connection,
  );
}

class RemoteCardUpdate {
  const RemoteCardUpdate({
    required this.card,
    required this.seq,
    required this.actorId,
  });

  final CardModel card;
  final int seq;
  final String actorId;

  @override
  bool operator ==(Object other) {
    return other is RemoteCardUpdate &&
        other.card == card &&
        other.seq == seq &&
        other.actorId == actorId;
  }

  @override
  int get hashCode => Object.hash(card, seq, actorId);
}

sealed class OpOutcome {
  const OpOutcome();
}

final class OpConfirmed extends OpOutcome {
  const OpConfirmed({required this.seq});

  final int seq;

  @override
  bool operator ==(Object other) => other is OpConfirmed && other.seq == seq;

  @override
  int get hashCode => seq.hashCode;
}

final class OpRejected extends OpOutcome {
  const OpRejected(this.rejection);

  final OpRejection rejection;

  @override
  bool operator ==(Object other) =>
      other is OpRejected && other.rejection == rejection;

  @override
  int get hashCode => rejection.hashCode;
}
