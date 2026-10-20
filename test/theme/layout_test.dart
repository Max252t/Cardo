import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Map<String, double> _values(CardoLayout layout) {
  return <String, double>{
    'breakpointMedium': layout.breakpointMedium,
    'breakpointExpanded': layout.breakpointExpanded,
    'columnWidth': layout.columnWidth,
    'columnWidthDense': layout.columnWidthDense,
    'sidebarWidth': layout.sidebarWidth,
    'detailPanelWidth': layout.detailPanelWidth,
    'headerPaddingTop': layout.headerPaddingTop,
    'boardHeaderPaddingVertical': layout.boardHeaderPaddingVertical,
    'tabHeight': layout.tabHeight,
    'tabMarkerGap': layout.tabMarkerGap,
    'columnPaddingVertical': layout.columnPaddingVertical,
    'columnPaddingHorizontal': layout.columnPaddingHorizontal,
    'columnPaddingDense': layout.columnPaddingDense,
    'columnHeaderInset': layout.columnHeaderInset,
    'columnHeaderInsetDense': layout.columnHeaderInsetDense,
    'columnHeaderBottom': layout.columnHeaderBottom,
    'columnHeaderBottomDense': layout.columnHeaderBottomDense,
    'markerColumnDense': layout.markerColumnDense,
    'columnsPaddingVertical': layout.columnsPaddingVertical,
    'addCardHeight': layout.addCardHeight,
    'fadeHeight': layout.fadeHeight,
    'pageDot': layout.pageDot,
    'pageDotActive': layout.pageDotActive,
    'pageDotGap': layout.pageDotGap,
    'pageDotBottom': layout.pageDotBottom,
    'sidebarPaddingVertical': layout.sidebarPaddingVertical,
    'sidebarPaddingHorizontal': layout.sidebarPaddingHorizontal,
    'sidebarGap': layout.sidebarGap,
    'sidebarItemGap': layout.sidebarItemGap,
    'boardAvatar': layout.boardAvatar,
    'panelPaddingVertical': layout.panelPaddingVertical,
    'panelGap': layout.panelGap,
    'panelChipHeight': layout.panelChipHeight,
    'descriptionMinHeight': layout.descriptionMinHeight,
    'autoScrollEdge': layout.autoScrollEdge,
    'autoScrollStep': layout.autoScrollStep,
    'pageFlipEdge': layout.pageFlipEdge,
    'addColumnWidth': layout.addColumnWidth,
    'addColumnHeight': layout.addColumnHeight,
    'addColumnRadius': layout.addColumnRadius,
    'bannerPaddingVertical': layout.bannerPaddingVertical,
    'bannerRadius': layout.bannerRadius,
    'iconDense': layout.iconDense,
    'iconHeader': layout.iconHeader,
    'headerMaxFraction': layout.headerMaxFraction,
  };
}

