import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/cardo_theme.dart';

enum FormMessageTone { error, info }

class FormMessage extends StatelessWidget {
  const FormMessage({
    super.key,
    required this.message,
    this.tone = FormMessageTone.error,
  });

  final String message;
  final FormMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final layout = CardoLayout.of(context);
    final isError = tone == FormMessageTone.error;
    final foreground = isError ? colors.nackText : colors.textSoft;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.md,
          vertical: layout.bannerPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: isError ? colors.nackBackground : colors.surface,
          border: Border.all(
            color: isError ? colors.nackBorder : colors.line,
            width: sizes.hairline,
          ),
          borderRadius: BorderRadius.circular(layout.bannerRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.md,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                isError ? LucideIcons.circleAlert : LucideIcons.info,
                size: layout.iconDense,
                color: foreground,
              ),
            ),
            Expanded(
              child: Text(
                message,
                style: typography.message.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
