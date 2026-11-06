import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/board_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/invite_policy.dart';

class RolePickerButton extends StatelessWidget {
  const RolePickerButton({
    super.key,
    required this.role,
    required this.onSelected,
    required this.semanticLabel,
    this.busy = false,
  });

  final BoardRole role;
  final ValueChanged<BoardRole>? onSelected;
  final String semanticLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final layout = CardoLayout.of(context);
    final enabled = onSelected != null && !busy;
    final foreground = enabled ? colors.textPrimary : colors.textSecondary;
    return PopupMenuButton<BoardRole>(
      enabled: enabled,
      initialValue: role,
      tooltip: semanticLabel,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => <PopupMenuEntry<BoardRole>>[
        for (final option in InvitePolicy.assignableRoles)
          PopupMenuItem<BoardRole>(
            value: option,
            child: Text(RoleBadge.labelFor(l10n, option)),
          ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: sizes.tapTarget,
          minWidth: sizes.tapTarget,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.lineStrong, width: sizes.hairline),
            borderRadius: BorderRadius.circular(radii.buttonSmall),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: spacing.md,
              end: spacing.sm,
              top: spacing.xs,
              bottom: spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.xs,
              children: <Widget>[
                Flexible(
                  child: Text(
                    RoleBadge.labelFor(l10n, role),
                    style: typography.buttonSmall.copyWith(color: foreground),
                  ),
                ),
                if (busy)
                  const BusyIndicator()
                else
                  ExcludeSemantics(
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: layout.iconDense,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
