import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../theme/cardo_theme.dart';

class BoardsSkeleton extends StatelessWidget {
  const BoardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    return Semantics(
      label: l10n.commonLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.all(spacing.screen + spacing.xs),
          children: <Widget>[
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(bottom: spacing.md),
                child: Container(
                  height: metrics.skeletonCardHeight,
                  padding: EdgeInsetsDirectional.all(spacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(radii.columnDense),
                    border: Border.all(
                      color: colors.line,
                      width: sizes.hairline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.md,
                    children: <Widget>[
                      SkeletonBar(widthFactor: 0.6, color: colors.column),
                      SkeletonBar(widthFactor: 0.35, color: colors.column),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SkeletonBar extends StatelessWidget {
  const SkeletonBar({
    super.key,
    required this.widthFactor,
    required this.color,
  });

  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final spacing = CardoSpacing.of(context);
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: metrics.skeletonLine,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(spacing.xs + spacing.xxs),
        ),
      ),
    );
  }
}

class BoardsEmpty extends StatelessWidget {
  const BoardsEmpty({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.section + spacing.xs),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.section,
            children: <Widget>[
              const EmptyIllustration(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.cardGap,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.boardsEmptyTitle,
                      textAlign: TextAlign.center,
                      style: typography.titleLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    l10n.boardsEmptyBody,
                    textAlign: TextAlign.center,
                    style: typography.body.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              CardoPrimaryButton(
                label: l10n.boardsEmptyAction,
                icon: LucideIcons.plus,
                onPressed: onCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: metrics.illustrationWidth,
          height: metrics.illustrationHeight,
          child: Stack(
            children: <Widget>[
              for (final (index, accent) in <Color>[
                colors.columnBacklog,
                colors.columnInProgress,
                colors.columnDone,
              ].indexed)
                PositionedDirectional(
                  start: index * (metrics.illustrationWidth / 3),
                  top: index == 1 ? 0 : spacing.xl,
                  child: Container(
                    width: metrics.illustrationWidth / 3 - spacing.sm,
                    height: metrics.illustrationHeight - spacing.xl * 2,
                    padding: EdgeInsetsDirectional.all(spacing.sm),
                    decoration: BoxDecoration(
                      color: colors.column,
                      borderRadius: BorderRadius.circular(radii.card),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: SkeletonBar(widthFactor: 0.6, color: accent),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: metrics.illustrationWidth / 3,
                top: spacing.section + spacing.md,
                child: Transform.rotate(
                  angle: -metrics.brandCardTilt,
                  child: Container(
                    width: metrics.illustrationWidth / 2,
                    height: metrics.illustrationHeight / 3,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(radii.buttonSmall),
                      border: Border.all(
                        color: colors.accent,
                        width: sizes.emphasisBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
