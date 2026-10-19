import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/board_role.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final BoardRole role;

  static String labelFor(AppLocalizations l10n, BoardRole role) {
    return switch (role) {
      BoardRole.owner => l10n.roleOwner,
      BoardRole.editor => l10n.roleEditor,
      BoardRole.viewer => l10n.roleViewer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final label = labelFor(l10n, role);
    final (Color fill, Color foreground, BoxBorder? border) = switch (role) {
      BoardRole.owner => (colors.emphasis, colors.onEmphasis, null),
      BoardRole.editor => (
        colors.card,
        colors.textPrimary,
        Border.all(color: colors.textPrimary, width: sizes.hairline),
      ),
      BoardRole.viewer => (
        colors.roleViewerBackground,
        colors.roleViewerText,
        null,
      ),
    };
    return Semantics(
      label: l10n.roleSemanticLabel(label),
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: sizes.badgeHeight),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.badgePaddingHorizontal,
          ),
          decoration: BoxDecoration(
            color: fill,
            border: border,
            borderRadius: BorderRadius.circular(radii.badge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (role == BoardRole.viewer) ...<Widget>[
                Icon(LucideIcons.eye, size: sizes.iconBadge, color: foreground),
                SizedBox(width: spacing.iconGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: typography.label.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
