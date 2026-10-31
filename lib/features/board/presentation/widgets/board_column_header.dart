import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_view_data.dart';
import '../board_providers.dart';
import 'add_card_dialog.dart';
import 'column_marker.dart';

class BoardColumnHeader extends StatelessWidget {
  const BoardColumnHeader({
    super.key,
    required this.column,
    required this.count,
    required this.dense,
  });

  final ColumnInfo column;
  final int count;
  final bool dense;

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
    return Semantics(
      header: true,
      label: l10n.boardTabSemantic(column.title, count),
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: inset,
            end: inset,
            top: spacing.xxs,
            bottom: dense
                ? layout.columnHeaderBottomDense
                : layout.columnHeaderBottom,
          ),
          child: Row(
            children: <Widget>[
              ColumnMarkerSquare(
                marker: column.marker,
                size: dense ? layout.markerColumnDense : sizes.markerColumn,
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
                style: typography.mono.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddCardButton extends ConsumerWidget {
  const AddCardButton({super.key, required this.columnId, required this.dense});

  final String columnId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: () => unawaited(_add(context, ref)),
      icon: Icon(
        LucideIcons.plus,
        size: dense ? layout.iconDense : sizes.iconButton,
      ),
      label: Text(l10n.boardAddCard),
      style: TextButton.styleFrom(
        foregroundColor: colors.textSoft,
        minimumSize: Size(
          sizes.tapTarget,
          dense ? sizes.tapTarget : layout.addCardHeight,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: dense ? spacing.iconGap : spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            dense ? radii.buttonSmall : radii.iconButton,
          ),
        ),
        textStyle: dense ? typography.buttonSmall : typography.tab,
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(boardNotifierProvider.notifier);
    final title = await showAddCardDialog(context);
    if (title != null) {
      notifier.createCard(columnId: columnId, title: title);
    }
  }
}
