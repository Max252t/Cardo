import 'package:flutter/material.dart';

import '../../../../theme/cardo_theme.dart';

enum CardEditorVariant { sheet, panel }

@immutable
class CardEditorStyle {
  const CardEditorStyle({
    required this.title,
    required this.field,
    required this.fieldRadius,
    required this.avatarDiameter,
    required this.fillField,
    required this.uppercaseLabel,
    required this.chipColor,
    required this.chipRadius,
    required this.chipMinHeight,
    required this.chipPadding,
    required this.chipMarkerSize,
    required this.chipText,
    required this.buttonRadius,
    required this.buttonIconSize,
    required this.quietForeground,
    required this.closeBackground,
    this.chipBorder,
    this.buttonSize,
  });

  factory CardEditorStyle.of(BuildContext context, CardEditorVariant variant) {
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return switch (variant) {
      CardEditorVariant.sheet => CardEditorStyle(
        title: typography.sheetTitle,
        field: typography.sheetField,
        fieldRadius: radii.editor,
        avatarDiameter: sizes.avatarMeta,
        fillField: true,
        uppercaseLabel: false,
        chipColor: colors.background,
        chipRadius: radii.chip,
        chipMinHeight: layout.sheetChipHeight,
        chipPadding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.badgePaddingHorizontal,
        ),
        chipMarkerSize: layout.markerColumnDense,
        chipText: typography.pill.copyWith(color: colors.textPrimary),
        buttonRadius: radii.iconButton,
        buttonIconSize: sizes.iconLarge,
        buttonSize: Size.square(sizes.tapTarget),
        quietForeground: colors.textSoft,
        closeBackground: colors.background,
      ),
      CardEditorVariant.panel => CardEditorStyle(
        title: typography.cardTitle,
        field: typography.panelField,
        fieldRadius: radii.field,
        avatarDiameter: sizes.avatarFooter,
        fillField: false,
        uppercaseLabel: true,
        chipColor: colors.card,
        chipRadius: radii.badge,
        chipMinHeight: layout.panelChipHeight,
        chipPadding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.cardGap,
          vertical: spacing.xxs,
        ),
        chipMarkerSize: sizes.markerTab,
        chipText: typography.caption.copyWith(color: colors.textPrimary),
        chipBorder: Border.all(color: colors.cardBorder, width: sizes.hairline),
        buttonRadius: radii.buttonSmall,
        buttonIconSize: sizes.iconButton,
        quietForeground: colors.textSecondary,
        closeBackground: colors.card,
      ),
    };
  }

  final TextStyle title;
  final TextStyle field;
  final double fieldRadius;
  final double avatarDiameter;
  final bool fillField;
  final bool uppercaseLabel;
  final Color chipColor;
  final double chipRadius;
  final double chipMinHeight;
  final EdgeInsetsGeometry chipPadding;
  final double chipMarkerSize;
  final TextStyle chipText;
  final Border? chipBorder;
  final double buttonRadius;
  final double buttonIconSize;
  final Size? buttonSize;
  final Color quietForeground;
  final Color closeBackground;
}
