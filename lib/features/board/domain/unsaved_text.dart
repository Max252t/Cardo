import 'board_op.dart';
import 'board_sync_state.dart';
import 'card_draft.dart';

class UnsavedText {
  const UnsavedText({
    required this.cardId,
    required this.cardTitle,
    required this.text,
  });

  final String cardId;
  final String? cardTitle;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is UnsavedText &&
        other.cardId == cardId &&
        other.cardTitle == cardTitle &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(cardId, cardTitle, text);

  @override
  String toString() => 'UnsavedText($cardId)';
}

List<UnsavedText> unsavedDescriptions(
  Iterable<CardDraft> drafts,
  BoardSyncState state,
) {
  final seen = <String>{};
  final found = <UnsavedText>[];
  String? titleOf(String cardId) =>
      state.confirmed.cardById(cardId)?.title ??
      state.view.cardById(cardId)?.title;
  for (final draft in drafts) {
    final known = state.confirmed.cardById(draft.cardId)?.description;
    if (draft.text.isEmpty || draft.text == known) {
      continue;
    }
    if (seen.add(draft.cardId)) {
      found.add(
        UnsavedText(
          cardId: draft.cardId,
          cardTitle: titleOf(draft.cardId),
          text: draft.text,
        ),
      );
    }
  }
  for (final item in state.pending) {
    final op = item.op;
    if (op is! EditCardDescription || op.description.isEmpty) {
      continue;
    }
    if (seen.add(op.cardId)) {
      found.add(
        UnsavedText(
          cardId: op.cardId,
          cardTitle: titleOf(op.cardId),
          text: op.description,
        ),
      );
    }
  }
  return found;
}
