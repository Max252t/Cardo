import 'board_model.dart';
import 'board_op.dart';
import 'board_sync_state.dart';

const Object _keep = Object();

class CardDraft {
  const CardDraft({
    required this.cardId,
    required this.text,
    required this.baseDescriptionVersion,
    this.submittedOpId,
    this.conflict = false,
    this.conflictActorId,
    this.conflictAtSeq,
    this.flushRequested = false,
  });

  final String cardId;
  final String text;
  final int baseDescriptionVersion;
  final String? submittedOpId;
  final bool conflict;
  final String? conflictActorId;
  final int? conflictAtSeq;
  final bool flushRequested;

  bool get submitted => submittedOpId != null;

  bool get tooLong => text.length > CardLimits.descriptionMaxLength;

  bool get canSubmit => !tooLong && !conflict && !submitted;

  CardDraft _with({
    String? text,
    int? base,
    Object? submittedOpId = _keep,
    bool? conflict,
    Object? conflictActorId = _keep,
    Object? conflictAtSeq = _keep,
    bool? flushRequested,
  }) {
    return CardDraft(
      cardId: cardId,
      text: text ?? this.text,
      baseDescriptionVersion: base ?? baseDescriptionVersion,
      submittedOpId: identical(submittedOpId, _keep)
          ? this.submittedOpId
          : submittedOpId as String?,
      conflict: conflict ?? this.conflict,
      conflictActorId: identical(conflictActorId, _keep)
          ? this.conflictActorId
          : conflictActorId as String?,
      conflictAtSeq: identical(conflictAtSeq, _keep)
          ? this.conflictAtSeq
          : conflictAtSeq as int?,
      flushRequested: flushRequested ?? this.flushRequested,
    );
  }

  CardDraft withText(String value) => _with(text: value, flushRequested: false);

  CardDraft submittedAs(String opId) => _with(
    submittedOpId: opId,
    conflict: false,
    conflictActorId: null,
    conflictAtSeq: null,
    flushRequested: false,
  );

  CardDraft unsubmitted() => _with(submittedOpId: null);

  CardDraft conflictedBy(String? actorId, {int? atSeq}) => _with(
    submittedOpId: null,
    conflict: true,
    conflictActorId: actorId,
    conflictAtSeq: atSeq,
  );

  CardDraft rebased(int descriptionVersion) => _with(
    base: descriptionVersion,
    submittedOpId: null,
    conflict: false,
    conflictActorId: null,
    conflictAtSeq: null,
  );

  CardDraft withFlushRequested() => _with(flushRequested: true);

  @override
  bool operator ==(Object other) {
    return other is CardDraft &&
        other.cardId == cardId &&
        other.text == text &&
        other.baseDescriptionVersion == baseDescriptionVersion &&
        other.submittedOpId == submittedOpId &&
        other.conflict == conflict &&
        other.conflictActorId == conflictActorId &&
        other.conflictAtSeq == conflictAtSeq &&
        other.flushRequested == flushRequested;
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    text,
    baseDescriptionVersion,
    submittedOpId,
    conflict,
    conflictActorId,
    conflictAtSeq,
    flushRequested,
  );

  @override
  String toString() =>
      'CardDraft($cardId, base d$baseDescriptionVersion, '
      'conflict $conflict)';
}

bool isConflictResolvable(CardDraft draft, BoardSyncState state) {
  if (!draft.conflict) {
    return true;
  }
  final atSeq = draft.conflictAtSeq;
  if (atSeq == null || state.lastSeq >= atSeq) {
    return true;
  }
  final card = state.confirmed.cardById(draft.cardId);
  return card != null && card.descriptionVersion > draft.baseDescriptionVersion;
}

bool isDraftBlocked(CardDraft draft, BoardSyncState state) {
  return state.confirmed.cardById(draft.cardId) == null ||
      state.hasBlockingRejection(draft.cardId);
}

CardDraft? reconcileDraft(CardDraft draft, BoardSyncState state) {
  final live = state.liveView.cardById(draft.cardId);
  if (live == null || live.archived) {
    return null;
  }
  final card = state.confirmed.cardById(draft.cardId);
  if (card == null) {
    return draft;
  }
  final opId = draft.submittedOpId;
  if (opId != null) {
    return _reconcileSubmitted(draft, state, card, opId);
  }
  if (card.descriptionVersion <= draft.baseDescriptionVersion) {
    return draft;
  }
  if (card.description == draft.text) {
    return null;
  }
  return draft.conflict ? draft : draft.conflictedBy(card.updatedBy);
}

CardDraft? _reconcileSubmitted(
  CardDraft draft,
  BoardSyncState state,
  CardModel card,
  String opId,
) {
  final item = state.pending.where((other) => other.opId == opId).firstOrNull;
  if (item == null) {
    return card.description == draft.text
        ? null
        : reconcileDraft(
            draft.rebased(draft.baseDescriptionVersion + 1),
            state,
          );
  }
  if (!item.isRejected) {
    return draft;
  }
  if (item.isDescriptionConflict) {
    return draft.conflictedBy(
      item.rejection?.actorId,
      atSeq: item.rejection?.atSeq,
    );
  }
  return draft.unsubmitted();
}

Map<String, CardDraft> reconcileDrafts(
  Map<String, CardDraft> drafts,
  BoardSyncState state,
) {
  return <String, CardDraft>{
    for (final entry in drafts.entries)
      entry.key: ?reconcileDraft(entry.value, state),
  };
}

EditCardDescription? descriptionOpFor(
  CardDraft draft, {
  required String opId,
  required String actorId,
  required DateTime at,
}) {
  if (!draft.canSubmit) {
    return null;
  }
  return EditCardDescription(
    opId: opId,
    cardId: draft.cardId,
    description: draft.text,
    baseDescriptionVersion: draft.baseDescriptionVersion,
    actorId: actorId,
    at: at,
  );
}
