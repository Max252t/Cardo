import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_model.dart';
import 'board_providers.dart';

@immutable
class CardInlineState {
  const CardInlineState({
    this.composerColumnId,
    this.composerTitle = '',
    this.composerDescription = '',
    this.composerDescriptionOpen = false,
    this.editingCardId,
    this.editingTitle = '',
  });

  final String? composerColumnId;
  final String composerTitle;
  final String composerDescription;
  final bool composerDescriptionOpen;
  final String? editingCardId;
  final String editingTitle;

  CardInlineState withoutComposer() {
    return CardInlineState(
      editingCardId: editingCardId,
      editingTitle: editingTitle,
    );
  }

  CardInlineState withoutEditing() {
    return CardInlineState(
      composerColumnId: composerColumnId,
      composerTitle: composerTitle,
      composerDescription: composerDescription,
      composerDescriptionOpen: composerDescriptionOpen,
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
        other.editingTitle == editingTitle;
  }

  @override
  int get hashCode => Object.hash(
    composerColumnId,
    composerTitle,
    composerDescription,
    composerDescriptionOpen,
    editingCardId,
    editingTitle,
  );
}

class CardInlineNotifier extends Notifier<CardInlineState> {
  @override
  CardInlineState build() => const CardInlineState();

  void openComposer(String columnId) {
    if (state.composerColumnId == columnId) {
      return;
    }
    state = CardInlineState(
      composerColumnId: columnId,
      editingCardId: state.editingCardId,
      editingTitle: state.editingTitle,
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
    );
  }

  void startEditing(String cardId, String title) {
    if (state.editingCardId == cardId) {
      return;
    }
    state = CardInlineState(
      composerColumnId: state.composerColumnId,
      composerTitle: state.composerTitle,
      composerDescription: state.composerDescription,
      composerDescriptionOpen: state.composerDescriptionOpen,
      editingCardId: cardId,
      editingTitle: title,
    );
  }

  void setEditingTitle(String title) {
    final id = state.editingCardId;
    if (id == null) {
      return;
    }
    state = CardInlineState(
      composerColumnId: state.composerColumnId,
      composerTitle: state.composerTitle,
      composerDescription: state.composerDescription,
      composerDescriptionOpen: state.composerDescriptionOpen,
      editingCardId: id,
      editingTitle: title,
    );
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

class RuneLimitFormatter extends TextInputFormatter {
  const RuneLimitFormatter(this.limit);

  final int limit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final runes = newValue.text.runes;
    if (runes.length <= limit) {
      return newValue;
    }
    final text = String.fromCharCodes(runes.take(limit));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

bool isValidCardTitle(String raw) {
  final trimmed = raw.trim();
  return trimmed.isNotEmpty &&
      trimmed.runes.length <= CardLimits.titleMaxLength;
}
