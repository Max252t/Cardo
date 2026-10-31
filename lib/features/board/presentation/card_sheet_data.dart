import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/avatar_identity.dart';
import '../domain/board_sync_state.dart';
import '../domain/card_draft.dart';
import 'board_providers.dart';
import 'board_view_data.dart';
import 'card_drafts.dart';

@immutable
class CardConflictData {
  const CardConflictData({this.actorName, this.resolvable = true});

  final String? actorName;
  final bool resolvable;

  @override
  bool operator ==(Object other) =>
      other is CardConflictData &&
      other.actorName == actorName &&
      other.resolvable == resolvable;

  @override
  int get hashCode => Object.hash(actorName, resolvable);
}

@immutable
class CardNackData {
  const CardNackData({required this.rejection, this.actorName});

  final OpRejection rejection;
  final String? actorName;

  @override
  bool operator ==(Object other) {
    return other is CardNackData &&
        other.rejection == rejection &&
        other.actorName == actorName;
  }

  @override
  int get hashCode => Object.hash(rejection, actorName);
}

@immutable
class CardHeaderData {
  const CardHeaderData({
    required this.cardId,
    required this.title,
    required this.version,
    required this.createdAt,
    required this.editable,
    this.createdBy,
    this.conflict,
  });

  final String cardId;
  final String title;
  final int version;
  final DateTime createdAt;
  final bool editable;
  final AvatarIdentity? createdBy;
  final CardConflictData? conflict;

  @override
  bool operator ==(Object other) {
    return other is CardHeaderData &&
        other.cardId == cardId &&
        other.title == title &&
        other.version == version &&
        other.createdAt == createdAt &&
        other.editable == editable &&
        other.createdBy == createdBy &&
        other.conflict == conflict;
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    title,
    version,
    createdAt,
    editable,
    createdBy,
    conflict,
  );
}

@immutable
class CardChromeData {
  CardChromeData({
    required this.cardId,
    required this.title,
    required this.canEdit,
    required this.locked,
    required this.canSave,
    required List<ColumnInfo> moveTargets,
    this.column,
  }) : moveTargets = List<ColumnInfo>.unmodifiable(moveTargets);

  final String cardId;
  final String title;
  final bool canEdit;
  final bool locked;
  final bool canSave;
  final List<ColumnInfo> moveTargets;
  final ColumnInfo? column;

  @override
  bool operator ==(Object other) {
    return other is CardChromeData &&
        other.cardId == cardId &&
        other.title == title &&
        other.canEdit == canEdit &&
        other.locked == locked &&
        other.canSave == canSave &&
        listEquals(other.moveTargets, moveTargets) &&
        other.column == column;
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    title,
    canEdit,
    locked,
    canSave,
    Object.hashAll(moveTargets),
    column,
  );
}

@immutable
class CardSheetData {
  CardSheetData({
    required this.cardId,
    required this.title,
    required this.version,
    required this.createdAt,
    required this.text,
    required this.canEdit,
    required this.locked,
    required this.tooLong,
    required this.hasDraft,
    List<ColumnInfo> moveTargets = const <ColumnInfo>[],
    this.column,
    this.createdBy,
    this.conflict,
  }) : moveTargets = List<ColumnInfo>.unmodifiable(moveTargets);

  final String cardId;
  final String title;
  final int version;
  final DateTime createdAt;
  final String text;
  final bool canEdit;
  final bool locked;
  final bool tooLong;
  final bool hasDraft;
  final List<ColumnInfo> moveTargets;
  final ColumnInfo? column;
  final AvatarIdentity? createdBy;
  final CardConflictData? conflict;

  bool get editable => canEdit && !locked;

  bool get canSave => editable && hasDraft && conflict == null && !tooLong;

  CardHeaderData get header => CardHeaderData(
    cardId: cardId,
    title: title,
    version: version,
    createdAt: createdAt,
    editable: editable,
    createdBy: createdBy,
    conflict: canEdit ? conflict : null,
  );

  CardChromeData get chrome => CardChromeData(
    cardId: cardId,
    title: title,
    canEdit: canEdit,
    locked: locked,
    canSave: canSave,
    moveTargets: moveTargets,
    column: column,
  );

  @override
  bool operator ==(Object other) {
    return other is CardSheetData &&
        other.cardId == cardId &&
        other.title == title &&
        other.version == version &&
        other.createdAt == createdAt &&
        other.text == text &&
        other.canEdit == canEdit &&
        other.locked == locked &&
        other.tooLong == tooLong &&
        other.hasDraft == hasDraft &&
        listEquals(other.moveTargets, moveTargets) &&
        other.column == column &&
        other.createdBy == createdBy &&
        other.conflict == conflict;
  }

  @override
  int get hashCode => Object.hash(
    cardId,
    title,
    version,
    createdAt,
    text,
    canEdit,
    locked,
    tooLong,
    hasDraft,
    Object.hashAll(moveTargets),
    column,
    createdBy,
    conflict,
  );
}

final cardSheetProvider = Provider.autoDispose.family<CardSheetData?, String>((
  ref,
  cardId,
) {
  final state = ref.watch(boardNotifierProvider);
  final view = state.view;
  final card = view.cardById(cardId);
  if (card == null || card.archived) {
    return null;
  }
  final live = state.liveView.cardById(cardId) ?? card;
  final canEdit = ref.watch(canEditBoardProvider);
  final draft = canEdit ? ref.watch(cardDraftProvider(cardId)) : null;
  final column = view.columnById(card.columnId);
  final creator = view.memberById(card.createdBy);
  final conflictActor = draft?.conflictActorId;
  return CardSheetData(
    cardId: cardId,
    title: card.title,
    version: card.version,
    createdAt: card.createdAt,
    text: draft?.text ?? live.description,
    canEdit: canEdit,
    locked: state.hasBlockingRejection(cardId),
    tooLong: draft?.tooLong ?? false,
    hasDraft: draft != null && !draft.submitted,
    moveTargets: <ColumnInfo>[
      for (final other in view.orderedColumns)
        if (other.id != card.columnId) ColumnInfo.of(other),
    ],
    column: column == null ? null : ColumnInfo.of(column),
    createdBy: creator == null ? null : identityOf(creator),
    conflict: draft != null && draft.conflict
        ? CardConflictData(
            actorName: conflictActor == null
                ? null
                : view.memberById(conflictActor)?.name,
            resolvable: isConflictResolvable(draft, state),
          )
        : null,
  );
});

final cardNackProvider = Provider.autoDispose.family<CardNackData?, String>((
  ref,
  cardId,
) {
  final state = ref.watch(boardNotifierProvider);
  final rejection = state.blockingRejection(cardId);
  if (rejection == null) {
    return null;
  }
  final actorId = rejection.actorId;
  return CardNackData(
    rejection: rejection,
    actorName: actorId == null ? null : state.view.memberById(actorId)?.name,
  );
});
