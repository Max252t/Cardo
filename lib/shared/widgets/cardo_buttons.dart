import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

class CardoPrimaryButton extends StatelessWidget {
  const CardoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.large = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(
          sizes.tapTarget,
          large ? metrics.largeButtonHeight : sizes.buttonHeight,
        ),
        disabledBackgroundColor: busy ? colors.emphasis : null,
        disabledForegroundColor: busy ? colors.onEmphasis : null,
      ),
      child: busy
          ? BusyIndicator(color: colors.onEmphasis)
          : ButtonLabel(label: label, icon: icon),
    );
  }
}

class CardoSecondaryButton extends StatelessWidget {
  const CardoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.large = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final sizes = CardoSizes.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          sizes.tapTarget,
          large ? metrics.largeButtonHeight : sizes.buttonHeight,
        ),
      ),
      child: ButtonLabel(label: label, icon: icon),
    );
  }
}

class ButtonLabel extends StatelessWidget {
  const ButtonLabel({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final glyph = icon;
    if (glyph == null) {
      return Text(label, textAlign: TextAlign.center);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.sm,
      children: <Widget>[
        Icon(glyph, size: sizes.iconButton),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}

class BusyIndicator extends StatelessWidget {
  const BusyIndicator({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    return SizedBox.square(
      dimension: metrics.progressSize,
      child: CircularProgressIndicator(
        strokeWidth: metrics.progressStroke,
        color: color,
        semanticsLabel: AppLocalizations.of(context).commonLoading,
      ),
    );
  }
}
