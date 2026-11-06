import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

enum CardoWindowClass { compact, medium, expanded }

@immutable
class CardoLayout extends ThemeExtension<CardoLayout> {
  const CardoLayout({
    required this.breakpointMedium,
    required this.breakpointExpanded,
    required this.columnWidth,
    required this.columnWidthDense,
    required this.sidebarWidth,
    required this.detailPanelWidth,
    required this.headerPaddingTop,
    required this.boardHeaderPaddingVertical,
    required this.tabHeight,
    required this.tabMarkerGap,
    required this.columnPaddingVertical,
    required this.columnPaddingHorizontal,
    required this.columnPaddingDense,
    required this.columnHeaderInset,
    required this.columnHeaderInsetDense,
    required this.columnHeaderBottom,
    required this.columnHeaderBottomDense,
    required this.markerColumnDense,
    required this.columnsPaddingVertical,
    required this.addCardHeight,
    required this.fadeHeight,
    required this.pageDot,
    required this.pageDotActive,
    required this.pageDotGap,
    required this.pageDotBottom,
    required this.sidebarPaddingVertical,
    required this.sidebarPaddingHorizontal,
    required this.sidebarGap,
    required this.sidebarItemGap,
    required this.boardAvatar,
    required this.panelPaddingVertical,
    required this.panelGap,
    required this.panelChipHeight,
    required this.descriptionMinHeight,
    required this.autoScrollEdge,
    required this.autoScrollStep,
    required this.pageFlipEdge,
    required this.addColumnWidth,
    required this.addColumnHeight,
    required this.addColumnRadius,
    required this.bannerPaddingVertical,
    required this.bannerRadius,
    required this.iconDense,
    required this.iconHeader,
    required this.sheetTopInset,
    required this.sheetPaddingTop,
    required this.sheetPaddingBottom,
    required this.sheetChipHeight,
    required this.stackActionsTextScale,
    required this.headerMaxFraction,
  });

  static const CardoLayout standard = CardoLayout(
    breakpointMedium: 600,
    breakpointExpanded: 840,
    columnWidth: 318,
    columnWidthDense: 272,
    sidebarWidth: 232,
    detailPanelWidth: 360,
    headerPaddingTop: 14,
    boardHeaderPaddingVertical: 18,
    tabHeight: 36,
    tabMarkerGap: 7,
    columnPaddingVertical: 12,
    columnPaddingHorizontal: 10,
    columnPaddingDense: 12,
    columnHeaderInset: 6,
    columnHeaderInsetDense: 4,
    columnHeaderBottom: 4,
    columnHeaderBottomDense: 6,
    markerColumnDense: 9,
    columnsPaddingVertical: 20,
    addCardHeight: 46,
    fadeHeight: 64,
    pageDot: 6,
    pageDotActive: 18,
    pageDotGap: 6,
    pageDotBottom: 22,
    sidebarPaddingVertical: 20,
    sidebarPaddingHorizontal: 14,
    sidebarGap: 22,
    sidebarItemGap: 2,
    boardAvatar: 34,
    panelPaddingVertical: 22,
    panelGap: 18,
    panelChipHeight: 28,
    descriptionMinHeight: 200,
    autoScrollEdge: 56,
    autoScrollStep: 14,
    pageFlipEdge: 40,
    addColumnWidth: 240,
    addColumnHeight: 52,
    addColumnRadius: 16,
    bannerPaddingVertical: 10,
    bannerRadius: 12,
    iconDense: 16,
    iconHeader: 22,
    sheetTopInset: 96,
    sheetPaddingTop: 10,
    sheetPaddingBottom: 24,
    sheetChipHeight: 30,
    stackActionsTextScale: 1.3,
    headerMaxFraction: 0.5,
  );

