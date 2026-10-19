import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoSizes extends ThemeExtension<CardoSizes> {
  const CardoSizes({
    required this.tapTarget,
    required this.pillHeight,
    required this.badgeHeight,
    required this.buttonHeight,
    required this.buttonHeightCompact,
    required this.snackbarActionHeight,
    required this.iconFooter,
    required this.iconFooterDense,
    required this.iconPill,
    required this.iconCompact,
    required this.iconBadge,
    required this.iconButton,
    required this.iconSnackbar,
    required this.statusDot,
    required this.statusDotCompact,
    required this.ringStroke,
    required this.markerColumn,
    required this.markerTab,
    required this.avatarFooter,
    required this.avatarFooterDense,
    required this.avatarPresence,
    required this.avatarPresenceLarge,
    required this.avatarProfile,
    required this.avatarRing,
    required this.avatarRingLarge,
    required this.avatarOverlap,
    required this.avatarOverlapLarge,
    required this.hairline,
    required this.pendingBorder,
    required this.emphasisBorder,
    required this.dashLength,
    required this.dashGap,
    required this.logoMark,
    required this.logoMarkLarge,
    required this.logoGap,
    required this.logoGapLarge,
    required this.dropPlaceholder,
    required this.dropPlaceholderDense,
    required this.sheetHandleWidth,
    required this.sheetHandleHeight,
    required this.previewMaxWidth,
  });

  static const CardoSizes standard = CardoSizes(
    tapTarget: 44,
    pillHeight: 32,
    badgeHeight: 28,
    buttonHeight: 48,
    buttonHeightCompact: 40,
    snackbarActionHeight: 36,
    iconFooter: 14,
    iconFooterDense: 13,
    iconPill: 14,
    iconCompact: 12,
    iconBadge: 13,
    iconButton: 18,
    iconSnackbar: 20,
    statusDot: 8,
    statusDotCompact: 7,
    ringStroke: 2,
    markerColumn: 10,
    markerTab: 8,
    avatarFooter: 22,
    avatarFooterDense: 20,
    avatarPresence: 30,
    avatarPresenceLarge: 36,
    avatarProfile: 32,
    avatarRing: 2,
    avatarRingLarge: 3,
    avatarOverlap: 9,
    avatarOverlapLarge: 10,
    hairline: 1,
    pendingBorder: 1.5,
    emphasisBorder: 2,
    dashLength: 6,
    dashGap: 4,
    logoMark: 26,
    logoMarkLarge: 44,
    logoGap: 9,
    logoGapLarge: 12,
    dropPlaceholder: 64,
    dropPlaceholderDense: 52,
    sheetHandleWidth: 40,
    sheetHandleHeight: 5,
    previewMaxWidth: 720,
  );

  final double tapTarget;
  final double pillHeight;
  final double badgeHeight;
  final double buttonHeight;
  final double buttonHeightCompact;
  final double snackbarActionHeight;
  final double iconFooter;
  final double iconFooterDense;
  final double iconPill;
  final double iconCompact;
  final double iconBadge;
  final double iconButton;
  final double iconSnackbar;
  final double statusDot;
  final double statusDotCompact;
  final double ringStroke;
  final double markerColumn;
  final double markerTab;
  final double avatarFooter;
  final double avatarFooterDense;
  final double avatarPresence;
  final double avatarPresenceLarge;
  final double avatarProfile;
  final double avatarRing;
  final double avatarRingLarge;
  final double avatarOverlap;
  final double avatarOverlapLarge;
  final double hairline;
  final double pendingBorder;
  final double emphasisBorder;
  final double dashLength;
  final double dashGap;
  final double logoMark;
  final double logoMarkLarge;
  final double logoGap;
  final double logoGapLarge;
  final double dropPlaceholder;
  final double dropPlaceholderDense;
  final double sheetHandleWidth;
  final double sheetHandleHeight;
  final double previewMaxWidth;

  static CardoSizes of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoSizes>();
    assert(
      extension != null,
      'CardoSizes missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  double iconFooterFor({required bool dense}) =>
      dense ? iconFooterDense : iconFooter;

  double avatarFooterFor({required bool dense}) =>
      dense ? avatarFooterDense : avatarFooter;

  double dropPlaceholderFor({required bool dense}) =>
      dense ? dropPlaceholderDense : dropPlaceholder;

  @override
  CardoSizes copyWith({
    double? tapTarget,
    double? pillHeight,
    double? badgeHeight,
    double? buttonHeight,
    double? buttonHeightCompact,
    double? snackbarActionHeight,
    double? iconFooter,
    double? iconFooterDense,
    double? iconPill,
    double? iconCompact,
    double? iconBadge,
    double? iconButton,
    double? iconSnackbar,
    double? statusDot,
    double? statusDotCompact,
    double? ringStroke,
    double? markerColumn,
    double? markerTab,
    double? avatarFooter,
    double? avatarFooterDense,
    double? avatarPresence,
    double? avatarPresenceLarge,
    double? avatarProfile,
    double? avatarRing,
    double? avatarRingLarge,
    double? avatarOverlap,
    double? avatarOverlapLarge,
    double? hairline,
    double? pendingBorder,
    double? emphasisBorder,
    double? dashLength,
    double? dashGap,
    double? logoMark,
    double? logoMarkLarge,
    double? logoGap,
    double? logoGapLarge,
    double? dropPlaceholder,
    double? dropPlaceholderDense,
    double? sheetHandleWidth,
    double? sheetHandleHeight,
    double? previewMaxWidth,
  }) {
    return CardoSizes(
      tapTarget: tapTarget ?? this.tapTarget,
      pillHeight: pillHeight ?? this.pillHeight,
      badgeHeight: badgeHeight ?? this.badgeHeight,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      buttonHeightCompact: buttonHeightCompact ?? this.buttonHeightCompact,
      snackbarActionHeight: snackbarActionHeight ?? this.snackbarActionHeight,
      iconFooter: iconFooter ?? this.iconFooter,
      iconFooterDense: iconFooterDense ?? this.iconFooterDense,
      iconPill: iconPill ?? this.iconPill,
      iconCompact: iconCompact ?? this.iconCompact,
      iconBadge: iconBadge ?? this.iconBadge,
      iconButton: iconButton ?? this.iconButton,
      iconSnackbar: iconSnackbar ?? this.iconSnackbar,
      statusDot: statusDot ?? this.statusDot,
      statusDotCompact: statusDotCompact ?? this.statusDotCompact,
      ringStroke: ringStroke ?? this.ringStroke,
      markerColumn: markerColumn ?? this.markerColumn,
      markerTab: markerTab ?? this.markerTab,
      avatarFooter: avatarFooter ?? this.avatarFooter,
      avatarFooterDense: avatarFooterDense ?? this.avatarFooterDense,
      avatarPresence: avatarPresence ?? this.avatarPresence,
      avatarPresenceLarge: avatarPresenceLarge ?? this.avatarPresenceLarge,
      avatarProfile: avatarProfile ?? this.avatarProfile,
      avatarRing: avatarRing ?? this.avatarRing,
      avatarRingLarge: avatarRingLarge ?? this.avatarRingLarge,
      avatarOverlap: avatarOverlap ?? this.avatarOverlap,
      avatarOverlapLarge: avatarOverlapLarge ?? this.avatarOverlapLarge,
      hairline: hairline ?? this.hairline,
      pendingBorder: pendingBorder ?? this.pendingBorder,
      emphasisBorder: emphasisBorder ?? this.emphasisBorder,
      dashLength: dashLength ?? this.dashLength,
      dashGap: dashGap ?? this.dashGap,
      logoMark: logoMark ?? this.logoMark,
      logoMarkLarge: logoMarkLarge ?? this.logoMarkLarge,
      logoGap: logoGap ?? this.logoGap,
      logoGapLarge: logoGapLarge ?? this.logoGapLarge,
      dropPlaceholder: dropPlaceholder ?? this.dropPlaceholder,
      dropPlaceholderDense: dropPlaceholderDense ?? this.dropPlaceholderDense,
      sheetHandleWidth: sheetHandleWidth ?? this.sheetHandleWidth,
      sheetHandleHeight: sheetHandleHeight ?? this.sheetHandleHeight,
      previewMaxWidth: previewMaxWidth ?? this.previewMaxWidth,
    );
  }

  @override
  CardoSizes lerp(covariant ThemeExtension<CardoSizes>? other, double t) {
    if (other is! CardoSizes) {
      return this;
    }
    double l(double a, double b) => lerpDouble(a, b, t) ?? b;
    return CardoSizes(
      tapTarget: l(tapTarget, other.tapTarget),
      pillHeight: l(pillHeight, other.pillHeight),
      badgeHeight: l(badgeHeight, other.badgeHeight),
      buttonHeight: l(buttonHeight, other.buttonHeight),
      buttonHeightCompact: l(buttonHeightCompact, other.buttonHeightCompact),
      snackbarActionHeight: l(snackbarActionHeight, other.snackbarActionHeight),
      iconFooter: l(iconFooter, other.iconFooter),
      iconFooterDense: l(iconFooterDense, other.iconFooterDense),
      iconPill: l(iconPill, other.iconPill),
      iconCompact: l(iconCompact, other.iconCompact),
      iconBadge: l(iconBadge, other.iconBadge),
      iconButton: l(iconButton, other.iconButton),
      iconSnackbar: l(iconSnackbar, other.iconSnackbar),
      statusDot: l(statusDot, other.statusDot),
      statusDotCompact: l(statusDotCompact, other.statusDotCompact),
      ringStroke: l(ringStroke, other.ringStroke),
      markerColumn: l(markerColumn, other.markerColumn),
      markerTab: l(markerTab, other.markerTab),
      avatarFooter: l(avatarFooter, other.avatarFooter),
      avatarFooterDense: l(avatarFooterDense, other.avatarFooterDense),
      avatarPresence: l(avatarPresence, other.avatarPresence),
      avatarPresenceLarge: l(avatarPresenceLarge, other.avatarPresenceLarge),
      avatarProfile: l(avatarProfile, other.avatarProfile),
      avatarRing: l(avatarRing, other.avatarRing),
      avatarRingLarge: l(avatarRingLarge, other.avatarRingLarge),
      avatarOverlap: l(avatarOverlap, other.avatarOverlap),
      avatarOverlapLarge: l(avatarOverlapLarge, other.avatarOverlapLarge),
      hairline: l(hairline, other.hairline),
      pendingBorder: l(pendingBorder, other.pendingBorder),
      emphasisBorder: l(emphasisBorder, other.emphasisBorder),
      dashLength: l(dashLength, other.dashLength),
      dashGap: l(dashGap, other.dashGap),
      logoMark: l(logoMark, other.logoMark),
      logoMarkLarge: l(logoMarkLarge, other.logoMarkLarge),
      logoGap: l(logoGap, other.logoGap),
      logoGapLarge: l(logoGapLarge, other.logoGapLarge),
      dropPlaceholder: l(dropPlaceholder, other.dropPlaceholder),
      dropPlaceholderDense: l(dropPlaceholderDense, other.dropPlaceholderDense),
      sheetHandleWidth: l(sheetHandleWidth, other.sheetHandleWidth),
      sheetHandleHeight: l(sheetHandleHeight, other.sheetHandleHeight),
      previewMaxWidth: l(previewMaxWidth, other.previewMaxWidth),
    );
  }
}
