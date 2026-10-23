import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import '../card_drafts.dart';
import '../card_sheet_data.dart';
import 'card_editor_body.dart';
import 'card_editor_style.dart';
import 'column_marker.dart';

Future<void> showCardSheet(BuildContext context, String cardId) async {
  final sizes = CardoSizes.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: BoxConstraints(maxWidth: sizes.previewMaxWidth),
    builder: (context) => CardSheet(cardId: cardId),
  );
  if (!context.mounted) {
    return;
  }
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(cardDraftsProvider.notifier).flush(cardId);
}

class CardSheet extends ConsumerWidget {
  const CardSheet({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(cardSheetProvider(cardId).select((data) => data == null), (
      previous,
      gone,
    ) {
      if (gone && context.mounted) {
        unawaited(Navigator.of(context).maybePop());
      }
    });
    final title = ref.watch(
      cardSheetProvider(cardId).select((data) => data?.title),
    );
    if (title == null) {
      return const SizedBox.shrink();
    }
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final height = MediaQuery.sizeOf(context).height - layout.sheetTopInset;
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: AppLocalizations.of(context).cardPanelSemantic(title),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.xl,
            end: spacing.xl,
            top: layout.sheetPaddingTop,
            bottom:
                layout.sheetPaddingBottom +
                MediaQuery.viewPaddingOf(context).bottom +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: layout.panelGap,
            children: <Widget>[
              const _SheetHandle(),
              _SheetTopBar(cardId: cardId),
              Expanded(
                child: CardEditorBody(
                  cardId: cardId,
                  variant: CardEditorVariant.sheet,
                  saveOnBlur: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: sizes.sheetHandleWidth,
          height: sizes.sheetHandleHeight,
          decoration: BoxDecoration(
            color: colors.lineStrong,
            borderRadius: BorderRadius.circular(CardoRadii.of(context).pill),
          ),
        ),
      ),
    );
  }
}

class _SheetTopBar extends ConsumerWidget {
  const _SheetTopBar({required this.cardId});

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
    final l10n = AppLocalizations.of(context);
    final column = data.column;
    return Row(
      spacing: CardoSpacing.of(context).xs,
      children: <Widget>[
        if (column != null)
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SheetColumnChip(column: column),
            ),
          )
        else
          const Spacer(),
        if (data.canEdit)
          _SheetIconButton(
            tooltip: l10n.cardPanelArchive,
            icon: LucideIcons.archive,
            foreground: colors.textSoft,
            onPressed: data.locked
                ? null
                : () => ref
                      .read(boardNotifierProvider.notifier)
                      .archiveCard(cardId),
          ),
        _SheetIconButton(
          tooltip: l10n.cardPanelClose,
          icon: LucideIcons.x,
          foreground: colors.textPrimary,
          background: colors.background,
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
        ),
      ],
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.background,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color? background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final sizes = CardoSizes.of(context);
    final size = Size.square(sizes.tapTarget);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: size,
        minimumSize: size,
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            CardoRadii.of(context).iconButton,
          ),
        ),
      ),
      iconSize: sizes.iconLarge,
      icon: Icon(icon),
    );
  }
}

class _SheetColumnChip extends StatelessWidget {
  const _SheetColumnChip({required this.column});

  final ColumnInfo column;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: layout.sheetChipHeight),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.badgePaddingHorizontal,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing.sm,
        children: <Widget>[
          ColumnMarkerSquare(
            marker: column.marker,
            size: layout.markerColumnDense,
            radius: radii.markerTab,
          ),
          Flexible(
            child: Text(
              column.title,
              style: typography.pill.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
