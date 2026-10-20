import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_view_data.dart';
import 'column_marker.dart';

class ColumnTabs extends StatelessWidget {
  const ColumnTabs({
    super.key,
    required this.columns,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ColumnViewData> columns;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.xs),
      child: Row(
        spacing: spacing.sm,
        children: <Widget>[
          for (var i = 0; i < columns.length; i++)
            ColumnTab(
              data: columns[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class ColumnTab extends StatelessWidget {
  const ColumnTab({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final ColumnViewData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(radii.buttonSmall);
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.boardTabSemantic(data.column.title, data.count),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: sizes.tapTarget),
            child: Center(
              widthFactor: 1,
              child: Container(
                constraints: BoxConstraints(minHeight: layout.tabHeight),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.md,
                ),
                decoration: BoxDecoration(
                  color: selected ? colors.emphasis : colors.surface,
                  borderRadius: radius,
                  border: selected
                      ? null
                      : Border.all(color: colors.line, width: sizes.hairline),
                ),
                child: ColumnTabLabel(data: data, selected: selected),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ColumnTabLabel extends StatelessWidget {
  const ColumnTabLabel({super.key, required this.data, required this.selected});

  final ColumnViewData data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final gap = CardoLayout.of(context).tabMarkerGap;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ColumnMarkerSquare(
          marker: data.column.marker,
          size: sizes.markerTab,
          radius: radii.markerTab,
        ),
        SizedBox(width: gap),
        Text(
          data.column.title,
          style: typography.tab.copyWith(
            color: selected ? colors.onEmphasis : colors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        SizedBox(width: gap),
        Text(
          '${data.count}',
          style: typography.mono.copyWith(
            color: selected ? colors.tabActiveCount : colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
