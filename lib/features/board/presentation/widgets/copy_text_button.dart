import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';

ButtonStyle outlinedActionStyle(BuildContext context) {
  final colors = CardoColors.of(context);
  final sizes = CardoSizes.of(context);
  final spacing = CardoSpacing.of(context);
  return OutlinedButton.styleFrom(
    minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
    padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
    side: BorderSide(color: colors.lineStrong, width: sizes.hairline),
    foregroundColor: colors.textPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CardoRadii.of(context).buttonSmall),
    ),
    textStyle: CardoTypography.of(context).buttonSmall,
  );
}

class CopyTextButton extends StatefulWidget {
  const CopyTextButton({super.key, required this.text, required this.label});

  final String text;
  final String label;

  @override
  State<CopyTextButton> createState() => _CopyTextButtonState();
}

class _CopyTextButtonState extends State<CopyTextButton> {
  bool _copied = false;

  void _copy() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.text)));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final sizes = CardoSizes.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: OutlinedButton.icon(
        onPressed: _copy,
        style: outlinedActionStyle(context),
        icon: Icon(
          _copied ? LucideIcons.check : LucideIcons.copy,
          size: sizes.iconCompact,
        ),
        label: Text(_copied ? l10n.rejectedCopied : widget.label),
      ),
    );
  }
}
