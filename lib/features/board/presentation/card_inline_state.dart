import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_model.dart';
import 'board_providers.dart';

typedef ComposerDraft = ({
  String title,
  String description,
  bool descriptionOpen,
});

@immutable
class CardInlineState {
  const CardInlineState({
    this.composerColumnId,
    this.composerTitle = '',
    this.composerDescription = '',
    this.composerDescriptionOpen = false,
    this.editingCardId,
    this.editingTitle = '',
    this.composerDrafts = const <String, ComposerDraft>{},
  });

  final String? composerColumnId;
  final String composerTitle;
  final String composerDescription;
  final bool composerDescriptionOpen;
  final String? editingCardId;
  final String editingTitle;
  final Map<String, ComposerDraft> composerDrafts;

  bool get composerHasText =>
      composerTitle.isNotEmpty || composerDescription.isNotEmpty;

  CardInlineState withoutComposer() {
    return CardInlineState(
      editingCardId: editingCardId,
      editingTitle: editingTitle,
      composerDrafts: composerDrafts,
    );
  }

  CardInlineState withoutEditing() {
    return CardInlineState(
      composerColumnId: composerColumnId,
      composerTitle: composerTitle,
      composerDescription: composerDescription,
      composerDescriptionOpen: composerDescriptionOpen,
      composerDrafts: composerDrafts,
    );
  }

  CardInlineState withComposer({
    String? title,
    String? description,
    bool? descriptionOpen,
  }) {
    return CardInlineState(
      composerColumnId: composerColumnId,
      composerTitle: title ?? composerTitle,
      composerDescription: description ?? composerDescription,
      composerDescriptionOpen: descriptionOpen ?? composerDescriptionOpen,
      editingCardId: editingCardId,
      editingTitle: editingTitle,
      composerDrafts: composerDrafts,
    );
  }

  CardInlineState withEditing(String? cardId, String title) {
    return CardInlineState(
      composerColumnId: composerColumnId,
      composerTitle: composerTitle,
      composerDescription: composerDescription,
      composerDescriptionOpen: composerDescriptionOpen,
      editingCardId: cardId,
      editingTitle: title,
      composerDrafts: composerDrafts,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CardInlineState &&
        other.composerColumnId == composerColumnId &&
        other.composerTitle == composerTitle &&
        other.composerDescription == composerDescription &&
        other.composerDescriptionOpen == composerDescriptionOpen &&
        other.editingCardId == editingCardId &&
        other.editingTitle == editingTitle &&
        mapEquals(other.composerDrafts, composerDrafts);
  }

  @override
  int get hashCode => Object.hash(
    composerColumnId,
    composerTitle,
    composerDescription,
    composerDescriptionOpen,
    editingCardId,
    editingTitle,
    Object.hashAllUnordered(<int>[
      for (final entry in composerDrafts.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );
}

class CardInlineNotifier extends Notifier<CardInlineState> {
  @override
  CardInlineState build() => const CardInlineState();

  void openComposer(String columnId) {
    final current = state.composerColumnId;
    if (current == columnId) {
      return;
    }
    final drafts = <String, ComposerDraft>{...state.composerDrafts};
    if (current != null && state.composerHasText) {
      drafts[current] = (
        title: state.composerTitle,
        description: state.composerDescription,
        descriptionOpen: state.composerDescriptionOpen,
      );
    }
    final restored = drafts.remove(columnId);
    state = CardInlineState(
      composerColumnId: columnId,
      composerTitle: restored?.title ?? '',
      composerDescription: restored?.description ?? '',
      composerDescriptionOpen: restored?.descriptionOpen ?? false,
      editingCardId: state.editingCardId,
      editingTitle: state.editingTitle,
      composerDrafts: drafts,
    );
  }

  void setComposer({String? title, String? description}) {
    if (state.composerColumnId == null) {
      return;
    }
    state = state.withComposer(title: title, description: description);
  }

  void toggleComposerDescription() {
    if (state.composerColumnId == null) {
      return;
    }
    state = state.withComposer(descriptionOpen: !state.composerDescriptionOpen);
  }

  void closeComposer() {
    state = state.withoutComposer();
  }

  void clearComposerText() {
    if (state.composerColumnId == null) {
      return;
    }
    state = CardInlineState(
      composerColumnId: state.composerColumnId,
      composerDescriptionOpen: state.composerDescriptionOpen,
      editingCardId: state.editingCardId,
      editingTitle: state.editingTitle,
      composerDrafts: state.composerDrafts,
    );
  }

  void startEditing(String cardId, String title) {
    if (state.editingCardId == cardId) {
      return;
    }
    state = state.withEditing(cardId, title);
  }

  void setEditingTitle(String title) {
    final id = state.editingCardId;
    if (id == null) {
      return;
    }
    state = state.withEditing(id, title);
  }

  void stopEditing() {
    state = state.withoutEditing();
  }
}

final cardInlineProvider =
    NotifierProvider<CardInlineNotifier, CardInlineState>(
      CardInlineNotifier.new,
      dependencies: [boardGatewayProvider],
    );

bool isValidCardTitle(String raw) {
  final trimmed = raw.trim();
  return trimmed.isNotEmpty &&
      trimmed.runes.length <= CardLimits.titleMaxLength;
}
