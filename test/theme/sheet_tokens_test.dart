import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const light = CardoColors.light;
  const dark = CardoColors.dark;

  group('colors', () {
    test('scrim is the same translucent ink in both themes', () {
      for (final colors in <CardoColors>[light, dark]) {
        expect(colors.scrim.a, closeTo(0.48, 0.005));
        expect((colors.scrim.r * 255).round(), 17);
        expect((colors.scrim.g * 255).round(), 19);
        expect((colors.scrim.b * 255).round(), 24);
      }
    });

    test('conflictIcon differs between themes', () {
      expect(light.conflictIcon, isNot(dark.conflictIcon));
    });

    test('copyWith and lerp cover scrim and conflictIcon', () {
      const marker = Color(0xFF010203);
      expect(light.copyWith(scrim: marker).scrim, marker);
      expect(light.copyWith(conflictIcon: marker).conflictIcon, marker);
      expect(light.copyWith().scrim, light.scrim);
      expect(light.copyWith().conflictIcon, light.conflictIcon);
      expect(light.lerp(dark, 0).conflictIcon, light.conflictIcon);
      expect(light.lerp(dark, 1).conflictIcon, dark.conflictIcon);
      expect(
        light.lerp(dark, 0.5).conflictIcon,
        Color.lerp(light.conflictIcon, dark.conflictIcon, 0.5),
      );
      expect(
        light.lerp(dark, 0.5).scrim,
        Color.lerp(light.scrim, dark.scrim, 0.5),
      );
    });

    test('the bottom sheet theme uses the scrim', () {
      expect(buildLightTheme().bottomSheetTheme.modalBarrierColor, light.scrim);
      expect(buildDarkTheme().bottomSheetTheme.modalBarrierColor, dark.scrim);
    });
  });

  group('layout and sizes', () {
    const layout = CardoLayout.standard;
    const sizes = CardoSizes.standard;

    test('match the M-Card mockup', () {
      expect(layout.sheetTopInset, 96);
      expect(layout.sheetPaddingTop, 10);
      expect(layout.sheetPaddingBottom, 24);
      expect(layout.sheetChipHeight, 30);
      expect(layout.stackActionsTextScale, 1.3);
      expect(sizes.sheetHandleWidth, 40);
      expect(sizes.sheetHandleHeight, 5);
      expect(sizes.avatarMeta, 24);
      expect(sizes.iconLarge, 20);
    });

    test('copyWith and lerp cover the new fields', () {
      expect(layout.copyWith(sheetTopInset: 1).sheetTopInset, 1);
      expect(layout.copyWith(sheetChipHeight: 2).sheetChipHeight, 2);
      expect(layout.copyWith().sheetPaddingTop, 10);
      expect(
        layout.lerp(layout.copyWith(sheetTopInset: 196), 0.5).sheetTopInset,
        146,
      );
      expect(sizes.copyWith(avatarMeta: 3).avatarMeta, 3);
      expect(sizes.copyWith(iconLarge: 4).iconLarge, 4);
      expect(sizes.copyWith(sheetHandleWidth: 5).sheetHandleWidth, 5);
      expect(sizes.copyWith().sheetHandleHeight, 5);
      expect(sizes.lerp(sizes.copyWith(iconLarge: 40), 0.5).iconLarge, 30);
    });
  });

  group('radii and spacing', () {
    test('chip and editor radii', () {
      const radii = CardoRadii.standard;
      expect(radii.chip, 9);
      expect(radii.editor, 16);
      expect(radii.sheet, 28);
      expect(radii.copyWith(chip: 1).chip, 1);
      expect(radii.copyWith(editor: 2).editor, 2);
      expect(radii.lerp(radii.copyWith(chip: 19), 0.5).chip, 14);
    });

    test('bannerTextGap', () {
      const spacing = CardoSpacing.standard;
      expect(spacing.bannerTextGap, 3);
      expect(spacing.copyWith(bannerTextGap: 7).bannerTextGap, 7);
      expect(
        spacing.lerp(spacing.copyWith(bannerTextGap: 5), 0.5).bannerTextGap,
        4,
      );
    });
  });

  group('typography', () {
    const typography = CardoTypography.standard;

    test('sheetTitle is Bricolage 26 / 700', () {
      final style = typography.sheetTitle;
      expect(style.fontSize, 26);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.height, 1.12);
      expect(style.letterSpacing, closeTo(-0.52, 0.001));
    });

    test('sheetField is Geist 15 with 1.55 line height', () {
      final style = typography.sheetField;
      expect(style.fontSize, 15);
      expect(style.height, 1.55);
    });

    test('bannerText is 13 with 1.45 line height', () {
      final style = typography.bannerText;
      expect(style.fontSize, 13);
      expect(style.height, 1.45);
    });

    test('copyWith and lerp cover the new styles', () {
      const marker = TextStyle(fontSize: 99);
      expect(typography.copyWith(sheetTitle: marker).sheetTitle, marker);
      expect(typography.copyWith(sheetField: marker).sheetField, marker);
      expect(typography.copyWith(bannerText: marker).bannerText, marker);
      expect(typography.copyWith().sheetTitle, typography.sheetTitle);
      final other = typography.copyWith(
        sheetField: typography.sheetField.copyWith(fontSize: 25),
      );
      expect(typography.lerp(other, 0.5).sheetField.fontSize, 20);
    });
  });

  group('themes', () {
    for (final theme in <ThemeData>[buildLightTheme(), buildDarkTheme()]) {
      test('${theme.brightness.name} carries the sheet tokens', () {
        expect(theme.extension<CardoLayout>()!.sheetTopInset, 96);
        expect(theme.extension<CardoSizes>()!.iconLarge, 20);
        expect(theme.extension<CardoTypography>()!.sheetTitle.fontSize, 26);
      });
    }
  });
}
