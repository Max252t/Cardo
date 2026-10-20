import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoRadii extends ThemeExtension<CardoRadii> {
  const CardoRadii({
    required this.card,
    required this.cardDense,
    required this.column,
    required this.columnDense,
    required this.field,
    required this.button,
    required this.buttonCompact,
    required this.buttonSmall,
    required this.iconButton,
    required this.snackbar,
    required this.badge,
    required this.tag,
    required this.sheet,
    required this.pill,
    required this.markerColumn,
    required this.markerTab,
  });

  static const CardoRadii standard = CardoRadii(
    card: 14,
    cardDense: 12,
    column: 20,
    columnDense: 18,
    field: 14,
    button: 14,
    buttonCompact: 11,
    buttonSmall: 10,
    iconButton: 12,
    snackbar: 16,
    badge: 8,
    tag: 6,
    sheet: 28,
    pill: 999,
    markerColumn: 3,
    markerTab: 2,
  );

  final double card;
  final double cardDense;
  final double column;
  final double columnDense;
  final double field;
  final double button;
  final double buttonCompact;
  final double buttonSmall;
  final double iconButton;
  final double snackbar;
  final double badge;
  final double tag;
  final double sheet;
  final double pill;
  final double markerColumn;
  final double markerTab;

  static CardoRadii of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoRadii>();
    assert(
      extension != null,
      'CardoRadii missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  double cardFor({required bool dense}) => dense ? cardDense : card;

  double columnFor({required bool dense}) => dense ? columnDense : column;

  @override
  CardoRadii copyWith({
    double? card,
    double? cardDense,
    double? column,
    double? columnDense,
    double? field,
    double? button,
    double? buttonCompact,
    double? buttonSmall,
    double? iconButton,
    double? snackbar,
    double? badge,
    double? tag,
    double? sheet,
    double? pill,
    double? markerColumn,
    double? markerTab,
  }) {
    return CardoRadii(
      card: card ?? this.card,
      cardDense: cardDense ?? this.cardDense,
      column: column ?? this.column,
      columnDense: columnDense ?? this.columnDense,
      field: field ?? this.field,
      button: button ?? this.button,
      buttonCompact: buttonCompact ?? this.buttonCompact,
      buttonSmall: buttonSmall ?? this.buttonSmall,
      iconButton: iconButton ?? this.iconButton,
      snackbar: snackbar ?? this.snackbar,
      badge: badge ?? this.badge,
      tag: tag ?? this.tag,
      sheet: sheet ?? this.sheet,
      pill: pill ?? this.pill,
      markerColumn: markerColumn ?? this.markerColumn,
      markerTab: markerTab ?? this.markerTab,
    );
  }

  @override
  CardoRadii lerp(covariant ThemeExtension<CardoRadii>? other, double t) {
    if (other is! CardoRadii) {
      return this;
    }
    double l(double a, double b) => lerpDouble(a, b, t) ?? b;
    return CardoRadii(
      card: l(card, other.card),
      cardDense: l(cardDense, other.cardDense),
      column: l(column, other.column),
      columnDense: l(columnDense, other.columnDense),
      field: l(field, other.field),
      button: l(button, other.button),
      buttonCompact: l(buttonCompact, other.buttonCompact),
      buttonSmall: l(buttonSmall, other.buttonSmall),
      iconButton: l(iconButton, other.iconButton),
      snackbar: l(snackbar, other.snackbar),
      badge: l(badge, other.badge),
      tag: l(tag, other.tag),
      sheet: l(sheet, other.sheet),
      pill: l(pill, other.pill),
      markerColumn: l(markerColumn, other.markerColumn),
      markerTab: l(markerTab, other.markerTab),
    );
  }
}
