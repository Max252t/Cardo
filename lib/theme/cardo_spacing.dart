import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoSpacing extends ThemeExtension<CardoSpacing> {
  const CardoSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.section,
    required this.screen,
    required this.screenDesktop,
    required this.cardPadding,
    required this.cardPaddingDense,
    required this.cardContentGap,
    required this.cardContentGapDense,
    required this.cardGap,
    required this.cardGapDense,
    required this.columnGap,
    required this.columnGapDense,
    required this.iconGap,
    required this.pillPaddingHorizontal,
    required this.pillGap,
    required this.badgePaddingHorizontal,
    required this.tagPaddingHorizontal,
    required this.tagPaddingHorizontalDense,
    required this.tagPaddingVertical,
    required this.tagPaddingVerticalDense,
    required this.tagOffset,
    required this.tagInsetEnd,
    required this.tagInsetEndDense,
    required this.buttonPaddingHorizontal,
    required this.buttonPaddingHorizontalCompact,
    required this.textButtonPaddingHorizontal,
    required this.snackbarPadding,
    required this.snackbarPaddingStart,
    required this.snackbarGap,
  });

  static const CardoSpacing standard = CardoSpacing(
    xxs: 2,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    section: 28,
    screen: 16,
    screenDesktop: 24,
    cardPadding: 14,
    cardPaddingDense: 12,
    cardContentGap: 12,
    cardContentGapDense: 10,
    cardGap: 10,
    cardGapDense: 8,
    columnGap: 12,
    columnGapDense: 14,
    iconGap: 6,
    pillPaddingHorizontal: 12,
    pillGap: 8,
    badgePaddingHorizontal: 10,
    tagPaddingHorizontal: 8,
    tagPaddingHorizontalDense: 7,
    tagPaddingVertical: 2,
    tagPaddingVerticalDense: 1,
    tagOffset: 10,
    tagInsetEnd: 12,
    tagInsetEndDense: 10,
    buttonPaddingHorizontal: 22,
    buttonPaddingHorizontalCompact: 14,
    textButtonPaddingHorizontal: 16,
    snackbarPadding: 14,
    snackbarPaddingStart: 18,
    snackbarGap: 12,
  );

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double section;
  final double screen;
  final double screenDesktop;
  final double cardPadding;
  final double cardPaddingDense;
  final double cardContentGap;
  final double cardContentGapDense;
  final double cardGap;
  final double cardGapDense;
  final double columnGap;
  final double columnGapDense;
  final double iconGap;
  final double pillPaddingHorizontal;
  final double pillGap;
  final double badgePaddingHorizontal;
  final double tagPaddingHorizontal;
  final double tagPaddingHorizontalDense;
  final double tagPaddingVertical;
  final double tagPaddingVerticalDense;
  final double tagOffset;
  final double tagInsetEnd;
  final double tagInsetEndDense;
  final double buttonPaddingHorizontal;
  final double buttonPaddingHorizontalCompact;
  final double textButtonPaddingHorizontal;
  final double snackbarPadding;
  final double snackbarPaddingStart;
  final double snackbarGap;

  static CardoSpacing of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoSpacing>();
    assert(
      extension != null,
      'CardoSpacing missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  double cardPaddingFor({required bool dense}) =>
      dense ? cardPaddingDense : cardPadding;

  double cardContentGapFor({required bool dense}) =>
      dense ? cardContentGapDense : cardContentGap;

  double cardGapFor({required bool dense}) => dense ? cardGapDense : cardGap;

  @override
  CardoSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? section,
    double? screen,
    double? screenDesktop,
    double? cardPadding,
    double? cardPaddingDense,
    double? cardContentGap,
    double? cardContentGapDense,
    double? cardGap,
    double? cardGapDense,
    double? columnGap,
    double? columnGapDense,
    double? iconGap,
    double? pillPaddingHorizontal,
    double? pillGap,
    double? badgePaddingHorizontal,
    double? tagPaddingHorizontal,
    double? tagPaddingHorizontalDense,
    double? tagPaddingVertical,
    double? tagPaddingVerticalDense,
    double? tagOffset,
    double? tagInsetEnd,
    double? tagInsetEndDense,
    double? buttonPaddingHorizontal,
    double? buttonPaddingHorizontalCompact,
    double? textButtonPaddingHorizontal,
    double? snackbarPadding,
    double? snackbarPaddingStart,
    double? snackbarGap,
  }) {
    return CardoSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      section: section ?? this.section,
      screen: screen ?? this.screen,
      screenDesktop: screenDesktop ?? this.screenDesktop,
      cardPadding: cardPadding ?? this.cardPadding,
      cardPaddingDense: cardPaddingDense ?? this.cardPaddingDense,
      cardContentGap: cardContentGap ?? this.cardContentGap,
      cardContentGapDense: cardContentGapDense ?? this.cardContentGapDense,
      cardGap: cardGap ?? this.cardGap,
      cardGapDense: cardGapDense ?? this.cardGapDense,
      columnGap: columnGap ?? this.columnGap,
      columnGapDense: columnGapDense ?? this.columnGapDense,
      iconGap: iconGap ?? this.iconGap,
      pillPaddingHorizontal:
          pillPaddingHorizontal ?? this.pillPaddingHorizontal,
      pillGap: pillGap ?? this.pillGap,
      badgePaddingHorizontal:
          badgePaddingHorizontal ?? this.badgePaddingHorizontal,
      tagPaddingHorizontal: tagPaddingHorizontal ?? this.tagPaddingHorizontal,
      tagPaddingHorizontalDense:
          tagPaddingHorizontalDense ?? this.tagPaddingHorizontalDense,
      tagPaddingVertical: tagPaddingVertical ?? this.tagPaddingVertical,
      tagPaddingVerticalDense:
          tagPaddingVerticalDense ?? this.tagPaddingVerticalDense,
      tagOffset: tagOffset ?? this.tagOffset,
      tagInsetEnd: tagInsetEnd ?? this.tagInsetEnd,
      tagInsetEndDense: tagInsetEndDense ?? this.tagInsetEndDense,
      buttonPaddingHorizontal:
          buttonPaddingHorizontal ?? this.buttonPaddingHorizontal,
      buttonPaddingHorizontalCompact:
          buttonPaddingHorizontalCompact ?? this.buttonPaddingHorizontalCompact,
      textButtonPaddingHorizontal:
          textButtonPaddingHorizontal ?? this.textButtonPaddingHorizontal,
      snackbarPadding: snackbarPadding ?? this.snackbarPadding,
      snackbarPaddingStart: snackbarPaddingStart ?? this.snackbarPaddingStart,
      snackbarGap: snackbarGap ?? this.snackbarGap,
    );
  }

  @override
  CardoSpacing lerp(covariant ThemeExtension<CardoSpacing>? other, double t) {
    if (other is! CardoSpacing) {
      return this;
    }
    double l(double a, double b) => lerpDouble(a, b, t) ?? b;
    return CardoSpacing(
      xxs: l(xxs, other.xxs),
      xs: l(xs, other.xs),
      sm: l(sm, other.sm),
      md: l(md, other.md),
      lg: l(lg, other.lg),
      xl: l(xl, other.xl),
      section: l(section, other.section),
      screen: l(screen, other.screen),
      screenDesktop: l(screenDesktop, other.screenDesktop),
      cardPadding: l(cardPadding, other.cardPadding),
      cardPaddingDense: l(cardPaddingDense, other.cardPaddingDense),
      cardContentGap: l(cardContentGap, other.cardContentGap),
      cardContentGapDense: l(cardContentGapDense, other.cardContentGapDense),
      cardGap: l(cardGap, other.cardGap),
      cardGapDense: l(cardGapDense, other.cardGapDense),
      columnGap: l(columnGap, other.columnGap),
      columnGapDense: l(columnGapDense, other.columnGapDense),
      iconGap: l(iconGap, other.iconGap),
      pillPaddingHorizontal: l(
        pillPaddingHorizontal,
        other.pillPaddingHorizontal,
      ),
      pillGap: l(pillGap, other.pillGap),
      badgePaddingHorizontal: l(
        badgePaddingHorizontal,
        other.badgePaddingHorizontal,
      ),
      tagPaddingHorizontal: l(tagPaddingHorizontal, other.tagPaddingHorizontal),
      tagPaddingHorizontalDense: l(
        tagPaddingHorizontalDense,
        other.tagPaddingHorizontalDense,
      ),
      tagPaddingVertical: l(tagPaddingVertical, other.tagPaddingVertical),
      tagPaddingVerticalDense: l(
        tagPaddingVerticalDense,
        other.tagPaddingVerticalDense,
      ),
      tagOffset: l(tagOffset, other.tagOffset),
      tagInsetEnd: l(tagInsetEnd, other.tagInsetEnd),
      tagInsetEndDense: l(tagInsetEndDense, other.tagInsetEndDense),
      buttonPaddingHorizontal: l(
        buttonPaddingHorizontal,
        other.buttonPaddingHorizontal,
      ),
      buttonPaddingHorizontalCompact: l(
        buttonPaddingHorizontalCompact,
        other.buttonPaddingHorizontalCompact,
      ),
      textButtonPaddingHorizontal: l(
        textButtonPaddingHorizontal,
        other.textButtonPaddingHorizontal,
      ),
      snackbarPadding: l(snackbarPadding, other.snackbarPadding),
      snackbarPaddingStart: l(snackbarPaddingStart, other.snackbarPaddingStart),
      snackbarGap: l(snackbarGap, other.snackbarGap),
    );
  }
}
