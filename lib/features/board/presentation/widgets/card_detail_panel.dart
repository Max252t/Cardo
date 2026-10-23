import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import '../card_sheet_data.dart';
import 'card_editor_body.dart';
import 'card_editor_style.dart';
import 'card_panel_actions.dart';
import 'column_marker.dart';

class CardDetailPanel extends ConsumerWidget {
  const CardDetailPanel({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cardSheetProvider(cardId).select((data) => data?.chrome),
    );
    if (data == null) {
      return const SizedBox.shrink();
    }
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.cardPanelSemantic(data.title),
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
              _PanelTopBar(data: data),
              CardEditorBody(
                key: ValueKey<String>(cardId),
                cardId: cardId,
                variant: CardEditorVariant.panel,
              ),
              if (data.canEdit)
                CardPanelActions(
                  cardId: cardId,
                  otherColumns: data.moveTargets,
                  canSave: data.canSave,
                  locked: data.locked,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelTopBar extends ConsumerWidget {
  const _PanelTopBar({required this.data});

  final CardChromeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final column = data.column;
    return Row(
      spacing: spacing.xs,
      children: <Widget>[
        if (column != null)
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _PanelColumnChip(column: column),
            ),
          )
        else
          const Spacer(),
        if (data.canEdit)
          IconButton(
            tooltip: l10n.cardPanelArchive,
            onPressed: data.locked
                ? null
                : () {
                    ref
                        .read(boardNotifierProvider.notifier)
                        .archiveCard(data.cardId);
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

class _PanelColumnChip extends StatelessWidget {
  const _PanelColumnChip({required this.column});

  final ColumnInfo column;

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