  final double breakpointMedium;
  final double breakpointExpanded;
  final double columnWidth;
  final double columnWidthDense;
  final double sidebarWidth;
  final double detailPanelWidth;
  final double headerPaddingTop;
  final double boardHeaderPaddingVertical;
  final double tabHeight;
  final double tabMarkerGap;
  final double columnPaddingVertical;
  final double columnPaddingHorizontal;
  final double columnPaddingDense;
  final double columnHeaderInset;
  final double columnHeaderInsetDense;
  final double columnHeaderBottom;
  final double columnHeaderBottomDense;
  final double markerColumnDense;
  final double columnsPaddingVertical;
  final double addCardHeight;
  final double fadeHeight;
  final double pageDot;
  final double pageDotActive;
  final double pageDotGap;
  final double pageDotBottom;
  final double sidebarPaddingVertical;
  final double sidebarPaddingHorizontal;
  final double sidebarGap;
  final double sidebarItemGap;
  final double boardAvatar;
  final double panelPaddingVertical;
  final double panelGap;
  final double panelChipHeight;
  final double descriptionMinHeight;
  final double autoScrollEdge;
  final double autoScrollStep;
  final double pageFlipEdge;
  final double addColumnWidth;
  final double addColumnHeight;
  final double addColumnRadius;
  final double bannerPaddingVertical;
  final double bannerRadius;
  final double iconDense;
  final double iconHeader;
  final double sheetTopInset;
  final double sheetPaddingTop;
  final double sheetPaddingBottom;
  final double sheetChipHeight;
  final double stackActionsTextScale;
  final double headerMaxFraction;

  static CardoLayout of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoLayout>();
    assert(
      extension != null,
      'CardoLayout missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  CardoWindowClass windowClassFor(double width) {
    if (width >= breakpointExpanded) {
      return CardoWindowClass.expanded;
    }
    if (width >= breakpointMedium) {
      return CardoWindowClass.medium;
    }
    return CardoWindowClass.compact;
  }

  double columnWidthFor({required bool dense}) =>
      dense ? columnWidthDense : columnWidth;

