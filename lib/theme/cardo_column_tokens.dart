import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoColumnTokens extends ThemeExtension<CardoColumnTokens> {
  const CardoColumnTokens({
    required this.newFieldWidth,
    required this.confirmButton,
    required this.confirmRadius,
    required this.confirmIcon,
    required this.menuIcon,
    required this.menuItemHeight,
    required this.nameFieldHeight,
    required this.dangerRadius,
    required this.dangerIconBox,
    required this.dangerIconRadius,
    required this.emptyWidth,
    required this.emptyHeight,
    required this.ghostLeft,
    required this.ghostTop,
    required this.ghostWidth,
    required this.ghostHeight,
    required this.ghostRadius,
    required this.ghostAngle,
    required this.sampleLeft,
    required this.sampleTop,
    required this.sampleAngle,
    required this.sampleLineHeight,
    required this.sampleLineLong,
    required this.sampleLineShort,
    required this.plusBadge,
    required this.plusIcon,
    required this.emptyPaddingHorizontal,
    required this.emptyBodyLineHeight,
    required this.sampleLineRadius,
  });

  static const CardoColumnTokens standard = CardoColumnTokens(
    newFieldWidth: 200,
    confirmButton: 28,
    confirmRadius: 7,
    confirmIcon: 14,
    menuIcon: 18,
    menuItemHeight: 52,
    nameFieldHeight: 52,
    dangerRadius: 18,
    dangerIconBox: 40,
    dangerIconRadius: 12,
    emptyWidth: 140,
    emptyHeight: 96,
    ghostLeft: 6,
    ghostTop: 18,
    ghostWidth: 110,
    ghostHeight: 66,
    ghostRadius: 12,
    ghostAngle: -0.1222,
    sampleLeft: 26,
    sampleTop: 6,
    sampleAngle: 0.0873,
    sampleLineHeight: 7,
    sampleLineLong: 0.7,
    sampleLineShort: 0.45,
    plusBadge: 30,
    plusIcon: 16,
    emptyPaddingHorizontal: 24,
    emptyBodyLineHeight: 1.45,
    sampleLineRadius: 4,
  );

  final double newFieldWidth;
  final double confirmButton;
  final double confirmRadius;
  final double confirmIcon;
  final double menuIcon;
  final double menuItemHeight;
  final double nameFieldHeight;
  final double dangerRadius;
  final double dangerIconBox;
  final double dangerIconRadius;
  final double emptyWidth;
  final double emptyHeight;
  final double ghostLeft;
  final double ghostTop;
  final double ghostWidth;
  final double ghostHeight;
  final double ghostRadius;
  final double ghostAngle;
  final double sampleLeft;
  final double sampleTop;
  final double sampleAngle;
  final double sampleLineHeight;
  final double sampleLineLong;
  final double sampleLineShort;
  final double plusBadge;
  final double plusIcon;
  final double emptyPaddingHorizontal;
  final double emptyBodyLineHeight;
  final double sampleLineRadius;

  static CardoColumnTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoColumnTokens>();
    assert(
      extension != null,
      'CardoColumnTokens missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  @override
  CardoColumnTokens copyWith({
    double? newFieldWidth,
    double? confirmButton,
    double? confirmRadius,
    double? confirmIcon,
    double? menuIcon,
    double? menuItemHeight,
    double? nameFieldHeight,
    double? dangerRadius,
    double? dangerIconBox,
    double? dangerIconRadius,
    double? emptyWidth,
    double? emptyHeight,
    double? ghostLeft,
    double? ghostTop,
    double? ghostWidth,
    double? ghostHeight,
    double? ghostRadius,
    double? ghostAngle,
    double? sampleLeft,
    double? sampleTop,
    double? sampleAngle,
    double? sampleLineHeight,
    double? sampleLineLong,
    double? sampleLineShort,
    double? plusBadge,
    double? plusIcon,
    double? emptyPaddingHorizontal,
    double? emptyBodyLineHeight,
    double? sampleLineRadius,
  }) {
    return CardoColumnTokens(
      newFieldWidth: newFieldWidth ?? this.newFieldWidth,
      confirmButton: confirmButton ?? this.confirmButton,
      confirmRadius: confirmRadius ?? this.confirmRadius,
      confirmIcon: confirmIcon ?? this.confirmIcon,
      menuIcon: menuIcon ?? this.menuIcon,
      menuItemHeight: menuItemHeight ?? this.menuItemHeight,
      nameFieldHeight: nameFieldHeight ?? this.nameFieldHeight,
      dangerRadius: dangerRadius ?? this.dangerRadius,
      dangerIconBox: dangerIconBox ?? this.dangerIconBox,
      dangerIconRadius: dangerIconRadius ?? this.dangerIconRadius,
      emptyWidth: emptyWidth ?? this.emptyWidth,
      emptyHeight: emptyHeight ?? this.emptyHeight,
      ghostLeft: ghostLeft ?? this.ghostLeft,
      ghostTop: ghostTop ?? this.ghostTop,
      ghostWidth: ghostWidth ?? this.ghostWidth,
      ghostHeight: ghostHeight ?? this.ghostHeight,
      ghostRadius: ghostRadius ?? this.ghostRadius,
      ghostAngle: ghostAngle ?? this.ghostAngle,
      sampleLeft: sampleLeft ?? this.sampleLeft,
      sampleTop: sampleTop ?? this.sampleTop,
      sampleAngle: sampleAngle ?? this.sampleAngle,
      sampleLineHeight: sampleLineHeight ?? this.sampleLineHeight,
      sampleLineLong: sampleLineLong ?? this.sampleLineLong,
      sampleLineShort: sampleLineShort ?? this.sampleLineShort,
      plusBadge: plusBadge ?? this.plusBadge,
      plusIcon: plusIcon ?? this.plusIcon,
      emptyPaddingHorizontal:
          emptyPaddingHorizontal ?? this.emptyPaddingHorizontal,
      emptyBodyLineHeight: emptyBodyLineHeight ?? this.emptyBodyLineHeight,
      sampleLineRadius: sampleLineRadius ?? this.sampleLineRadius,
    );
  }

  @override
  CardoColumnTokens lerp(ThemeExtension<CardoColumnTokens>? other, double t) {
    if (other is! CardoColumnTokens) {
      return this;
    }
    double mix(double a, double b) => lerpDouble(a, b, t)!;
    return CardoColumnTokens(
      newFieldWidth: mix(newFieldWidth, other.newFieldWidth),
      confirmButton: mix(confirmButton, other.confirmButton),
      confirmRadius: mix(confirmRadius, other.confirmRadius),
      confirmIcon: mix(confirmIcon, other.confirmIcon),
      menuIcon: mix(menuIcon, other.menuIcon),
      menuItemHeight: mix(menuItemHeight, other.menuItemHeight),
      nameFieldHeight: mix(nameFieldHeight, other.nameFieldHeight),
      dangerRadius: mix(dangerRadius, other.dangerRadius),
      dangerIconBox: mix(dangerIconBox, other.dangerIconBox),
      dangerIconRadius: mix(dangerIconRadius, other.dangerIconRadius),
      emptyWidth: mix(emptyWidth, other.emptyWidth),
      emptyHeight: mix(emptyHeight, other.emptyHeight),
      ghostLeft: mix(ghostLeft, other.ghostLeft),
      ghostTop: mix(ghostTop, other.ghostTop),
      ghostWidth: mix(ghostWidth, other.ghostWidth),
      ghostHeight: mix(ghostHeight, other.ghostHeight),
      ghostRadius: mix(ghostRadius, other.ghostRadius),
      ghostAngle: mix(ghostAngle, other.ghostAngle),
      sampleLeft: mix(sampleLeft, other.sampleLeft),
      sampleTop: mix(sampleTop, other.sampleTop),
      sampleAngle: mix(sampleAngle, other.sampleAngle),
      sampleLineHeight: mix(sampleLineHeight, other.sampleLineHeight),
      sampleLineLong: mix(sampleLineLong, other.sampleLineLong),
      sampleLineShort: mix(sampleLineShort, other.sampleLineShort),
      plusBadge: mix(plusBadge, other.plusBadge),
      plusIcon: mix(plusIcon, other.plusIcon),
      emptyPaddingHorizontal: mix(
        emptyPaddingHorizontal,
        other.emptyPaddingHorizontal,
      ),
      emptyBodyLineHeight: mix(emptyBodyLineHeight, other.emptyBodyLineHeight),
      sampleLineRadius: mix(sampleLineRadius, other.sampleLineRadius),
    );
  }
}
