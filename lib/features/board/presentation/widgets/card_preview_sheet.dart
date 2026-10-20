import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';

Future<void> showCardPreviewSheet(BuildContext context, CardModel card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CardPreviewSheet(card: card),
  );
}

class CardPreviewSheet extends StatelessWidget {
  const CardPreviewSheet({super.key, required this.card});

  final CardModel card;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(
        start: spacing.xl,
        end: spacing.xl,
        bottom: spacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: spacing.md,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              card.title,
              style: typography.cardTitle.copyWith(color: colors.textPrimary),
            ),
          ),
          Text(
            card.hasDescription
                ? card.description
                : l10n.cardPreviewNoDescription,
            style: typography.paragraph.copyWith(
              color: card.hasDescription
                  ? colors.textPrimary
                  : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
