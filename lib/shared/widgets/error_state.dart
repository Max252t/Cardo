import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/cardo_theme.dart';
import 'cardo_buttons.dart';

class CardoErrorState extends StatelessWidget {
  const CardoErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.code,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final layout = CardoLayout.of(context);
    final secondary = secondaryLabel;
    final codeText = code;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.section + spacing.xs),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.formMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.xl,
            children: <Widget>[
              ExcludeSemantics(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(radii.card),
                      border: Border.all(
                        color: colors.line,
                        width: sizes.hairline,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(spacing.xl),
                      child: Icon(
                        LucideIcons.triangleAlert,
                        size: layout.iconHeader + spacing.lg,
                        color: colors.nackText,
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.md,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: typography.titleLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: typography.body.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.cardGap,
                children: <Widget>[
                  CardoPrimaryButton(
                    label: retryLabel,
                    icon: LucideIcons.refreshCw,
                    onPressed: onRetry,
                  ),
                  if (secondary != null)
                    CardoSecondaryButton(
                      label: secondary,
                      onPressed: onSecondary,
                    ),
                ],
              ),
              if (codeText != null)
                Text(
                  codeText,
                  textAlign: TextAlign.center,
                  style: typography.mono.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
