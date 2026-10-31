import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../card_sheet_data.dart';
import 'board_snackbar.dart';

class CardNackStrip extends ConsumerWidget {
  const CardNackStrip({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nack = ref.watch(cardNackProvider(cardId));
    if (nack == null) {
      return const SizedBox.shrink();
    }
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final message = nackMessage(
      AppLocalizations.of(context),
      nack.rejection,
      actorName: nack.actorName,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.md,
            vertical: layout.bannerPaddingVertical,
          ),
          decoration: BoxDecoration(
            color: colors.nackBackground,
            borderRadius: BorderRadius.circular(layout.bannerRadius),
            border: Border.all(color: colors.nackBorder, width: sizes.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.cardGap,
            children: <Widget>[
              Icon(
                LucideIcons.circleAlert,
                size: sizes.iconCompact,
                color: colors.nackText,
              ),
              Expanded(
                child: Text(
                  message,
                  style: typography.caption.copyWith(color: colors.nackText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
