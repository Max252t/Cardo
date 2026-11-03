import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../sync_views.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(offlineBannerCountProvider);
    final motion = CardoMotion.of(context);
    final duration = resolveMotion(context, motion.reorder);
    final content = count == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: EdgeInsetsDirectional.only(
              top: CardoSpacing.of(context).md,
            ),
            child: OfflineBannerBody(
              count: count,
              onRetry: ref.read(boardNotifierProvider.notifier).retryConnection,
            ),
          );
    if (duration == Duration.zero) {
      return content;
    }
    return AnimatedSize(
      duration: duration,
      curve: motion.reorderCurve,
      alignment: AlignmentDirectional.topCenter,
      child: content,
    );
  }
}

class OfflineBannerBody extends StatelessWidget {
  const OfflineBannerBody({
    super.key,
    required this.count,
    required this.onRetry,
  });

  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >=
        CardoLayout.of(context).stackActionsTextScale;
    final message = Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        spacing: spacing.md,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              LucideIcons.wifiOff,
              size: sizes.iconButton,
              color: colors.snackbarText,
            ),
          ),
          Expanded(
            child: Text(
              l10n.syncOfflineBanner(count),
              style: typography.bodyDense.copyWith(color: colors.snackbarText),
            ),
          ),
        ],
      ),
    );
    final retry = TextButton(
      onPressed: onRetry,
      style: TextButton.styleFrom(
        minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
        padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
        backgroundColor: colors.snackbarAction,
        foregroundColor: colors.snackbarActionText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            CardoRadii.of(context).buttonSmall,
          ),
        ),
        textStyle: typography.buttonSmall,
      ),
      child: Text(l10n.commonRetry),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.snackbarBackground,
        borderRadius: BorderRadius.circular(CardoRadii.of(context).field),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: spacing.cardPadding,
          end: spacing.sm,
          top: spacing.sm,
          bottom: spacing.sm,
        ),
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.sm,
                children: <Widget>[
                  message,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: retry,
                  ),
                ],
              )
            : Row(
                spacing: spacing.sm,
                children: <Widget>[
                  Expanded(child: message),
                  retry,
                ],
              ),
      ),
    );
  }
}
