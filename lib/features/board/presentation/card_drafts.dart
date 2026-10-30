import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/equality/collection_equality.dart';
import '../domain/board_sync_state.dart';
import '../domain/card_draft.dart';
import 'board_providers.dart';

enum LostDraftReason { archived, createRejected }

@immutable
class LostDraft {
  const LostDraft({
    required this.cardId,
    required this.text,
    required this.reason,
  });

  final String cardId;
  final String text;
  final LostDraftReason reason;

  @override
  bool operator ==(Object other) {
    return other is LostDraft &&
        other.cardId == cardId &&
        other.text == text &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(cardId, text, reason);
}

class LostDraftNotifier extends Notifier<List<LostDraft>> {
  @override
  List<LostDraft> build() => const <LostDraft>[];

  void report(LostDraft draft) => state = <LostDraft>[...state, draft];

  void remove(LostDraft draft) {
    final index = state.indexOf(draft);
    if (index >= 0) {
      state = <LostDraft>[...state]..removeAt(index);
    }
  }
}

final lostDraftProvider = NotifierProvider<LostDraftNotifier, List<LostDraft>>(
  LostDraftNotifier.new,
);

class CardDraftsNotifier extends Notifier<Map<String, CardDraft>> {
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
    final card = _board.liveView.activeCard(cardId);
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
    final card = board.liveView.activeCard(cardId);
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
    if (draft.flushRequested) {
      _set(draft.withFlushCleared());
    }
    final opId = ref
        .read(boardNotifierProvider.notifier)
        .editCardDescription(
          cardId: cardId,
          description: draft.text,
          baseDescriptionVersion: draft.baseDescriptionVersion,
        );
    final current = state[cardId] ?? draft;
    if (opId != null) {
      _put(current.submittedAs(opId));
    } else if (draft.flushRequested && state.containsKey(cardId)) {
      _set(current.withFlushRequested());
    }
  }

  void overwrite(String cardId) {
    final draft = state[cardId];
    final card = _board.confirmed.activeCard(cardId);
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

  void _set(CardDraft draft) {
    state = <String, CardDraft>{...state, draft.cardId: draft};
  }

  void _put(CardDraft draft) {
    _apply(<String, CardDraft>{...state, draft.cardId: draft}, _board);
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
    _apply(Map<String, CardDraft>.of(state), board);
  }

  void _apply(Map<String, CardDraft> candidate, BoardSyncState board) {
    final next = _reconcileAndReport(candidate, board);
    _autoSend(<String>[
      for (final entry in next.entries)
        if (entry.value.flushRequested &&
            entry.value.canSubmit &&
            !isDraftBlocked(entry.value, board))
          entry.key,
    ]);
  }

  Map<String, CardDraft> _reconcileAndReport(
    Map<String, CardDraft> candidate,
    BoardSyncState board,
  ) {
    final next = reconcileDrafts(candidate, board);
    if (!mapEquals(state, next)) {
      state = next;
    }
    for (final entry in candidate.entries) {
      if (!next.containsKey(entry.key)) {
        _reportIfLost(entry.value, board);
      }
    }
    return next;
  }

  void _autoSend(List<String> cardIds) {
    for (final cardId in cardIds) {
      save(cardId);
    }
  }

  void _reportIfLost(CardDraft draft, BoardSyncState board) {
    final gone = board.liveView.activeCard(draft.cardId) == null;
    if (!gone || draft.text.isEmpty) {
      return;
    }
    final known = board.confirmed.cardById(draft.cardId)?.description;
    if (known == draft.text) {
      return;
    }
    ref
        .read(lostDraftProvider.notifier)
        .report(
          LostDraft(
            cardId: draft.cardId,
            text: draft.text,
            reason: board.hasRejectedCreate(draft.cardId)
                ? LostDraftReason.createRejected
                : LostDraftReason.archived,
          ),
        );
  }
}

final cardDraftsProvider =
    NotifierProvider<CardDraftsNotifier, Map<String, CardDraft>>(
      CardDraftsNotifier.new,
    );

final cardDraftProvider = Provider.autoDispose.family<CardDraft?, String>(
  (ref, cardId) => ref.watch(cardDraftsProvider.select((all) => all[cardId])),
);
