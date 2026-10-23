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
  });

  factory CardEditorStyle.of(BuildContext context, CardEditorVariant variant) {
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    return switch (variant) {
      CardEditorVariant.sheet => CardEditorStyle(
        title: typography.sheetTitle,
        field: typography.sheetField,
        fieldRadius: radii.editor,
        avatarDiameter: sizes.avatarMeta,
        fillField: true,
        uppercaseLabel: false,
      ),
      CardEditorVariant.panel => CardEditorStyle(
        title: typography.cardTitle,
        field: typography.panelField,
        fieldRadius: radii.field,
        avatarDiameter: sizes.avatarFooter,
        fillField: false,
        uppercaseLabel: true,
      ),
    };
  }

  final TextStyle title;
  final TextStyle field;
  final double fieldRadius;
  final double avatarDiameter;
  final bool fillField;
  final bool uppercaseLabel;
}
