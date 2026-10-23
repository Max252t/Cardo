import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/avatar_identity.dart';
import '../../../../shared/widgets/cardo_avatar.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../card_age_text.dart';

class CardMetaRow extends ConsumerWidget {
  const CardMetaRow({
    super.key,
    required this.createdBy,
    required this.createdAt,
    required this.version,
    required this.avatarDiameter,
  });

  final AvatarIdentity? createdBy;
  final DateTime createdAt;
  final int version;
  final double avatarDiameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final author = createdBy;
    final when = cardAgeText(l10n, createdAt, ref.watch(nowProvider)());
    return Row(
      spacing: spacing.cardGap,
      children: <Widget>[
        if (author != null)
          CardoAvatar(identity: author, diameter: avatarDiameter),
        Expanded(
          child: Text(
            author == null ? '' : l10n.cardMeta(author.name, when),
            style: typography.captionLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        Text(
          l10n.cardPanelVersion(version),
          style: typography.mono.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