  @override
  CardoLayout copyWith({
    double? breakpointMedium,
    double? breakpointExpanded,
    double? columnWidth,
    double? columnWidthDense,
    double? sidebarWidth,
    double? detailPanelWidth,
    double? headerPaddingTop,
    double? boardHeaderPaddingVertical,
    double? tabHeight,
    double? tabMarkerGap,
    double? columnPaddingVertical,
    double? columnPaddingHorizontal,
    double? columnPaddingDense,
    double? columnHeaderInset,
    double? columnHeaderInsetDense,
    double? columnHeaderBottom,
    double? columnHeaderBottomDense,
    double? markerColumnDense,
    double? columnsPaddingVertical,
    double? addCardHeight,
    double? fadeHeight,
    double? pageDot,
    double? pageDotActive,
    double? pageDotGap,
    double? pageDotBottom,
    double? sidebarPaddingVertical,
    double? sidebarPaddingHorizontal,
    double? sidebarGap,
    double? sidebarItemGap,
    double? boardAvatar,
    double? panelPaddingVertical,
    double? panelGap,
    double? panelChipHeight,
    double? descriptionMinHeight,
    double? autoScrollEdge,
    double? autoScrollStep,
    double? pageFlipEdge,
    double? addColumnWidth,
    double? addColumnHeight,
    double? addColumnRadius,
    double? bannerPaddingVertical,
    double? bannerRadius,
    double? iconDense,
    double? iconHeader,
    double? sheetTopInset,
    double? sheetPaddingTop,
    double? sheetPaddingBottom,
    double? sheetChipHeight,
    double? stackActionsTextScale,
    double? headerMaxFraction,
  }) {
    return CardoLayout(
      breakpointMedium: breakpointMedium ?? this.breakpointMedium,
      breakpointExpanded: breakpointExpanded ?? this.breakpointExpanded,
      columnWidth: columnWidth ?? this.columnWidth,
      columnWidthDense: columnWidthDense ?? this.columnWidthDense,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      detailPanelWidth: detailPanelWidth ?? this.detailPanelWidth,
      headerPaddingTop: headerPaddingTop ?? this.headerPaddingTop,
      boardHeaderPaddingVertical:
          boardHeaderPaddingVertical ?? this.boardHeaderPaddingVertical,
      tabHeight: tabHeight ?? this.tabHeight,
      tabMarkerGap: tabMarkerGap ?? this.tabMarkerGap,
      columnPaddingVertical:
          columnPaddingVertical ?? this.columnPaddingVertical,
      columnPaddingHorizontal:
          columnPaddingHorizontal ?? this.columnPaddingHorizontal,
      columnPaddingDense: columnPaddingDense ?? this.columnPaddingDense,
      columnHeaderInset: columnHeaderInset ?? this.columnHeaderInset,
      columnHeaderInsetDense:
          columnHeaderInsetDense ?? this.columnHeaderInsetDense,
      columnHeaderBottom: columnHeaderBottom ?? this.columnHeaderBottom,
      columnHeaderBottomDense:
          columnHeaderBottomDense ?? this.columnHeaderBottomDense,
      markerColumnDense: markerColumnDense ?? this.markerColumnDense,
      columnsPaddingVertical:
          columnsPaddingVertical ?? this.columnsPaddingVertical,
      addCardHeight: addCardHeight ?? this.addCardHeight,
      fadeHeight: fadeHeight ?? this.fadeHeight,
      pageDot: pageDot ?? this.pageDot,
      pageDotActive: pageDotActive ?? this.pageDotActive,
      pageDotGap: pageDotGap ?? this.pageDotGap,
      pageDotBottom: pageDotBottom ?? this.pageDotBottom,
      sidebarPaddingVertical:
          sidebarPaddingVertical ?? this.sidebarPaddingVertical,
      sidebarPaddingHorizontal:
          sidebarPaddingHorizontal ?? this.sidebarPaddingHorizontal,
      sidebarGap: sidebarGap ?? this.sidebarGap,
      sidebarItemGap: sidebarItemGap ?? this.sidebarItemGap,
      boardAvatar: boardAvatar ?? this.boardAvatar,
      panelPaddingVertical: panelPaddingVertical ?? this.panelPaddingVertical,
      panelGap: panelGap ?? this.panelGap,
      panelChipHeight: panelChipHeight ?? this.panelChipHeight,
      descriptionMinHeight: descriptionMinHeight ?? this.descriptionMinHeight,
      autoScrollEdge: autoScrollEdge ?? this.autoScrollEdge,
      autoScrollStep: autoScrollStep ?? this.autoScrollStep,
      pageFlipEdge: pageFlipEdge ?? this.pageFlipEdge,
      addColumnWidth: addColumnWidth ?? this.addColumnWidth,
      addColumnHeight: addColumnHeight ?? this.addColumnHeight,
      addColumnRadius: addColumnRadius ?? this.addColumnRadius,
      bannerPaddingVertical:
          bannerPaddingVertical ?? this.bannerPaddingVertical,
      bannerRadius: bannerRadius ?? this.bannerRadius,
      iconDense: iconDense ?? this.iconDense,
      iconHeader: iconHeader ?? this.iconHeader,
      sheetTopInset: sheetTopInset ?? this.sheetTopInset,
      sheetPaddingTop: sheetPaddingTop ?? this.sheetPaddingTop,
      sheetPaddingBottom: sheetPaddingBottom ?? this.sheetPaddingBottom,
      sheetChipHeight: sheetChipHeight ?? this.sheetChipHeight,
      stackActionsTextScale:
          stackActionsTextScale ?? this.stackActionsTextScale,
      headerMaxFraction: headerMaxFraction ?? this.headerMaxFraction,
    );
  }

