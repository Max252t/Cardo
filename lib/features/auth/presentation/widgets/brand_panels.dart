import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_logo.dart';
import '../../../../theme/cardo_theme.dart';

class BrandHero extends StatelessWidget {
  const BrandHero({super.key});

  static final ThemeData _dark = buildDarkTheme();

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    return Theme(
      data: _dark,
      child: Builder(
        builder: (context) {
          final colors = CardoColors.of(context);
          final spacing = CardoSpacing.of(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadiusDirectional.vertical(
                bottom: Radius.circular(metrics.heroRadius),
              ),
            ),
            child: SizedBox(
              height: metrics.heroHeight,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.all(spacing.xl),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CardoLogo(),
                      Expanded(child: Center(child: BrandIllustration())),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  static final ThemeData _dark = buildDarkTheme();

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: _dark,
      child: Builder(
        builder: (context) {
          final colors = CardoColors.of(context);
          final typography = CardoTypography.of(context);
          final spacing = CardoSpacing.of(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(metrics.brandPanelRadius),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.section + spacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: spacing.section,
                        children: <Widget>[
                          const CardoLogo(),
                          const Expanded(
                            child: Center(child: BrandIllustration()),
                          ),
                          Text(
                            l10n.loginBrandHeadline,
                            style: typography.display.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n.loginBrandBody,
                            style: typography.paragraph.copyWith(
                              color: colors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BrandIllustration extends StatelessWidget {
  const BrandIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: metrics.illustrationWidth,
        height: metrics.illustrationHeight,
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              start: 0,
              top: spacing.md,
              child: Transform.rotate(
                angle: -metrics.brandCardTilt,
                child: _BrandCard(
                  fill: colors.card,
                  border: colors.cardBorder,
                  borderWidth: sizes.hairline,
                  radius: radii.card,
                  bars: <double>[0.7, 0.45],
                  barColor: colors.lineStrong,
                ),
              ),
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Transform.rotate(
                angle: metrics.brandCardTilt / 2,
                child: _BrandCard(
                  fill: colors.textPrimary,
                  border: colors.accent,
                  borderWidth: sizes.emphasisBorder,
                  radius: radii.card,
                  bars: <double>[0.8, 0.5],
                  barColor: colors.background,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.radius,
    required this.bars,
    required this.barColor,
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final double radius;
  final List<double> bars;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final spacing = CardoSpacing.of(context);
    return Container(
      width: metrics.brandCardWidth,
      height: metrics.brandCardHeight,
      padding: EdgeInsetsDirectional.all(spacing.lg),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.md,
        children: <Widget>[
          for (final fraction in bars)
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: spacing.sm,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(spacing.xs),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
