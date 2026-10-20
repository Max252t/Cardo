import 'package:flutter/foundation.dart';

import '../../../shared/widgets/avatar_identity.dart';
import '../domain/board_model.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';

@immutable
class CardViewData {
  const CardViewData({
    required this.card,
    required this.status,
    this.rejection,
    this.rejectionActorName,
    this.createdBy,
    this.updatedBy,
    this.editingBy,
  });

  final CardModel card;
  final CardSyncStatus status;
  final OpRejection? rejection;
  final String? rejectionActorName;
  final AvatarIdentity? createdBy;
  final AvatarIdentity? updatedBy;
  final AvatarIdentity? editingBy;

  @override
  bool operator ==(Object other) {
    return other is CardViewData &&
        other.card == card &&
        other.status == status &&
        other.rejection == rejection &&
        other.rejectionActorName == rejectionActorName &&
        other.createdBy == createdBy &&
        other.updatedBy == updatedBy &&
        other.editingBy == editingBy;
  }

  @override
  int get hashCode => Object.hash(
    card,
    status,
    rejection,
    rejectionActorName,
    createdBy,
    updatedBy,
    editingBy,
  );
}

@immutable
class ColumnViewData {
  ColumnViewData({required this.column, required List<CardViewData> cards})
    : cards = List<CardViewData>.unmodifiable(cards);

  final ColumnModel column;
  final List<CardViewData> cards;

  int get count => cards.length;

  List<CardModel> get models =>
      cards.map((item) => item.card).toList(growable: false);

  @override
  bool operator ==(Object other) {
    return other is ColumnViewData &&
        other.column == column &&
        listEquals(other.cards, cards);
  }

  @override
  int get hashCode => Object.hash(column, Object.hashAll(cards));
}

AvatarIdentity identityOf(BoardMember member) {
  return AvatarIdentity(name: member.name, colorHex: member.avatarColor);
}

AvatarIdentity? _identityFor(BoardModel board, String? userId) {
  if (userId == null) {
    return null;
  }
  final member = board.memberById(userId);
  return member == null ? null : identityOf(member);
}

String? _nameOf(BoardModel board, String? userId) {
  return userId == null ? null : board.memberById(userId)?.name;
}

CardViewData _cardViewData({
  required BoardSyncState state,
  required BoardModel board,
  required CardModel card,
  required String? editorId,
}) {
  final rejection = state.cardRejection(card.id);
  return CardViewData(
    card: card,
    status: state.cardStatus(card.id),
    rejection: rejection,
    rejectionActorName: _nameOf(board, rejection?.actorId),
    createdBy: _identityFor(board, card.createdBy),
    updatedBy: _identityFor(board, card.updatedBy),
    editingBy: _identityFor(board, editorId),
  );
}

List<ColumnViewData> buildColumnViewData({
  required BoardSyncState state,
  required BoardPresence presence,
  required String currentUserId,
}) {
  final board = state.view;
  return <ColumnViewData>[
    for (final column in board.orderedColumns)
      ColumnViewData(
        column: column,
        cards: <CardViewData>[
          for (final card in board.cardsIn(column.id))
            _cardViewData(
              state: state,
              board: board,
              card: card,
              editorId: switch (presence.editingByCard[card.id]) {
                final id? when id != currentUserId => id,
                _ => null,
              },
            ),
        ],
      ),
  ];
}
