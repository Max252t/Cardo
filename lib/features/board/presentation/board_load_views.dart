import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../theme/cardo_theme.dart';
import '../../boards/presentation/widgets/boards_states.dart';

class BoardLoadingView extends StatelessWidget {
  const BoardLoadingView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final layout = CardoLayout.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: BorderDirectional(
                bottom: BorderSide(color: colors.line, width: sizes.hairline),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md,
                  end: spacing.md,
                  top: layout.headerPaddingTop,
                  bottom: spacing.md,
                ),
                child: Row(
                  spacing: spacing.xs,
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.boardBack,
                      onPressed: onBack,
                      iconSize: layout.iconHeader,
                      icon: const Icon(LucideIcons.chevronLeft),
                    ),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.boardLoadingTitle,
                          style: typography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: BoardSkeletonColumns()),
        ],
      ),
    );
  }
}

class BoardSkeletonColumns extends StatelessWidget {
  const BoardSkeletonColumns({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final layout = CardoLayout.of(context);
    return ExcludeSemantics(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          start: spacing.screen,
          top: spacing.screen,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.columnGap,
          children: <Widget>[
            for (final cards in const <int>[3, 1, 2])
              Container(
                width: layout.columnWidth,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: layout.columnPaddingHorizontal,
                  vertical: layout.columnPaddingVertical,
                ),
                decoration: BoxDecoration(
                  color: colors.column,
                  borderRadius: BorderRadiusDirectional.vertical(
                    top: Radius.circular(radii.column),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.cardGap,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: layout.columnHeaderInset,
                        vertical: spacing.xs,
                      ),
                      child: SkeletonBar(
                        widthFactor: 0.4,
                        color: colors.lineStrong,
                      ),
                    ),
                    for (var i = 0; i < cards; i++)
                      Container(
                        padding: EdgeInsetsDirectional.all(spacing.cardPadding),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(radii.card),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: spacing.cardGap,
                          children: <Widget>[
                            SkeletonBar(
                              widthFactor: 0.85,
                              color: colors.background,
                            ),
                            SkeletonBar(
                              widthFactor: 0.55,
                              color: colors.background,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BoardLoadErrorView extends StatelessWidget {
  const BoardLoadErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: spacing.md,
                top: spacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: l10n.boardBack,
                  onPressed: onBack,
                  iconSize: layout.iconHeader,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
              ),
            ),
            Expanded(
              child: CardoErrorState(
                title: l10n.boardLoadErrorTitle,
                message: describeApiFailure(l10n, failure),
                retryLabel: l10n.commonRetry,
                onRetry: onRetry,
                secondaryLabel: l10n.boardLoadErrorToList,
                onSecondary: onBack,
                code: l10n.boardLoadErrorCode(apiFailureCode(failure)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
