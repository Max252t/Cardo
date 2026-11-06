import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_sync_state.dart';
import '../sync_views.dart';
import 'copy_text_button.dart';

Future<void> showBoardEndedDialog(
  BuildContext context, {
  required BoardEndReason reason,
  required String boardTitle,
  required List<UnsavedTextView> unsaved,
  required VoidCallback onLeave,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => BoardEndedDialog(
      reason: reason,
      boardTitle: boardTitle,
      unsaved: unsaved,
      onLeave: onLeave,
    ),
  );
}

class BoardEndedDialog extends StatefulWidget {
  const BoardEndedDialog({
    super.key,
    required this.reason,
    required this.boardTitle,
    required this.unsaved,
    required this.onLeave,
  });

  final BoardEndReason reason;
  final String boardTitle;
  final List<UnsavedTextView> unsaved;
  final VoidCallback onLeave;

  @override
  State<BoardEndedDialog> createState() => _BoardEndedDialogState();
}

class _BoardEndedDialogState extends State<BoardEndedDialog> {
  bool _left = false;

  void _leave() {
    if (_left) {
      return;
    }
    _left = true;
    Navigator.of(context).pop();
    widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final form = CardoFormTokens.of(context);
    final tokens = CardoSyncTokens.of(context);
    final deleted = widget.reason == BoardEndReason.boardDeleted;
    final title = switch (widget.reason) {
      BoardEndReason.boardDeleted => l10n.boardEndedDeletedTitle,
      _ => l10n.boardEndedRemovedTitle,
    };
    final body = switch (widget.reason) {
      BoardEndReason.removed => l10n.boardEndedRemovedBody(widget.boardTitle),
      BoardEndReason.boardDeleted => l10n.boardEndedDeletedBody(
        widget.boardTitle,
      ),
      _ => l10n.boardEndedAccessLostBody,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leave();
        }
      },
      child: Dialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(form.dialogRadius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: form.dialogMaxWidth),
          child: Semantics(
            container: true,
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: title,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.xl,
                  end: spacing.xl,
                  top: spacing.section - spacing.xs,
                  bottom: spacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.lg,
                  children: <Widget>[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExcludeSemantics(
                        child: Container(
                          width: tokens.noticeIconBox,
                          height: tokens.noticeIconBox,
                          decoration: BoxDecoration(
                            color: colors.snackbarBackground,
                            borderRadius: BorderRadius.circular(
                              tokens.noticeIconRadius,
                            ),
                          ),
                          child: Icon(
                            deleted ? LucideIcons.trash2 : LucideIcons.lock,
                            size: tokens.noticeIcon,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: spacing.sm,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: typography.cardTitle.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          body,
                          style: typography.sheetField.copyWith(
                            color: colors.textSoft,
                          ),
                        ),
                      ],
                    ),
                    if (widget.unsaved.isNotEmpty)
                      UnsavedTextList(items: widget.unsaved),
                    FilledButton(
                      onPressed: _leave,
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(form.largeButtonHeight),
                      ),
                      child: Text(l10n.boardEndedAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnsavedTextList extends StatelessWidget {
  const UnsavedTextList({super.key, required this.items});

  final List<UnsavedTextView> items;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: <Widget>[
        Text(
          l10n.boardEndedUnsavedHeading,
          style: typography.label.copyWith(color: colors.textSecondary),
        ),
        for (final item in items)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.selectionFill,
              borderRadius: BorderRadius.circular(CardoRadii.of(context).field),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.sm,
                children: <Widget>[
                  if (item.cardTitle != null)
                    Text(
                      item.cardTitle!,
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  Text(
                    item.text,
                    style: typography.bannerText.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  CopyTextButton(
                    text: item.text,
                    label: l10n.cardDraftLostCopy,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
