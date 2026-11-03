import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../sync_texts.dart';
import '../sync_views.dart';
import 'copy_text_button.dart';

Future<String?> showRejectedOps(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final layout = CardoLayout.of(context);
  final expanded =
      layout.windowClassFor(MediaQuery.sizeOf(context).width) ==
      CardoWindowClass.expanded;
  final String? shown;
  if (expanded) {
    shown = await showDialog<String>(
      context: context,
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: const RejectedOpsDialog(),
      ),
    );
  } else {
    shown = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      constraints: BoxConstraints(
        maxWidth: CardoSizes.of(context).previewMaxWidth,
      ),
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: const RejectedOpsSheet(),
      ),
    );
  }
  if (context.mounted) {
    container.read(boardNotifierProvider.notifier).acknowledgeRejections();
  }
  return shown;
}

class RejectedOpsSheet extends StatelessWidget {
  const RejectedOpsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final colors = CardoColors.of(context);
    final height = MediaQuery.sizeOf(context).height - layout.sheetTopInset;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: spacing.xl,
          end: spacing.xl,
          top: layout.sheetPaddingTop,
          bottom:
              layout.sheetPaddingBottom +
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: layout.panelGap,
          children: <Widget>[
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: sizes.sheetHandleWidth,
                  height: sizes.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: BorderRadius.circular(
                      CardoRadii.of(context).pill,
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(child: RejectedOpsPanel(fill: true)),
          ],
        ),
      ),
    );
  }
}

class RejectedOpsDialog extends StatelessWidget {
  const RejectedOpsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.dialogMaxWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.section),
          child: const RejectedOpsPanel(fill: false),
        ),
      ),
    );
  }
}

class RejectedOpsPanel extends ConsumerStatefulWidget {
  const RejectedOpsPanel({super.key, required this.fill});

  final bool fill;

  @override
  ConsumerState<RejectedOpsPanel> createState() => _RejectedOpsPanelState();
}

class _RejectedOpsPanelState extends ConsumerState<RejectedOpsPanel> {
  List<RejectedItemView> _lastItems = const <RejectedItemView>[];
  SyncSummaryView? _lastSummary;

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill;
    final watchedItems = ref.watch(rejectedItemsProvider);
    if (watchedItems.isNotEmpty) {
      _lastItems = watchedItems;
      _lastSummary = ref.watch(syncSummaryProvider) ?? _lastSummary;
    }
    final items = _lastItems;
    final summary = _lastSummary;
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final form = CardoFormTokens.of(context);
    final tokens = CardoSyncTokens.of(context);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.rejectedTitle(items.length),
            style: typography.sheetTitle.copyWith(color: colors.textPrimary),
          ),
        ),
        if (summary != null)
          Text(
            rejectedSubtitle(l10n, summary),
            style: typography.message.copyWith(color: colors.textSecondary),
          ),
      ],
    );
    final list = ListView.separated(
      shrinkWrap: !fill,
      itemCount: items.length + 1,
      separatorBuilder: (context, index) =>
          SizedBox(height: index == 0 ? spacing.lg : tokens.rejectedItemGap),
      itemBuilder: (context, index) =>
          index == 0 ? header : RejectedItemCard(item: items[index - 1]),
    );
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: l10n.rejectedSemantic,
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.lg,
        children: <Widget>[
          if (fill) Expanded(child: list) else Flexible(child: list),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(form.largeButtonHeight),
            ),
            child: Text(l10n.rejectedClose),
          ),
        ],
      ),
    );
  }
}

class RejectedItemCard extends StatelessWidget {
  const RejectedItemCard({super.key, required this.item});

  final RejectedItemView item;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final showCardId = item.showCardId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CardoRadii.of(context).editor),
        border: Border.all(color: colors.line, width: sizes.hairline),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.cardGap,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.cardGap,
              children: <Widget>[
                Expanded(
                  child: Text(
                    rejectedSubject(l10n, item),
                    style: typography.body.copyWith(color: colors.textPrimary),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(top: spacing.xxs),
                    child: Text(
                      rejectedKindLabel(l10n, item.kind),
                      textAlign: TextAlign.end,
                      style: typography.mono.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.sm,
              children: <Widget>[
                ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(top: spacing.xxs),
                    child: Icon(
                      LucideIcons.circleAlert,
                      size: sizes.iconButton,
                      color: colors.nackText,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rejectedReason(l10n, item),
                    style: typography.bannerText.copyWith(
                      color: colors.nackText,
                    ),
                  ),
                ),
              ],
            ),
            if (showCardId != null || item.copyText.isNotEmpty)
              Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: <Widget>[
                  if (showCardId != null)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(showCardId),
                      style: outlinedActionStyle(context),
                      child: Text(l10n.rejectedShowOnBoard),
                    ),
                  if (item.copyText.isNotEmpty)
                    CopyTextButton(
                      text: item.copyText,
                      label: l10n.rejectedCopyText,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
