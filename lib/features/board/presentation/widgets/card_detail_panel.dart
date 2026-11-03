import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../card_inline_state.dart';
import '../card_sheet_data.dart';
import 'card_editor_body.dart';
import 'card_editor_parts.dart';
import 'card_editor_style.dart';
import 'card_panel_actions.dart';

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
    final spacing = CardoSpacing.of(context);
    final style = CardEditorStyle.of(context, CardEditorVariant.panel);
    final l10n = AppLocalizations.of(context);
    final column = data.column;
    return Row(
      spacing: spacing.xs,
      children: <Widget>[
        if (column != null)
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CardColumnChip(column: column, style: style),
            ),
          )
        else
          const Spacer(),
        if (data.canEdit)
          CardIconButton(
            tooltip: l10n.cardInlineEditAction,
            icon: LucideIcons.pencil,
            style: style,
            foreground: style.quietForeground,
            onPressed: data.locked
                ? null
                : () => ref
                      .read(cardInlineProvider.notifier)
                      .startEditing(data.cardId, data.title),
          ),
        if (data.canEdit)
          CardIconButton(
            tooltip: l10n.cardPanelArchive,
            icon: LucideIcons.archive,
            style: style,
            foreground: style.quietForeground,
            onPressed: data.locked
                ? null
                : () {
                    ref
                        .read(boardNotifierProvider.notifier)
                        .archiveCard(data.cardId);
                    ref.read(selectedCardIdProvider.notifier).clear();
                  },
          ),
        CardIconButton(
          tooltip: l10n.cardPanelClose,
          icon: LucideIcons.x,
          style: style,
          foreground: colors.textPrimary,
          background: style.closeBackground,
          onPressed: () => ref.read(selectedCardIdProvider.notifier).clear(),
        ),
      ],
    );
  }
}
