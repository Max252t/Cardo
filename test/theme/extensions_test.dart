import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

const _swatchA = ConnectionSwatch(
  background: Color(0xFF000001),
  foreground: Color(0xFF000002),
  glyph: Color(0xFF000003),
  compactForeground: Color(0xFF000004),
  compactGlyph: Color(0xFF000005),
);

const _swatchB = ConnectionSwatch(
  background: Color(0xFFF00001),
  foreground: Color(0xFFF00002),
  glyph: Color(0xFFF00003),
  compactForeground: Color(0xFFF00004),
  compactGlyph: Color(0xFFF00005),
);

void main() {
  final themes = <String, ThemeData>{
    'light': buildLightTheme(),
    'dark': buildDarkTheme(),
  };

  group('ThemeData extensions', () {
    themes.forEach((name, theme) {
      test('$name has all 7 extensions', () {
        expect(theme.extension<CardoColors>(), isNotNull);
        expect(theme.extension<CardoTypography>(), isNotNull);
        expect(theme.extension<CardoRadii>(), isNotNull);
        expect(theme.extension<CardoSpacing>(), isNotNull);
        expect(theme.extension<CardoSizes>(), isNotNull);
        expect(theme.extension<CardoShadows>(), isNotNull);
        expect(theme.extension<CardoMotion>(), isNotNull);
        expect(theme.extensions.length, 7);
      });
    });

    test('brightness matches', () {
      expect(themes['light']!.brightness, Brightness.light);
      expect(themes['dark']!.brightness, Brightness.dark);
      expect(
        themes['light']!.extension<CardoColors>()!.brightness,
        Brightness.light,
      );
      expect(
        themes['dark']!.extension<CardoColors>()!.brightness,
        Brightness.dark,
      );
    });
  });

  group('of(context)', () {
    testWidgets('returns light set in light theme', (tester) async {
      late CardoColors colors;
      late CardoShadows shadows;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = CardoColors.of(context);
            shadows = CardoShadows.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(colors.background, CardoColors.light.background);
      expect(colors.textPrimary, CardoColors.light.textPrimary);
      expect(shadows.card, CardoShadows.light.card);
    });

    testWidgets('returns dark set in dark theme', (tester) async {
      late CardoColors colors;
      late CardoShadows shadows;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = CardoColors.of(context);
            shadows = CardoShadows.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(colors.background, CardoColors.dark.background);
      expect(colors.textPrimary, CardoColors.dark.textPrimary);
      expect(shadows.card, CardoShadows.dark.card);
    });

    testWidgets('returns every extension', (tester) async {
      late List<Object> all;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            all = <Object>[
              CardoColors.of(context),
              CardoTypography.of(context),
              CardoRadii.of(context),
              CardoSpacing.of(context),
              CardoSizes.of(context),
              CardoShadows.of(context),
              CardoMotion.of(context),
            ];
            return const SizedBox();
          },
        ),
      );
      expect(all.length, 7);
    });

    testWidgets('asserts without cardo theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              expect(() => CardoColors.of(context), throwsAssertionError);
              expect(() => CardoTypography.of(context), throwsAssertionError);
              expect(() => CardoRadii.of(context), throwsAssertionError);
              expect(() => CardoSpacing.of(context), throwsAssertionError);
              expect(() => CardoSizes.of(context), throwsAssertionError);
              expect(() => CardoShadows.of(context), throwsAssertionError);
              expect(() => CardoMotion.of(context), throwsAssertionError);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('CardoColors', () {
    const light = CardoColors.light;
    const dark = CardoColors.dark;

    test('copyWith without arguments keeps values', () {
      final copy = light.copyWith();
      expect(copy.brightness, light.brightness);
      expect(copy.background, light.background);
      expect(copy.textSecondary, light.textSecondary);
      expect(copy.connected, light.connected);
      expect(copy.offline, light.offline);
      expect(copy.avatarFallback, light.avatarFallback);
      expect(copy.avatarOverflowText, light.avatarOverflowText);
    });

    test('copyWith replaces a field', () {
      final copy = light.copyWith(background: const Color(0xFF123456));
      expect(copy.background, const Color(0xFF123456));
      expect(copy.surface, light.surface);
    });

    test('lerp 0 and 1', () {
      final start = light.lerp(dark, 0);
      final end = light.lerp(dark, 1);
      expect(start.background, light.background);
      expect(start.card, light.card);
      expect(start.connected, light.connected);
      expect(start.brightness, Brightness.light);
      expect(end.background, dark.background);
      expect(end.card, dark.card);
      expect(end.connected, dark.connected);
      expect(end.brightness, Brightness.dark);
    });

    test('lerp midpoint interpolates colors', () {
      final mid = light.lerp(dark, 0.5);
      expect(
        mid.background,
        Color.lerp(light.background, dark.background, 0.5),
      );
    });

    test('brightness snaps at 0.5', () {
      expect(light.lerp(dark, 0.49).brightness, Brightness.light);
      expect(light.lerp(dark, 0.5).brightness, Brightness.dark);
    });

    test('lerp with foreign extension returns this', () {
      expect(light.lerp(null, 0.7), same(light));
    });

    test('avatarSwatch uses theme brightness', () {
      final lightSwatch = light.avatarSwatch(CardoAvatarPalette.violet);
      final darkSwatch = dark.avatarSwatch(CardoAvatarPalette.violet);
      expect(lightSwatch.accent, lightSwatch.fill);
      expect(darkSwatch.accent, isNot(darkSwatch.fill));
    });
  });

  group('ConnectionSwatch', () {
    test('equality and hashCode', () {
      expect(_swatchA, _swatchA.copyWith());
      expect(_swatchA.hashCode, _swatchA.copyWith().hashCode);
      expect(_swatchA == _swatchB, isFalse);
    });

    test('copyWith replaces', () {
      final c = _swatchA.copyWith(glyph: _swatchB.glyph);
      expect(c.glyph, _swatchB.glyph);
      expect(c.background, _swatchA.background);
    });

    test('lerp ends', () {
      expect(ConnectionSwatch.lerp(_swatchA, _swatchB, 0), _swatchA);
      expect(ConnectionSwatch.lerp(_swatchA, _swatchB, 1), _swatchB);
    });
  });

  group('CardoRadii', () {
    const base = CardoRadii.standard;
    final other = base.copyWith(card: 30, pill: 1);

    test('copyWith keeps values', () {
      final copy = base.copyWith();
      expect(copy.card, base.card);
      expect(copy.column, base.column);
      expect(copy.cardDense, base.cardDense);
      expect(copy.sheet, base.sheet);
    });

    test('dense variants', () {
      expect(base.cardFor(dense: false), 14);
      expect(base.cardFor(dense: true), 12);
      expect(base.columnFor(dense: false), 20);
      expect(base.columnFor(dense: true), 18);
    });

    test('lerp ends and middle', () {
      expect(base.lerp(other, 0).card, base.card);
      expect(base.lerp(other, 1).card, 30);
      expect(base.lerp(other, 0.5).card, closeTo((14 + 30) / 2, 0.001));
      expect(base.lerp(other, 1).pill, 1);
    });

    test('lerp with null returns this', () {
      expect(base.lerp(null, 1), same(base));
    });
  });

  group('CardoSpacing', () {
    const base = CardoSpacing.standard;
    final other = base.copyWith(xs: 100, cardPadding: 50);

    test('copyWith keeps values', () {
      final copy = base.copyWith();
      expect(copy.xs, base.xs);
      expect(copy.cardPadding, base.cardPadding);
      expect(copy.cardPaddingDense, base.cardPaddingDense);
      expect(copy.section, base.section);
    });

    test('lerp ends and middle', () {
      expect(base.lerp(other, 0).xs, base.xs);
      expect(base.lerp(other, 1).xs, 100);
      expect(base.lerp(other, 0.5).xs, closeTo((base.xs + 100) / 2, 0.001));
      expect(base.lerp(other, 1).cardPadding, 50);
    });

    test('dense helpers', () {
      expect(base.cardPaddingFor(dense: true), base.cardPaddingDense);
      expect(base.cardPaddingFor(dense: false), base.cardPadding);
    });
  });

  group('CardoSizes', () {
    const base = CardoSizes.standard;
    final other = base.copyWith(tapTarget: 100, hairline: 3);

    test('copyWith keeps values', () {
      final copy = base.copyWith();
      expect(copy.tapTarget, base.tapTarget);
      expect(copy.hairline, base.hairline);
      expect(copy.pillHeight, base.pillHeight);
      expect(copy.badgeHeight, base.badgeHeight);
    });

    test('tap target is at least 44', () {
      expect(base.tapTarget, greaterThanOrEqualTo(44));
    });

    test('lerp ends and middle', () {
      expect(base.lerp(other, 0).tapTarget, base.tapTarget);
      expect(base.lerp(other, 1).tapTarget, 100);
      expect(base.lerp(other, 1).hairline, 3);
      expect(
        base.lerp(other, 0.5).tapTarget,
        closeTo((base.tapTarget + 100) / 2, 0.001),
      );
    });
  });

  group('CardoTypography', () {
    const base = CardoTypography.standard;
    final other = base.copyWith(
      display: const TextStyle(fontSize: 80, fontWeight: FontWeight.w400),
      avatarInitialRatio: 0.8,
    );

    test('copyWith keeps values', () {
      final copy = base.copyWith();
      expect(copy.display, base.display);
      expect(copy.body, base.body);
      expect(copy.mono, base.mono);
      expect(copy.avatarInitialRatio, base.avatarInitialRatio);
      expect(copy.avatarInitialMin, base.avatarInitialMin);
    });

    test('bricolage styles have Geist fallback for cyrillic', () {
      for (final style in <TextStyle>[
        base.display,
        base.title,
        base.titleLarge,
        base.cardTitle,
        base.logo,
        base.logoLarge,
      ]) {
        expect(style.fontFamily, CardoFonts.bricolage);
        expect(style.fontFamilyFallback, contains(CardoFonts.geist));
      }
    });

    test('mono uses Geist Mono', () {
      expect(base.mono.fontFamily, CardoFonts.geistMono);
    });

    test('no font variations are used', () {
      for (final style in <TextStyle>[base.display, base.body, base.mono]) {
        expect(style.fontVariations, isNull);
      }
    });

    test('lerp ends and middle', () {
      expect(base.lerp(other, 0).display.fontSize, base.display.fontSize);
      expect(base.lerp(other, 1).display.fontSize, 80);
      expect(base.lerp(other, 0.5).display.fontSize, closeTo(60, 0.001));
      expect(base.lerp(other, 1).avatarInitialRatio, 0.8);
      expect(base.lerp(other, 0).avatarInitialRatio, base.avatarInitialRatio);
    });

    test('avatarInitial scales with diameter and respects minimum', () {
      expect(base.avatarInitial(100).fontSize, 40);
      expect(base.avatarInitial(10).fontSize, base.avatarInitialMin);
      expect(base.avatarInitial(28).height, 1);
    });
  });

  group('CardoShadows', () {
    const light = CardoShadows.light;
    const dark = CardoShadows.dark;

    test('copyWith keeps values', () {
      final copy = light.copyWith();
      expect(copy.card, light.card);
      expect(copy.dragging, light.dragging);
      expect(copy.fab, light.fab);
    });

    test('lerp ends', () {
      expect(
        light.lerp(dark, 0).dragging.first.color,
        light.dragging.first.color,
      );
      expect(
        light.lerp(dark, 1).dragging.first.color,
        dark.dragging.first.color,
      );
      for (final shadow in light.lerp(dark, 1).card) {
        expect(shadow.blurRadius, 0);
        expect(shadow.offset, Offset.zero);
      }
    });

    test('dark card has no shadow', () {
      expect(dark.card, isEmpty);
      expect(light.card, isNotEmpty);
    });
  });

  group('CardoMotion', () {
    const base = CardoMotion.standard;
    final other = base.copyWith(
      lift: const Duration(milliseconds: 1000),
      liftCurve: Curves.linear,
      reorder: const Duration(milliseconds: 2000),
      reorderCurve: Curves.linear,
      dragScale: 2,
      dragTiltTurns: 0.5,
    );

    test('copyWith keeps values', () {
      final copy = base.copyWith();
      expect(copy.lift, base.lift);
      expect(copy.liftCurve, base.liftCurve);
      expect(copy.reorder, base.reorder);
      expect(copy.reorderCurve, base.reorderCurve);
      expect(copy.dragTiltTurns, base.dragTiltTurns);
      expect(copy.dragScale, base.dragScale);
    });

    test('lerp 0 equals this', () {
      final r = base.lerp(other, 0);
      expect(r.lift, base.lift);
      expect(r.liftCurve, base.liftCurve);
      expect(r.reorder, base.reorder);
      expect(r.dragScale, base.dragScale);
      expect(r.dragTiltTurns, base.dragTiltTurns);
    });

    test('lerp 1 equals other', () {
      final r = base.lerp(other, 1);
      expect(r.lift, other.lift);
      expect(r.liftCurve, other.liftCurve);
      expect(r.reorder, other.reorder);
      expect(r.reorderCurve, other.reorderCurve);
      expect(r.dragScale, other.dragScale);
      expect(r.dragTiltTurns, other.dragTiltTurns);
    });

    test('curves snap at 0.5', () {
      expect(base.lerp(other, 0.49).liftCurve, base.liftCurve);
      expect(base.lerp(other, 0.5).liftCurve, other.liftCurve);
      expect(base.lerp(other, 0.49).reorderCurve, base.reorderCurve);
      expect(base.lerp(other, 0.5).reorderCurve, other.reorderCurve);
    });

    test('numeric fields interpolate', () {
      final r = base.lerp(other, 0.5);
      expect(r.dragScale, closeTo((base.dragScale + 2) / 2, 0.0001));
      expect(
        r.lift.inMicroseconds,
        closeTo((base.lift.inMicroseconds + other.lift.inMicroseconds) / 2, 1),
      );
    });

    test('tilt is minus 3 degrees', () {
      expect(base.dragTiltTurns * 360, closeTo(-3, 0.0001));
    });
  });

  group('resolveMotion', () {
    const duration = Duration(milliseconds: 150);

    Future<Duration> resolve(
      WidgetTester tester, {
      required bool disable,
    }) async {
      late Duration result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disable),
          child: Builder(
            builder: (context) {
              result = resolveMotion(context, duration);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('zero when animations disabled', (tester) async {
      expect(await resolve(tester, disable: true), Duration.zero);
    });

    testWidgets('unchanged when animations enabled', (tester) async {
      expect(await resolve(tester, disable: false), duration);
    });
  });
}