void main() {
  const standard = CardoLayout.standard;

  group('CardoLayout in both themes', () {
    final themes = <String, ThemeData>{
      'light': buildLightTheme(),
      'dark': buildDarkTheme(),
    };

    themes.forEach((name, theme) {
      test('$name theme carries the standard layout', () {
        expect(theme.extension<CardoLayout>(), isNotNull);
        expect(_values(theme.extension<CardoLayout>()!), _values(standard));
      });
    });

    for (final brightness in Brightness.values) {
      testWidgets('of(context) in ${brightness.name}', (tester) async {
        late CardoLayout layout;
        await pumpApp(
          tester,
          Builder(
            builder: (context) {
              layout = CardoLayout.of(context);
              return const SizedBox.shrink();
            },
          ),
          brightness: brightness,
        );
        expect(_values(layout), _values(standard));
      });
    }

    testWidgets('of(context) asserts without the cardo theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CardoLayout.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('CardoLayout values', () {
    test('match the mockups', () {
      expect(standard.breakpointMedium, 600);
      expect(standard.breakpointExpanded, 840);
      expect(standard.columnWidth, 318);
      expect(standard.columnWidthDense, 272);
      expect(standard.sidebarWidth, 232);
      expect(standard.detailPanelWidth, 360);
    });

    test('every value is positive', () {
      _values(standard).forEach((name, value) {
        expect(value, greaterThan(0), reason: name);
      });
    });

    test('active page dot is wider than an inactive one', () {
      expect(standard.pageDotActive, greaterThan(standard.pageDot));
    });

    test('columnWidthFor picks dense or regular', () {
      expect(standard.columnWidthFor(dense: false), 318);
      expect(standard.columnWidthFor(dense: true), 272);
    });
  });

  group('windowClassFor', () {
    test('compact below 600', () {
      expect(standard.windowClassFor(0), CardoWindowClass.compact);
      expect(standard.windowClassFor(375), CardoWindowClass.compact);
      expect(standard.windowClassFor(599), CardoWindowClass.compact);
      expect(standard.windowClassFor(599.99), CardoWindowClass.compact);
    });

    test('medium from 600 to below 840', () {
      expect(standard.windowClassFor(600), CardoWindowClass.medium);
      expect(standard.windowClassFor(700), CardoWindowClass.medium);
      expect(standard.windowClassFor(839), CardoWindowClass.medium);
      expect(standard.windowClassFor(839.99), CardoWindowClass.medium);
    });

    test('expanded from 840', () {
      expect(standard.windowClassFor(840), CardoWindowClass.expanded);
      expect(standard.windowClassFor(1280), CardoWindowClass.expanded);
      expect(standard.windowClassFor(5000), CardoWindowClass.expanded);
    });

    test('follows custom breakpoints', () {
      final custom = standard.copyWith(
        breakpointMedium: 400,
        breakpointExpanded: 500,
      );
      expect(custom.windowClassFor(399), CardoWindowClass.compact);
      expect(custom.windowClassFor(400), CardoWindowClass.medium);
      expect(custom.windowClassFor(500), CardoWindowClass.expanded);
    });
  });

  group('CardoLayout copyWith and lerp', () {
    test('copyWith without arguments keeps every value', () {
      expect(_values(standard.copyWith()), _values(standard));
    });

    test('copyWith replaces only the requested field', () {
      final copy = standard.copyWith(columnWidth: 1, iconHeader: 2);
      final changed = <String, double>{'columnWidth': 1, 'iconHeader': 2};
      _values(copy).forEach((name, value) {
        expect(value, changed[name] ?? _values(standard)[name], reason: name);
      });
    });

    test('lerp ends and middle', () {
      final other = standard.copyWith(
        columnWidth: 418,
        sidebarWidth: 332,
        iconHeader: 42,
      );
      expect(standard.lerp(other, 0).columnWidth, 318);
      expect(standard.lerp(other, 1).columnWidth, 418);
      expect(standard.lerp(other, 0.5).columnWidth, closeTo(368, 0.001));
      expect(standard.lerp(other, 0.5).sidebarWidth, closeTo(282, 0.001));
      expect(standard.lerp(other, 0.5).iconHeader, closeTo(32, 0.001));
      expect(standard.lerp(other, 0.5).detailPanelWidth, 360);
    });

    test('lerp with itself keeps every value', () {
      expect(_values(standard.lerp(standard, 0.3)), _values(standard));
    });

    test('lerp with a foreign extension returns this', () {
      expect(standard.lerp(null, 0.7), same(standard));
    });
  });

  group('CardoColors board tokens', () {
    const light = CardoColors.light;
    const dark = CardoColors.dark;

    test('are distinct between themes', () {
      expect(light.outlineMuted, isNot(dark.outlineMuted));
      expect(light.sidebarField, isNot(dark.sidebarField));
      expect(light.tabActiveCount, isNot(dark.tabActiveCount));
    });

    test('copyWith replaces each token', () {
      const marker = Color(0xFF010203);
      expect(light.copyWith(outlineMuted: marker).outlineMuted, marker);
      expect(light.copyWith(sidebarField: marker).sidebarField, marker);
      expect(light.copyWith(tabActiveCount: marker).tabActiveCount, marker);
      expect(light.copyWith().outlineMuted, light.outlineMuted);
      expect(light.copyWith().sidebarField, light.sidebarField);
      expect(light.copyWith().tabActiveCount, light.tabActiveCount);
    });

    test('copyWith of one token leaves the others', () {
      final copy = light.copyWith(sidebarField: const Color(0xFF010203));
      expect(copy.outlineMuted, light.outlineMuted);
      expect(copy.tabActiveCount, light.tabActiveCount);
    });

    test('lerp interpolates each token', () {
      final start = light.lerp(dark, 0);
      final end = light.lerp(dark, 1);
      final mid = light.lerp(dark, 0.5);
      expect(start.outlineMuted, light.outlineMuted);
      expect(end.outlineMuted, dark.outlineMuted);
      expect(
        mid.sidebarField,
        Color.lerp(light.sidebarField, dark.sidebarField, 0.5),
      );
      expect(
        mid.tabActiveCount,
        Color.lerp(light.tabActiveCount, dark.tabActiveCount, 0.5),
      );
      expect(end.tabActiveCount, dark.tabActiveCount);
      expect(end.sidebarField, dark.sidebarField);
    });
  });

  group('avatar initial table', () {
    const typography = CardoTypography.standard;

    test('maps the mockup diameters to sizes', () {
      expect(typography.avatarInitialSize(22), 11);
      expect(typography.avatarInitialSize(30), 12);
      expect(typography.avatarInitialSize(34), 13);
      expect(typography.avatarInitialSize(36), 14);
    });

    test('boundaries fall into the lower step', () {
      expect(typography.avatarInitialSize(21.9), 11);
      expect(typography.avatarInitialSize(22.1), 12);
      expect(typography.avatarInitialSize(29.9), 12);
      expect(typography.avatarInitialSize(30.1), 13);
      expect(typography.avatarInitialSize(33.9), 13);
      expect(typography.avatarInitialSize(34.1), 14);
    });

    test('tiny and huge diameters use the end steps', () {
      expect(typography.avatarInitialSize(0), 11);
      expect(typography.avatarInitialSize(10), 11);
      expect(typography.avatarInitialSize(200), 14);
      expect(typography.avatarInitialSize(double.infinity), 14);
    });

    test('steps ascend and end with an open step', () {
      final steps = typography.avatarInitialSteps;
      expect(steps.length, 4);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].maxDiameter, greaterThan(steps[i - 1].maxDiameter));
        expect(steps[i].fontSize, greaterThan(steps[i - 1].fontSize));
      }
      expect(steps.last.maxDiameter, double.infinity);
    });

    test('avatarInitial style uses the table with height 1', () {
      for (final entry in <double, double>{
        22: 11,
        30: 12,
        34: 13,
        36: 14,
      }.entries) {
        final style = typography.avatarInitial(entry.key);
        expect(style.fontSize, entry.value);
        expect(style.height, 1);
      }
    });
  });

  group('CardoDurations', () {
    test('sync timings are sane', () {
      expect(
        CardoDurations.syncConfirmDelay,
        const Duration(milliseconds: 700),
      );
      expect(CardoDurations.nackHold, const Duration(milliseconds: 2400));
      expect(CardoDurations.syncRetryDelay, const Duration(milliseconds: 1500));
      expect(CardoDurations.snackbar, const Duration(seconds: 4));
      expect(
        CardoDurations.nackHold,
        greaterThan(CardoDurations.syncConfirmDelay),
      );
    });
  });
}
