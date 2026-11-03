import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/connection_status.dart';
import '../domain/board_model.dart';
import '../domain/board_sync_state.dart';
import '../domain/card_draft.dart';
import '../domain/unsaved_text.dart';
import 'board_providers.dart';
import 'card_drafts.dart';

@immutable
class RejectedItemView {
  const RejectedItemView({
    required this.opId,
    required this.kind,
    required this.subject,
    required this.destination,
    required this.rejection,
    required this.dropCause,
    required this.actorName,
    required this.copyText,
    required this.showCardId,
  });

  final String opId;
  final RejectedOpKind kind;
  final String? subject;
  final String? destination;
  final OpRejection? rejection;
  final DropCause? dropCause;
  final String? actorName;
  final String copyText;
  final String? showCardId;

  @override
  bool operator ==(Object other) {
    return other is RejectedItemView &&
        other.opId == opId &&
        other.kind == kind &&
        other.subject == subject &&
        other.destination == destination &&
        other.rejection == rejection &&
        other.dropCause == dropCause &&
        other.actorName == actorName &&
        other.copyText == copyText &&
        other.showCardId == showCardId;
  }

  @override
  int get hashCode => Object.hash(
    opId,
    kind,
    subject,
    destination,
    rejection,
    dropCause,
    actorName,
    copyText,
    showCardId,
  );
}

@immutable
class SyncSummaryView {
  const SyncSummaryView({required this.failed, required this.saved});

  final int failed;
  final int saved;

  @override
  bool operator ==(Object other) {
    return other is SyncSummaryView &&
        other.failed == failed &&
        other.saved == saved;
  }

  @override
  int get hashCode => Object.hash(failed, saved);
}

SyncSummaryView? syncSummaryViewOf(SyncSummary? summary) {
  if (summary == null) {
    return null;
  }
  return SyncSummaryView(
    failed: summary.failedCount,
    saved: summary.savedCount,
  );
}

List<RejectedItemView> rejectedItemsOf(
  SyncSummary? summary,
  RejectionLog log,
  BoardModel board,
) {
  if (summary == null) {
    return const <RejectedItemView>[];
  }
  return <RejectedItemView>[
    for (final entry in log.forIds(summary.failedIds))
      RejectedItemView(
        opId: entry.opId,
        kind: entry.kind,
        subject: entry.subject,
        destination: entry.destination,
        rejection: entry.rejection,
        dropCause: entry.dropCause,
        actorName: entry.actorId == null
            ? null
            : board.memberById(entry.actorId!)?.name,
        copyText: entry.copyText,
        showCardId: _showableCard(entry, board),
      ),
  ];
}

String? _showableCard(RejectedOp entry, BoardModel board) {
  final cardId = entry.cardId;
  if (cardId == null || board.activeCard(cardId) == null) {
    return null;
  }
  return cardId;
}

@immutable
class UnsavedTextView {
  const UnsavedTextView({
    required this.cardId,
    required this.cardTitle,
    required this.text,
  });

  final String cardId;
  final String? cardTitle;
  final String text;

  @override
  bool operator ==(Object other) {
    return other is UnsavedTextView &&
        other.cardId == cardId &&
        other.cardTitle == cardTitle &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(cardId, cardTitle, text);
}

List<UnsavedTextView> unsavedTextViewsOf(
  Iterable<CardDraft> drafts,
  BoardSyncState state,
) {
  return <UnsavedTextView>[
    for (final item in unsavedDescriptions(drafts, state))
      UnsavedTextView(
        cardId: item.cardId,
        cardTitle: item.cardTitle,
        text: item.text,
      ),
  ];
}

int? offlineBannerCountOf(BoardSyncState state) {
  if (state.ended != null) {
    return null;
  }
  final offline =
      state.connection == ConnectionStatus.offline ||
      state.connection == ConnectionStatus.reconnecting;
  final waiting = state.waitingCount;
  return offline && waiting > 0 ? waiting : null;
}

final offlineBannerCountProvider = Provider<int?>(
  (ref) => ref.watch(boardNotifierProvider.select(offlineBannerCountOf)),
  dependencies: [boardNotifierProvider],
);

final syncSummaryProvider = Provider<SyncSummaryView?>(
  (ref) => syncSummaryViewOf(
    ref.watch(boardNotifierProvider.select((state) => state.summary)),
  ),
  dependencies: [boardNotifierProvider],
);

final rejectedItemsProvider = Provider<List<RejectedItemView>>((ref) {
  final (summary, log) = ref.watch(
    boardNotifierProvider.select((state) => (state.summary, state.rejections)),
  );
  return rejectedItemsOf(summary, log, ref.watch(boardViewProvider));
}, dependencies: [boardNotifierProvider, boardViewProvider]);

final unsavedTextsProvider = Provider<List<UnsavedTextView>>(
  (ref) => unsavedTextViewsOf(
    ref.watch(cardDraftsProvider).values,
    ref.watch(boardNotifierProvider),
  ),
  dependencies: [cardDraftsProvider, boardNotifierProvider],
);
