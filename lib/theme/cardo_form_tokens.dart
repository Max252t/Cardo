import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoFormTokens extends ThemeExtension<CardoFormTokens> {
  const CardoFormTokens({
    required this.largeButtonHeight,
    required this.swatch,
    required this.swatchLarge,
    required this.swatchRingGap,
    required this.avatarPreview,
    required this.avatarHero,
    required this.formMaxWidth,
    required this.contentMaxWidth,
    required this.gridContentMaxWidth,
    required this.gridTileMaxExtent,
    required this.gridTileHeight,
    required this.heroHeight,
    required this.heroRadius,
    required this.brandPanelRadius,
    required this.brandCardWidth,
    required this.brandCardHeight,
    required this.brandCardTilt,
    required this.illustrationWidth,
    required this.illustrationHeight,
    required this.progressStroke,
    required this.progressSize,
    required this.skeletonLine,
    required this.skeletonCardHeight,
    required this.fabHeight,
    required this.dialogMaxWidth,
    required this.dialogRadius,
  });

  static const CardoFormTokens standard = CardoFormTokens(
    largeButtonHeight: 54,
    swatch: 32,
    swatchLarge: 36,
    swatchRingGap: 3,
    avatarPreview: 56,
    avatarHero: 88,
    formMaxWidth: 400,
    contentMaxWidth: 480,
    gridContentMaxWidth: 1240,
    gridTileMaxExtent: 360,
    gridTileHeight: 148,
    heroHeight: 280,
    heroRadius: 32,
    brandPanelRadius: 28,
    brandCardWidth: 168,
    brandCardHeight: 92,
    brandCardTilt: 0.1,
    illustrationWidth: 220,
    illustrationHeight: 150,
    progressStroke: 2.5,
    progressSize: 22,
    skeletonLine: 12,
    skeletonCardHeight: 86,
    fabHeight: 56,
    dialogMaxWidth: 500,
    dialogRadius: 26,
  );

  final double largeButtonHeight;
  final double swatch;
  final double swatchLarge;
  final double swatchRingGap;
  final double avatarPreview;
  final double avatarHero;
  final double formMaxWidth;
  final double contentMaxWidth;
  final double gridContentMaxWidth;
  final double gridTileMaxExtent;
  final double gridTileHeight;
  final double heroHeight;
  final double heroRadius;
  final double brandPanelRadius;
  final double brandCardWidth;
  final double brandCardHeight;
  final double brandCardTilt;
  final double illustrationWidth;
  final double illustrationHeight;
  final double progressStroke;
  final double progressSize;
  final double skeletonLine;
  final double skeletonCardHeight;
  final double fabHeight;
  final double dialogMaxWidth;
  final double dialogRadius;

  static CardoFormTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoFormTokens>();
    assert(
      extension != null,
      'CardoFormTokens missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  @override
  CardoFormTokens copyWith({
    double? largeButtonHeight,
    double? swatch,
    double? swatchLarge,
    double? swatchRingGap,
    double? avatarPreview,
    double? avatarHero,
    double? formMaxWidth,
    double? contentMaxWidth,
    double? gridContentMaxWidth,
    double? gridTileMaxExtent,
    double? gridTileHeight,
    double? heroHeight,
    double? heroRadius,
    double? brandPanelRadius,
    double? brandCardWidth,
    double? brandCardHeight,
    double? brandCardTilt,
    double? illustrationWidth,
    double? illustrationHeight,
    double? progressStroke,
    double? progressSize,
    double? skeletonLine,
    double? skeletonCardHeight,
    double? fabHeight,
    double? dialogMaxWidth,
    double? dialogRadius,
  }) {
    return CardoFormTokens(
      largeButtonHeight: largeButtonHeight ?? this.largeButtonHeight,
      swatch: swatch ?? this.swatch,
      swatchLarge: swatchLarge ?? this.swatchLarge,
      swatchRingGap: swatchRingGap ?? this.swatchRingGap,
      avatarPreview: avatarPreview ?? this.avatarPreview,
      avatarHero: avatarHero ?? this.avatarHero,
      formMaxWidth: formMaxWidth ?? this.formMaxWidth,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      gridContentMaxWidth: gridContentMaxWidth ?? this.gridContentMaxWidth,
      gridTileMaxExtent: gridTileMaxExtent ?? this.gridTileMaxExtent,
      gridTileHeight: gridTileHeight ?? this.gridTileHeight,
      heroHeight: heroHeight ?? this.heroHeight,
      heroRadius: heroRadius ?? this.heroRadius,
      brandPanelRadius: brandPanelRadius ?? this.brandPanelRadius,
      brandCardWidth: brandCardWidth ?? this.brandCardWidth,
      brandCardHeight: brandCardHeight ?? this.brandCardHeight,
      brandCardTilt: brandCardTilt ?? this.brandCardTilt,
      illustrationWidth: illustrationWidth ?? this.illustrationWidth,
      illustrationHeight: illustrationHeight ?? this.illustrationHeight,
      progressStroke: progressStroke ?? this.progressStroke,
      progressSize: progressSize ?? this.progressSize,
      skeletonLine: skeletonLine ?? this.skeletonLine,
      skeletonCardHeight: skeletonCardHeight ?? this.skeletonCardHeight,
      fabHeight: fabHeight ?? this.fabHeight,
      dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
      dialogRadius: dialogRadius ?? this.dialogRadius,
    );
  }

  @override
  CardoFormTokens lerp(ThemeExtension<CardoFormTokens>? other, double t) {
    if (other is! CardoFormTokens) {
      return this;
    }
    return CardoFormTokens(
      largeButtonHeight: lerpDouble(
        largeButtonHeight,
        other.largeButtonHeight,
        t,
      )!,
      swatch: lerpDouble(swatch, other.swatch, t)!,
      swatchLarge: lerpDouble(swatchLarge, other.swatchLarge, t)!,
      swatchRingGap: lerpDouble(swatchRingGap, other.swatchRingGap, t)!,
      avatarPreview: lerpDouble(avatarPreview, other.avatarPreview, t)!,
      avatarHero: lerpDouble(avatarHero, other.avatarHero, t)!,
      formMaxWidth: lerpDouble(formMaxWidth, other.formMaxWidth, t)!,
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      gridContentMaxWidth: lerpDouble(
        gridContentMaxWidth,
        other.gridContentMaxWidth,
        t,
      )!,
      gridTileMaxExtent: lerpDouble(
        gridTileMaxExtent,
        other.gridTileMaxExtent,
        t,
      )!,
      gridTileHeight: lerpDouble(gridTileHeight, other.gridTileHeight, t)!,
      heroHeight: lerpDouble(heroHeight, other.heroHeight, t)!,
      heroRadius: lerpDouble(heroRadius, other.heroRadius, t)!,
      brandPanelRadius: lerpDouble(
        brandPanelRadius,
        other.brandPanelRadius,
        t,
      )!,
      brandCardWidth: lerpDouble(brandCardWidth, other.brandCardWidth, t)!,
      brandCardHeight: lerpDouble(brandCardHeight, other.brandCardHeight, t)!,
      brandCardTilt: lerpDouble(brandCardTilt, other.brandCardTilt, t)!,
      illustrationWidth: lerpDouble(
        illustrationWidth,
        other.illustrationWidth,
        t,
      )!,
      illustrationHeight: lerpDouble(
        illustrationHeight,
        other.illustrationHeight,
        t,
      )!,
      progressStroke: lerpDouble(progressStroke, other.progressStroke, t)!,
      progressSize: lerpDouble(progressSize, other.progressSize, t)!,
      skeletonLine: lerpDouble(skeletonLine, other.skeletonLine, t)!,
      skeletonCardHeight: lerpDouble(
        skeletonCardHeight,
        other.skeletonCardHeight,
        t,
      )!,
      fabHeight: lerpDouble(fabHeight, other.fabHeight, t)!,
      dialogMaxWidth: lerpDouble(dialogMaxWidth, other.dialogMaxWidth, t)!,
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t)!,
    );
  }
}
