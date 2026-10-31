import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../theme/cardo_theme.dart';
import '../../../board/presentation/card_age_text.dart';
import '../../domain/board_info.dart';

class BoardTile extends StatelessWidget {
  const BoardTile({
    super.key,
    required this.board,
    required this.now,
    required this.onTap,
  });

  final BoardInfo board;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final radius = BorderRadius.circular(radii.columnDense);
    final role = RoleBadge.labelFor(l10n, board.role);
    final updated = l10n.boardUpdatedAt(
      cardAgeText(l10n, board.updatedAt, now),
    );
    return Semantics(
      button: true,
      label: l10n.boardSemantic(board.title, role),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.line, width: sizes.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsetsDirectional.all(spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.md,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.md,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          board.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth / 2,
                        ),
                        child: RoleBadge(role: board.role),
                      ),
                    ],
                  ),
                ),
                Text(
                  updated,
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
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
