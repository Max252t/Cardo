import 'package:flutter/material.dart';

import '../../../../theme/cardo_theme.dart';
import '../board_view_data.dart';
import 'card_editor_style.dart';
import 'column_marker.dart';

class CardColumnChip extends StatelessWidget {
  const CardColumnChip({super.key, required this.column, required this.style});

  final ColumnInfo column;
  final CardEditorStyle style;

  @override
  Widget build(BuildContext context) {
    final radii = CardoRadii.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: style.chipMinHeight),
      padding: style.chipPadding,
      decoration: BoxDecoration(
        color: style.chipColor,
        borderRadius: BorderRadius.circular(style.chipRadius),
        border: style.chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CardoSpacing.of(context).sm,
        children: <Widget>[
          ColumnMarkerSquare(
            marker: column.marker,
            size: style.chipMarkerSize,
            radius: radii.markerTab,
          ),
          Flexible(child: Text(column.title, style: style.chipText)),
        ],
      ),
    );
  }
}

class CardIconButton extends StatelessWidget {
  const CardIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.style,
    required this.onPressed,
    this.background,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color? background;
  final CardEditorStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final size = style.buttonSize;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: size,
        minimumSize: size,
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
      iconSize: style.buttonIconSize,
      icon: Icon(icon),
    );
  }
}
