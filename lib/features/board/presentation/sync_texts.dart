import '../../../l10n/app_localizations.dart';
import '../domain/board_sync_state.dart';
import 'sync_views.dart';
import 'widgets/board_snackbar.dart';

String rejectedKindLabel(AppLocalizations l10n, RejectedOpKind kind) {
  return switch (kind) {
    RejectedOpKind.move => l10n.rejectedKindMove,
    RejectedOpKind.create => l10n.rejectedKindCreate,
    RejectedOpKind.editTitle => l10n.rejectedKindEditTitle,
    RejectedOpKind.editDescription => l10n.rejectedKindEditDescription,
    RejectedOpKind.archive => l10n.rejectedKindArchive,
    RejectedOpKind.createColumn => l10n.rejectedKindCreateColumn,
    RejectedOpKind.renameColumn => l10n.rejectedKindRenameColumn,
    RejectedOpKind.moveColumn => l10n.rejectedKindMoveColumn,
    RejectedOpKind.archiveColumn => l10n.rejectedKindArchiveColumn,
  };
}

String rejectedSubject(AppLocalizations l10n, RejectedItemView item) {
  final subject = item.subject;
  final isColumn = switch (item.kind) {
    RejectedOpKind.createColumn ||
    RejectedOpKind.renameColumn ||
    RejectedOpKind.moveColumn ||
    RejectedOpKind.archiveColumn => true,
    _ => false,
  };
  switch (item.kind) {
    case RejectedOpKind.create:
      return subject == null
          ? l10n.rejectedSubjectCard
          : l10n.rejectedSubjectNewCard(subject);
    case RejectedOpKind.createColumn:
      return subject == null
          ? l10n.rejectedSubjectColumn
          : l10n.rejectedSubjectNewColumn(subject);
    case RejectedOpKind.move:
      final column = item.destination;
      if (subject != null && column != null) {
        return l10n.rejectedSubjectMove(subject, column);
      }
      return subject ?? l10n.rejectedSubjectCard;
    default:
      return subject ??
          (isColumn ? l10n.rejectedSubjectColumn : l10n.rejectedSubjectCard);
  }
}

String rejectedReason(AppLocalizations l10n, RejectedItemView item) {
  final cause = item.dropCause;
  if (cause != null) {
    return switch (cause) {
      DropCause.stale => l10n.rejectedDropStale,
      DropCause.targetGone => l10n.rejectedDropGone,
    };
  }
  final rejection = item.rejection;
  if (rejection == null) {
    return l10n.nackInternalFinal;
  }
  return nackMessage(l10n, rejection, actorName: item.actorName);
}

String syncSummaryBody(AppLocalizations l10n, SyncSummaryView summary) {
  return summary.saved > 0
      ? l10n.syncSummaryBody
      : l10n.syncSummaryBodyAllFailed;
}

String rejectedSubtitle(AppLocalizations l10n, SyncSummaryView summary) {
  return summary.saved > 0
      ? l10n.rejectedSubtitleSaved(summary.saved)
      : l10n.rejectedSubtitle;
}
