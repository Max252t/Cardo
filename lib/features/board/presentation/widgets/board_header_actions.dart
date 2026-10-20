import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/board_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import 'board_snackbar.dart';

class MembersButton extends StatelessWidget {
  const MembersButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final typography = CardoTypography.of(context);
    final layout = CardoLayout.of(context);
    return OutlinedButton.icon(
      onPressed: () => showComingSoon(context),
      icon: Icon(LucideIcons.userPlus, size: layout.iconDense),
      label: Text(AppLocalizations.of(context).boardMembers),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.buttonPaddingHorizontalCompact,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.buttonCompact),
        ),
        textStyle: typography.buttonCompact,
      ),
    );
  }
}

class InviteButton extends StatelessWidget {
  const InviteButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final typography = CardoTypography.of(context);
    return FilledButton(
      onPressed: () => showComingSoon(context),
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
        padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.buttonCompact),
        ),
        textStyle: typography.buttonCompact,
      ),
      child: Text(AppLocalizations.of(context).boardInvite),
    );
  }
}

class ViewerBanner extends ConsumerWidget {
  const ViewerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(
      boardViewProvider.select(
        (board) => board.members
            .where((member) => member.role == BoardRole.owner)
            .firstOrNull
            ?.name,
      ),
    );
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: layout.bannerPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: colors.roleViewerBackground,
        borderRadius: BorderRadius.circular(layout.bannerRadius),
      ),
      child: Row(
        spacing: layout.columnPaddingHorizontal,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              LucideIcons.eye,
              size: sizes.iconButton,
              color: colors.roleViewerText,
            ),
          ),
          Expanded(
            child: Text(
              owner == null
                  ? l10n.boardViewerBannerNoOwner
                  : l10n.boardViewerBanner(owner),
              style: typography.captionLarge.copyWith(
                color: colors.roleViewerText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
