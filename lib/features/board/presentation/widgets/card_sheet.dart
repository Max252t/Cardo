import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../card_drafts.dart';
import '../card_inline_state.dart';
import '../card_sheet_data.dart';
import 'card_editor_body.dart';
import 'card_editor_parts.dart';
import 'card_editor_style.dart';

Future<void> showCardSheet(BuildContext context, String cardId) async {
  final sizes = CardoSizes.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: BoxConstraints(maxWidth: sizes.previewMaxWidth),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: CardSheet(cardId: cardId),
    ),
  );
  if (!context.mounted) {
    return;
  }
  container.read(cardDraftsProvider.notifier).flush(cardId);
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
    ref.listen<bool>(
      boardNotifierProvider.select((state) => state.ended != null),
      (previous, ended) {
        final route = ModalRoute.of(context);
        if (ended && context.mounted && route != null) {
          Navigator.of(context).removeRoute(route);
        }
      },
    );
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
    final style = CardEditorStyle.of(context, CardEditorVariant.sheet);
    final l10n = AppLocalizations.of(context);
    final column = data.column;
    return Row(
      spacing: CardoSpacing.of(context).xs,
      children: <Widget>[
        if (column != null)
          Expanded(
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
                : () {
                    ref
                        .read(cardInlineProvider.notifier)
                        .startEditing(cardId, data.title);
                    unawaited(Navigator.of(context).maybePop());
                  },
          ),
        if (data.canEdit)
          CardIconButton(
            tooltip: l10n.cardPanelArchive,
            icon: LucideIcons.archive,
            style: style,
            foreground: style.quietForeground,
            onPressed: data.locked
                ? null
                : () => ref
                      .read(boardNotifierProvider.notifier)
                      .archiveCard(cardId),
          ),
        CardIconButton(
          tooltip: l10n.cardPanelClose,
          icon: LucideIcons.x,
          style: style,
          foreground: colors.textPrimary,
          background: style.closeBackground,
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
        ),
      ],
    );
  }
}
