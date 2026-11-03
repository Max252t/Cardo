import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/dashed_border.dart';
import '../../../../theme/cardo_theme.dart';
import 'add_card_slot.dart';

class ColumnEmptyState extends StatelessWidget {
  const ColumnEmptyState({
    super.key,
    required this.columnId,
    required this.dense,
    required this.canEdit,
  });

  final String columnId;
  final bool dense;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoColumnTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: tokens.emptyPaddingHorizontal,
          vertical: spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.xl - spacing.xxs,
          children: <Widget>[
            const ExcludeSemantics(child: EmptyColumnIllustration()),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.iconGap,
              children: <Widget>[
                Text(
                  l10n.columnEmptyTitle,
                  textAlign: TextAlign.center,
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
                Text(
                  canEdit ? l10n.columnEmptyBody : l10n.columnEmptyBodyViewer,
                  textAlign: TextAlign.center,
                  style: typography.message.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
            if (canEdit)
              AddCardSlot(columnId: columnId, dense: dense, prominent: true),
          ],
        ),
      ),
    );
  }
}

class EmptyColumnIllustration extends StatelessWidget {
  const EmptyColumnIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final tokens = CardoColumnTokens.of(context);
    final shadows = CardoShadows.of(context);
    final padding = spacing.cardPadding;
    return SizedBox(
      width: tokens.emptyWidth,
      height: tokens.emptyHeight,
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            start: tokens.ghostLeft,
            top: tokens.ghostTop,
            child: Transform.rotate(
              angle: tokens.ghostAngle,
              child: CustomPaint(
                foregroundPainter: DashedBorderPainter(
                  color: colors.outlineMuted,
                  strokeWidth: sizes.emphasisBorder,
                  radius: tokens.ghostRadius,
                  dashLength: sizes.dashLength,
                  gapLength: sizes.dashGap,
                ),
                child: SizedBox(
                  width: tokens.ghostWidth,
                  height: tokens.ghostHeight,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: tokens.sampleLeft,
            top: tokens.sampleTop,
            child: Transform.rotate(
              angle: tokens.sampleAngle,
              child: Container(
                width: tokens.ghostWidth,
                height: tokens.ghostHeight,
                padding: EdgeInsetsDirectional.all(padding),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(tokens.ghostRadius),
                  boxShadow: shadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: spacing.sm,
                  children: <Widget>[
                    _SampleLine(factor: tokens.sampleLineLong),
                    _SampleLine(factor: tokens.sampleLineShort),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: spacing.iconGap,
            child: Container(
              width: tokens.plusBadge,
              height: tokens.plusBadge,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(radii.pill),
              ),
              child: Icon(
                LucideIcons.plus,
                size: tokens.plusIcon,
                color: colors.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleLine extends StatelessWidget {
  const _SampleLine({required this.factor});

  final double factor;

  @override
  Widget build(BuildContext context) {
    final tokens = CardoColumnTokens.of(context);
    return FractionallySizedBox(
      widthFactor: factor,
      child: Container(
        height: tokens.sampleLineHeight,
        decoration: BoxDecoration(
          color: CardoColors.of(context).line,
          borderRadius: BorderRadius.circular(
            CardoRadii.of(context).markerColumn + 1,
          ),
        ),
      ),
    );
  }
}
