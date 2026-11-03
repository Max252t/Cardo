import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_view_data.dart';
import 'column_menu_sheet.dart';
import 'column_marker.dart';

class BoardColumnHeader extends StatelessWidget {
  const BoardColumnHeader({
    super.key,
    required this.column,
    required this.count,
    required this.dense,
    this.canEdit = false,
  });

  final ColumnInfo column;
  final int count;
  final bool dense;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final inset = dense
        ? layout.columnHeaderInsetDense
        : layout.columnHeaderInset;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: inset,
        end: canEdit ? 0 : inset,
        top: spacing.xxs,
        bottom: dense
            ? layout.columnHeaderBottomDense
            : layout.columnHeaderBottom,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              label: l10n.boardTabSemantic(column.title, count),
              child: ExcludeSemantics(
                child: Row(
                  children: <Widget>[
                    ColumnMarkerSquare(
                      marker: column.marker,
                      size: dense
                          ? layout.markerColumnDense
                          : sizes.markerColumn,
                      radius: dense ? radii.markerTab : radii.markerColumn,
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        column.title,
                        style: typography
                            .columnTitleFor(dense: dense)
                            .copyWith(color: colors.textPrimary),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Text(
                      '$count',
                      style: typography.mono.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (canEdit) ColumnMenuButton(column: column),
        ],
      ),
    );
  }
}

class ColumnMenuButton extends StatelessWidget {
  const ColumnMenuButton({super.key, required this.column});

  final ColumnInfo column;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final tokens = CardoColumnTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.columnMenuSemantic(column.title),
      child: ExcludeSemantics(
        child: Tooltip(
          message: l10n.columnMenu,
          child: InkWell(
            onTap: () => unawaited(showColumnMenu(context, column.id)),
            borderRadius: BorderRadius.circular(radii.buttonSmall),
            child: SizedBox.square(
              dimension: sizes.tapTarget,
              child: Icon(
                LucideIcons.ellipsis,
                size: tokens.menuIcon,
                color: colors.textSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddCardButton extends StatelessWidget {
  const AddCardButton({
    super.key,
    required this.columnId,
    required this.dense,
    required this.onPressed,
    this.prominent = false,
  });

  final String columnId;
  final bool dense;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        LucideIcons.plus,
        size: dense ? layout.iconDense : sizes.iconButton,
      ),
      label: Text(l10n.boardAddCard),
      style: TextButton.styleFrom(
        foregroundColor: prominent ? colors.onEmphasis : colors.textSoft,
        backgroundColor: prominent ? colors.emphasis : null,
        minimumSize: Size(
          sizes.tapTarget,
          dense && !prominent ? sizes.tapTarget : layout.addCardHeight,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: prominent
              ? spacing.lg + spacing.xxs
              : dense
              ? spacing.iconGap
              : spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            prominent
                ? radii.button
                : dense
                ? radii.buttonSmall
                : radii.iconButton,
          ),
        ),
        textStyle: prominent
            ? typography.buttonCompact
            : dense
            ? typography.buttonSmall
            : typography.tab,
      ),
    );
  }
}