  @override
  CardoLayout lerp(covariant ThemeExtension<CardoLayout>? other, double t) {
    if (other is! CardoLayout) {
      return this;
    }
    double l(double a, double b) => lerpDouble(a, b, t) ?? b;
    return CardoLayout(
      breakpointMedium: l(breakpointMedium, other.breakpointMedium),
      breakpointExpanded: l(breakpointExpanded, other.breakpointExpanded),
      columnWidth: l(columnWidth, other.columnWidth),
      columnWidthDense: l(columnWidthDense, other.columnWidthDense),
      sidebarWidth: l(sidebarWidth, other.sidebarWidth),
      detailPanelWidth: l(detailPanelWidth, other.detailPanelWidth),
      headerPaddingTop: l(headerPaddingTop, other.headerPaddingTop),
      boardHeaderPaddingVertical: l(
        boardHeaderPaddingVertical,
        other.boardHeaderPaddingVertical,
      ),
      tabHeight: l(tabHeight, other.tabHeight),
      tabMarkerGap: l(tabMarkerGap, other.tabMarkerGap),
      columnPaddingVertical: l(
        columnPaddingVertical,
        other.columnPaddingVertical,
      ),
      columnPaddingHorizontal: l(
        columnPaddingHorizontal,
        other.columnPaddingHorizontal,
      ),
      columnPaddingDense: l(columnPaddingDense, other.columnPaddingDense),
      columnHeaderInset: l(columnHeaderInset, other.columnHeaderInset),
      columnHeaderInsetDense: l(
        columnHeaderInsetDense,
        other.columnHeaderInsetDense,
      ),
      columnHeaderBottom: l(columnHeaderBottom, other.columnHeaderBottom),
      columnHeaderBottomDense: l(
        columnHeaderBottomDense,
        other.columnHeaderBottomDense,
      ),
      markerColumnDense: l(markerColumnDense, other.markerColumnDense),
      columnsPaddingVertical: l(
        columnsPaddingVertical,
        other.columnsPaddingVertical,
      ),
      addCardHeight: l(addCardHeight, other.addCardHeight),
      fadeHeight: l(fadeHeight, other.fadeHeight),
      pageDot: l(pageDot, other.pageDot),
      pageDotActive: l(pageDotActive, other.pageDotActive),
      pageDotGap: l(pageDotGap, other.pageDotGap),
      pageDotBottom: l(pageDotBottom, other.pageDotBottom),
      sidebarPaddingVertical: l(
        sidebarPaddingVertical,
        other.sidebarPaddingVertical,
      ),
      sidebarPaddingHorizontal: l(
        sidebarPaddingHorizontal,
        other.sidebarPaddingHorizontal,
      ),
      sidebarGap: l(sidebarGap, other.sidebarGap),
      sidebarItemGap: l(sidebarItemGap, other.sidebarItemGap),
      boardAvatar: l(boardAvatar, other.boardAvatar),
      panelPaddingVertical: l(panelPaddingVertical, other.panelPaddingVertical),
      panelGap: l(panelGap, other.panelGap),
      panelChipHeight: l(panelChipHeight, other.panelChipHeight),
      descriptionMinHeight: l(descriptionMinHeight, other.descriptionMinHeight),
      autoScrollEdge: l(autoScrollEdge, other.autoScrollEdge),
      autoScrollStep: l(autoScrollStep, other.autoScrollStep),
      pageFlipEdge: l(pageFlipEdge, other.pageFlipEdge),
      addColumnWidth: l(addColumnWidth, other.addColumnWidth),
      addColumnHeight: l(addColumnHeight, other.addColumnHeight),
      addColumnRadius: l(addColumnRadius, other.addColumnRadius),
      bannerPaddingVertical: l(
        bannerPaddingVertical,
        other.bannerPaddingVertical,
      ),
      bannerRadius: l(bannerRadius, other.bannerRadius),
      iconDense: l(iconDense, other.iconDense),
      iconHeader: l(iconHeader, other.iconHeader),
      sheetTopInset: l(sheetTopInset, other.sheetTopInset),
      sheetPaddingTop: l(sheetPaddingTop, other.sheetPaddingTop),
      sheetPaddingBottom: l(sheetPaddingBottom, other.sheetPaddingBottom),
      sheetChipHeight: l(sheetChipHeight, other.sheetChipHeight),
      stackActionsTextScale: l(
        stackActionsTextScale,
        other.stackActionsTextScale,
      ),
      headerMaxFraction: l(headerMaxFraction, other.headerMaxFraction),
    );
  }
}
