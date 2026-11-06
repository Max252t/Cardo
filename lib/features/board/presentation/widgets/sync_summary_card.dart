import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../sync_texts.dart';
import '../sync_views.dart';

class SyncSummaryOverlay extends ConsumerWidget {
  const SyncSummaryOverlay({super.key, required this.onDetails});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(syncSummaryProvider);
    final motion = CardoMotion.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoSyncTokens.of(context);
    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: resolveMotion(context, motion.reorder),
          switchInCurve: motion.reorderCurve,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: summary == null
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey<String>('sync-summary'),
                  padding: EdgeInsetsDirectional.only(
                    start: spacing.md,
                    end: spacing.md,
                    bottom: tokens.summaryBottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: tokens.summaryMaxWidth,
                    ),
                    child: SyncSummaryCard(
                      summary: summary,
                      onHide: ref
                          .read(boardNotifierProvider.notifier)
                          .dismissSummary,
                      onDetails: onDetails,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class SyncSummaryCard extends StatelessWidget {
  const SyncSummaryCard({
    super.key,
    required this.summary,
    required this.onHide,
    required this.onDetails,
  });

  final SyncSummaryView summary;
  final VoidCallback onHide;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final title = l10n.syncSummaryTitle(summary.failed);
    final body = syncSummaryBody(l10n, summary);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CardoRadii.of(context).iconButton),
    );
    final minimum = Size(sizes.tapTarget, sizes.tapTarget);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.snackbarBackground,
        borderRadius: BorderRadius.circular(CardoRadii.of(context).snackbar),
        boxShadow: CardoShadows.of(context).dragging,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.md,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: '$title. $body',
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: spacing.md,
                      children: <Widget>[
                        Icon(
                          LucideIcons.circleAlert,
                          size: sizes.iconLarge,
                          color: colors.snackbarIcon,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: spacing.xs,
                            children: <Widget>[
                              Text(
                                title,
                                style: typography.button.copyWith(
                                  color: colors.snackbarText,
                                ),
                              ),
                              Text(
                                body,
                                style: typography.bannerText.copyWith(
                                  color: colors.snackbarText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: <Widget>[
                TextButton(
                  onPressed: onHide,
                  style: TextButton.styleFrom(
                    minimumSize: minimum,
                    shape: shape,
                    foregroundColor: colors.snackbarText,
                    textStyle: typography.buttonCompact,
                  ),
                  child: Text(l10n.syncSummaryHide),
                ),
                FilledButton(
                  onPressed: onDetails,
                  style: FilledButton.styleFrom(
                    minimumSize: minimum,
                    shape: shape,
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    textStyle: typography.buttonCompact,
                  ),
                  child: Text(l10n.syncSummaryDetails),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
