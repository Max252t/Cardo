import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/equality/collection_equality.dart';
import '../domain/board_model.dart';
import '../domain/board_sync_state.dart';
import '../domain/card_draft.dart';
import 'board_providers.dart';

@immutable
class LostDraft {
  const LostDraft({required this.cardId, required this.text});

  final String cardId;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is LostDraft && other.cardId == cardId && other.text == text;
  }

  @override
  int get hashCode => Object.hash(cardId, text);
}

class LostDraftNotifier extends Notifier<LostDraft?> {
  @override
  LostDraft? build() => null;

  void report(LostDraft draft) => state = draft;

  void clear() => state = null;
}

final lostDraftProvider = NotifierProvider<LostDraftNotifier, LostDraft?>(
  LostDraftNotifier.new,
);

class CardDraftsNotifier extends Notifier<Map<String, CardDraft>> {
  bool _saving = false;

  @override
  Map<String, CardDraft> build() {
    ref.listen<BoardSyncState>(
      boardNotifierProvider,
      (previous, next) => _reconcile(next),
    );
    return const <String, CardDraft>{};
  }

  BoardSyncState get _board => ref.read(boardNotifierProvider);

  void edit(String cardId, String text) {
    final card = _editableCard(_board.liveView, cardId);
    if (card == null || !ref.read(canEditBoardProvider)) {
      return;
    }
    final existing = state[cardId];
    final pristine =
        text == card.description &&
        (existing == null || (!existing.conflict && !existing.submitted));
    if (pristine) {
      _remove(cardId);
      return;
    }
    _put(
      existing?.withText(text) ??
          CardDraft(
            cardId: cardId,
            text: text,
            baseDescriptionVersion: card.descriptionVersion,
          ),
    );
  }

  void save(String cardId) {
    final draft = state[cardId];
    final board = _board;
    final card = _editableCard(board.liveView, cardId);
    if (draft == null ||
        !draft.canSubmit ||
        card == null ||
        isDraftBlocked(draft, board) ||
        !ref.read(canEditBoardProvider)) {
      return;
    }
    if (draft.text == card.description) {
      _remove(cardId);
      return;
    }
    _saving = true;
    final String? opId;
    try {
      opId = ref
          .read(boardNotifierProvider.notifier)
          .editCardDescription(
            cardId: cardId,
            description: draft.text,
            baseDescriptionVersion: draft.baseDescriptionVersion,
          );
    } finally {
      _saving = false;
    }
    if (opId != null) {
      _put((state[cardId] ?? draft).submittedAs(opId));
    }
  }

  void overwrite(String cardId) {
    final draft = state[cardId];
    final card = _editableCard(_board.confirmed, cardId);
    if (draft == null ||
        !draft.conflict ||
        card == null ||
        !isConflictResolvable(draft, _board)) {
      return;
    }
    _put(draft.rebased(card.descriptionVersion));
    save(cardId);
  }

  void discard(String cardId) {
    final draft = state[cardId];
    if (draft == null || !isConflictResolvable(draft, _board)) {
      return;
    }
    _remove(cardId);
  }

  void flush(String cardId) {
    final draft = state[cardId];
    if (draft == null || draft.conflict) {
      return;
    }
    if (!draft.flushRequested) {
      _put(draft.withFlushRequested());
    }
    save(cardId);
  }

  void _put(CardDraft draft) {
    _commit(<String, CardDraft>{...state, draft.cardId: draft}, _board);
  }

  void _remove(String cardId) {
    if (state.containsKey(cardId)) {
      state = Map<String, CardDraft>.of(state)..remove(cardId);
    }
  }

  void _reconcile(BoardSyncState board) {
    if (state.isEmpty) {
      return;
    }
    _commit(Map<String, CardDraft>.of(state), board);
  }

  void _commit(Map<String, CardDraft> candidate, BoardSyncState board) {
    final next = reconcileDrafts(candidate, board);
    final previous = state;
    if (!mapEquals(previous, next)) {
      state = next;
    }
    for (final entry in candidate.entries) {
      if (!next.containsKey(entry.key)) {
        _reportIfLost(entry.value, board);
      }
    }
    if (_saving) {
      return;
    }
    for (final entry in next.entries) {
      final draft = entry.value;
      if (draft.flushRequested &&
          draft.canSubmit &&
          !isDraftBlocked(draft, board)) {
        save(entry.key);
      }
    }
  }

  void _reportIfLost(CardDraft draft, BoardSyncState board) {
    final live = board.liveView.cardById(draft.cardId);
    final gone = live == null || live.archived;
    if (!gone || draft.text.isEmpty) {
      return;
    }
    final known = board.confirmed.cardById(draft.cardId)?.description;
    if (known == draft.text) {
      return;
    }
    ref
        .read(lostDraftProvider.notifier)
        .report(LostDraft(cardId: draft.cardId, text: draft.text));
  }
}

final cardDraftsProvider =
    NotifierProvider<CardDraftsNotifier, Map<String, CardDraft>>(
      CardDraftsNotifier.new,
    );

final cardDraftProvider = Provider.autoDispose.family<CardDraft?, String>(
  (ref, cardId) => ref.watch(cardDraftsProvider.select((all) => all[cardId])),
);

CardModel? _editableCard(BoardModel board, String cardId) {
  final card = board.cardById(cardId);
  return card == null || card.archived ? null : card;
}
