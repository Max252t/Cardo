import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

class ConflictBanner extends StatelessWidget {
  const ConflictBanner({
    super.key,
    required this.title,
    required this.text,
    required this.onOverwrite,
    required this.onCancel,
    this.waitingText,
  });

  final String title;
  final String text;
  final VoidCallback onOverwrite;
  final VoidCallback onCancel;
  final String? waitingText;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final waiting = waitingText;
    return Semantics(
      container: true,
      liveRegion: true,
      label: waiting == null ? '$title. $text' : '$title. $text. $waiting',
      child: Container(
        padding: EdgeInsetsDirectional.all(spacing.cardPadding),
        decoration: BoxDecoration(
          color: colors.conflictBackground,
          borderRadius: BorderRadius.circular(CardoRadii.of(context).editor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.md,
          children: <Widget>[
            ExcludeSemantics(
              child: _BannerMessage(
                title: title,
                text: text,
                waitingText: waiting,
              ),
            ),
            _BannerActions(
              onOverwrite: waiting == null ? onOverwrite : null,
              onCancel: waiting == null ? onCancel : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerMessage extends StatelessWidget {
  const _BannerMessage({
    required this.title,
    required this.text,
    this.waitingText,
  });

  final String title;
  final String text;
  final String? waitingText;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.cardGap,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(top: spacing.xxs),
          child: Icon(
            LucideIcons.triangleAlert,
            size: CardoSizes.of(context).iconLarge,
            color: colors.conflictIcon,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.bannerTextGap,
            children: <Widget>[
              Text(
                title,
                style: typography.buttonCompact.copyWith(
                  color: colors.conflictTitle,
                ),
              ),
              Text(
                text,
                style: typography.bannerText.copyWith(
                  color: colors.conflictText,
                ),
              ),
              if (waitingText != null)
                Text(
                  waitingText!,
                  style: typography.bannerText.copyWith(
                    color: colors.conflictText,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerActions extends StatelessWidget {
  const _BannerActions({required this.onOverwrite, required this.onCancel});

  final VoidCallback? onOverwrite;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CardoRadii.of(context).iconButton),
    );
    final minimum = Size(sizes.tapTarget, sizes.tapTarget);
    final overwrite = FilledButton(
      onPressed: onOverwrite,
      style: FilledButton.styleFrom(
        minimumSize: minimum,
        shape: shape,
        textStyle: typography.buttonCompact,
      ),
      child: Text(l10n.cardConflictOverwrite, textAlign: TextAlign.center),
    );
    final cancel = OutlinedButton(
      onPressed: onCancel,
      style: OutlinedButton.styleFrom(
        minimumSize: minimum,
        shape: shape,
        side: BorderSide(color: colors.conflictBorder, width: sizes.hairline),
        foregroundColor: colors.conflictTitle,
        textStyle: typography.buttonCompact,
      ),
      child: Text(l10n.cardConflictCancel, textAlign: TextAlign.center),
    );
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >=
        CardoLayout.of(context).stackActionsTextScale;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: <Widget>[overwrite, cancel],
      );
    }
    return Row(
      spacing: spacing.sm,
      children: <Widget>[
        Expanded(child: overwrite),
        Expanded(child: cancel),
      ],
    );
  }
}
