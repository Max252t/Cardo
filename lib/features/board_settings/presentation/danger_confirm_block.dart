import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../theme/cardo_theme.dart';

class DangerZone extends StatelessWidget {
  const DangerZone({
    super.key,
    required this.title,
    required this.body,
    required this.startLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.confirming,
    required this.busy,
    required this.locked,
    required this.failure,
    required this.onStart,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String startLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final bool confirming;
  final bool busy;
  final bool locked;
  final ApiFailure? failure;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoColumnTokens.of(context);
    final radii = CardoRadii.of(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.button),
    );
    final buttonSize = Size(sizes.tapTarget, sizes.buttonHeight);
    final error = failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.md,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.boardSettingsDanger,
            style: typography.overline.copyWith(color: colors.nackText),
          ),
        ),
        if (!confirming)
          OutlinedButton(
            onPressed: onStart,
            style: OutlinedButton.styleFrom(
              minimumSize: buttonSize,
              foregroundColor: colors.nackText,
              backgroundColor: colors.nackBackground,
              shape: buttonShape,
              side: BorderSide(color: colors.nackBorder, width: sizes.hairline),
            ),
            child: Text(startLabel, textAlign: TextAlign.center),
          )
        else
          Container(
            padding: EdgeInsetsDirectional.all(spacing.lg),
            decoration: BoxDecoration(
              color: colors.nackBackground,
              borderRadius: BorderRadius.circular(tokens.dangerRadius),
              border: Border.all(
                color: colors.nackBorder,
                width: sizes.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.md + spacing.xxs,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: spacing.xs,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: typography.paragraph.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      body,
                      style: typography.message.copyWith(
                        color: colors.textSoft,
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  FormMessage(message: describeApiFailure(l10n, error)),
                Row(
                  spacing: spacing.sm,
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: locked ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: colors.surface,
                          foregroundColor: colors.textPrimary,
                          shape: buttonShape,
                          side: BorderSide(
                            color: colors.nackBorder,
                            width: sizes.hairline,
                          ),
                        ),
                        child: Text(
                          l10n.commonCancel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: locked ? null : onConfirm,
                        style: FilledButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: colors.nackText,
                          foregroundColor: colors.surface,
                          disabledBackgroundColor: colors.nackText,
                          disabledForegroundColor: colors.surface,
                          shape: buttonShape,
                        ),
                        child: busy
                            ? BusyIndicator(color: colors.surface)
                            : ButtonLabel(
                                label: confirmLabel,
                                icon: confirmIcon,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
