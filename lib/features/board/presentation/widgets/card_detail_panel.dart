import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_avatar.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../../domain/board_sync_state.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import 'card_panel_editor.dart';
import 'column_marker.dart';

class CardDetailPanel extends ConsumerWidget {
  const CardDetailPanel({super.key, required this.data});

  final CardViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(boardViewProvider);
    final canEdit = ref.watch(canEditBoardProvider);
    final column = board.columnById(data.card.columnId);
    final locked = data.status == CardSyncStatus.rejected;
    final otherColumns = <ColumnModel>[
      for (final other in board.orderedColumns)
        if (other.id != data.card.columnId) other,
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.cardPanelSemantic(data.card.title),
      child: Container(
        width: layout.detailPanelWidth,
        decoration: BoxDecoration(
          color: colors.surface,
          border: BorderDirectional(
            start: BorderSide(color: colors.line, width: sizes.hairline),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.screenDesktop,
            vertical: layout.panelPaddingVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: layout.panelGap,
            children: <Widget>[
              CardPanelTopBar(
                column: column,
                canEdit: canEdit,
                cardId: data.card.id,
                locked: locked,
              ),
              CardPanelTitle(data: data),
              CardDescriptionEditor(
                key: ValueKey<String>(data.card.id),
                description: data.card.description,
                readOnly: !canEdit,
              ),
              if (canEdit)
                CardPanelActions(
                  cardId: data.card.id,
                  otherColumns: otherColumns,
                  locked: locked,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardPanelTopBar extends ConsumerWidget {
  const CardPanelTopBar({
    super.key,
    required this.column,
    required this.canEdit,
    required this.cardId,
    this.locked = false,
  });

  final ColumnModel? column;
  final bool canEdit;
  final String cardId;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final current = column;
    return Row(
      spacing: spacing.xs,
      children: <Widget>[
        if (current != null)
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PanelColumnChip(column: current),
            ),
          )
        else
          const Spacer(),
        if (canEdit)
          IconButton(
            tooltip: l10n.cardPanelArchive,
            onPressed: locked
                ? null
                : () {
                    ref
                        .read(boardNotifierProvider.notifier)
                        .archiveCard(cardId);
                    ref.read(selectedCardIdProvider.notifier).clear();
                  },
            color: colors.textSecondary,
            iconSize: sizes.iconButton,
            icon: const Icon(LucideIcons.archive),
          ),
        IconButton(
          tooltip: l10n.cardPanelClose,
          onPressed: () => ref.read(selectedCardIdProvider.notifier).clear(),
          style: IconButton.styleFrom(
            backgroundColor: colors.card,
            foregroundColor: colors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radii.buttonSmall),
            ),
          ),
          iconSize: sizes.iconButton,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

class CardPanelTitle extends StatelessWidget {
  const CardPanelTitle({super.key, required this.data});

  final CardViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final author = data.createdBy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CardoLayout.of(context).panelGap,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            data.card.title,
            style: typography.cardTitle.copyWith(color: colors.textPrimary),
          ),
        ),
        Row(
          spacing: spacing.cardGap,
          children: <Widget>[
            if (author != null)
              CardoAvatar(identity: author, diameter: sizes.avatarFooter),
            Expanded(
              child: Text(
                author == null ? '' : l10n.cardPanelCreatedBy(author.name),
                style: typography.captionLarge.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              l10n.cardPanelVersion(data.card.version),
              style: typography.mono.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class PanelColumnChip extends StatelessWidget {
  const PanelColumnChip({super.key, required this.column});

  final ColumnModel column;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: CardoLayout.of(context).panelChipHeight,
      ),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.cardGap,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radii.badge),
        border: Border.all(color: colors.cardBorder, width: sizes.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing.sm,
        children: <Widget>[
          ColumnMarkerSquare(
            marker: column.marker,
            size: sizes.markerTab,
            radius: radii.markerTab,
          ),
          Flexible(
            child: Text(
              column.title,
              style: typography.caption.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
