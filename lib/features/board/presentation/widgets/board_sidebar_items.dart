import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/realtime/connection_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/avatar_identity.dart';
import '../../../../shared/widgets/cardo_avatar.dart';
import '../../../../shared/widgets/connection_pill.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_view_data.dart';
import '../board_providers.dart';
import 'board_snackbar.dart';
import 'column_marker.dart';

class SidebarSearchField extends StatelessWidget {
  const SidebarSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.buttonSmall),
      borderSide: BorderSide.none,
    );
    return TextField(
      style: typography.message.copyWith(color: colors.textPrimary),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.boardSearch,
        hintStyle: typography.message.copyWith(color: colors.textSecondary),
        filled: true,
        fillColor: colors.sidebarField,
        isDense: true,
        constraints: BoxConstraints(minHeight: sizes.tapTarget),
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.cardGap,
          vertical: spacing.md,
        ),
        prefixIcon: Icon(
          LucideIcons.search,
          size: layout.iconDense,
          color: colors.textSecondary,
        ),
        prefixIconConstraints: BoxConstraints(
          minWidth: sizes.tapTarget - spacing.sm,
          minHeight: sizes.tapTarget,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.buttonSmall),
          borderSide: BorderSide(
            color: colors.emphasis,
            width: sizes.emphasisBorder,
          ),
        ),
      ),
    );
  }
}

class SidebarBoardItem extends StatelessWidget {
  const SidebarBoardItem({
    super.key,
    required this.board,
    required this.active,
    required this.connection,
  });

  final BoardListItem board;
  final bool active;
  final ConnectionStatus? connection;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radius = BorderRadius.circular(radii.buttonSmall);
    final status = connection;
    final marker = active
        ? colors.accent
        : colors.avatarSwatch(board.colorHex).accent;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: active ? null : () => showComingSoon(context),
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(minHeight: sizes.tapTarget),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacing.cardGap,
              vertical: spacing.xs,
            ),
            decoration: BoxDecoration(
              color: active ? colors.selectionFill : null,
              borderRadius: radius,
            ),
            child: Row(
              spacing: spacing.cardGap,
              children: <Widget>[
                MarkerSquare(
                  color: marker,
                  size: sizes.markerTab,
                  radius: radii.markerTab,
                ),
                Expanded(
                  child: Text(
                    board.title,
                    style: typography.message.copyWith(
                      color: active ? colors.textPrimary : colors.textSoft,
                      fontWeight: active ? FontWeight.w500 : null,
                    ),
                  ),
                ),
                if (status != null) SidebarConnectionGlyph(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarNewBoardButton extends StatelessWidget {
  const SidebarNewBoardButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return TextButton.icon(
      onPressed: () => showComingSoon(context),
      icon: Icon(LucideIcons.plus, size: layout.iconDense),
      label: Text(AppLocalizations.of(context).boardNewBoard),
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: colors.textSecondary,
        minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
        padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.cardGap),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.buttonSmall),
        ),
        textStyle: typography.tab,
      ),
    );
  }
}

class SidebarProfile extends ConsumerWidget {
  const SidebarProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final user = ref.watch(currentUserProvider);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: layout.sidebarPaddingHorizontal,
        end: layout.sidebarPaddingHorizontal,
        bottom: layout.sidebarPaddingVertical,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: BorderSide(color: colors.line, width: sizes.hairline),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.cardGap,
          ),
          child: Row(
            spacing: spacing.cardGap,
            children: <Widget>[
              CardoAvatar(
                identity: AvatarIdentity(
                  name: user.name,
                  colorHex: user.avatarColor,
                ),
                diameter: sizes.avatarProfile,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      style: typography.pill.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      user.email,
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarConnectionGlyph extends StatelessWidget {
  const SidebarConnectionGlyph({super.key, required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.connectionSemanticLabel(
        ConnectionPill.labelFor(l10n, status, null),
      ),
      child: ConnectionGlyph(
        status: status,
        color: ConnectionPill.swatchFor(
          CardoColors.of(context),
          status,
        ).compactGlyph,
        compact: true,
      ),
    );
  }
}
