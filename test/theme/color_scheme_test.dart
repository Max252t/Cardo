import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <String, (ThemeData, CardoColors)>{
    'light': (buildLightTheme(), CardoColors.light),
    'dark': (buildDarkTheme(), CardoColors.dark),
  };

  cases.forEach((name, value) {
    final (theme, c) = value;
    group('ColorScheme $name', () {
      final scheme = theme.colorScheme;

      test('brightness', () {
        expect(scheme.brightness, c.brightness);
      });

      test('key roles map to CardoColors slots', () {
        expect(scheme.primary, c.emphasis);
        expect(scheme.onPrimary, c.onEmphasis);
        expect(scheme.secondary, c.accent);
        expect(scheme.onSecondary, c.onAccent);
        expect(scheme.surface, c.surface);
        expect(scheme.onSurface, c.textPrimary);
        expect(scheme.onSurfaceVariant, c.textSecondary);
        expect(scheme.outline, c.lineStrong);
        expect(scheme.outlineVariant, c.line);
        expect(scheme.error, c.nackText);
        expect(scheme.errorContainer, c.nackBackground);
        expect(scheme.inverseSurface, c.snackbarBackground);
        expect(scheme.onInverseSurface, c.snackbarText);
        expect(scheme.surfaceTint, Colors.transparent);
      });

      test('is not generated from a seed', () {
        final seeded = ColorScheme.fromSeed(
          seedColor: c.accent,
          brightness: c.brightness,
        );
        expect(scheme.primary, isNot(seeded.primary));
        expect(scheme.surface, isNot(seeded.surface));
        expect(scheme.primaryContainer, isNot(seeded.primaryContainer));
      });

      test('all container roles are opaque', () {
        final containers = <String, Color>{
          'primaryContainer': scheme.primaryContainer,
          'secondaryContainer': scheme.secondaryContainer,
          'tertiaryContainer': scheme.tertiaryContainer,
          'errorContainer': scheme.errorContainer,
          'surfaceContainerLowest': scheme.surfaceContainerLowest,
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };
        containers.forEach((role, color) {
          expect(color.a, 1.0, reason: role);
        });
      });

      test('secondaryContainer is the selection fill', () {
        expect(scheme.secondaryContainer, c.selectionFill);
        expect(
          CardoAvatarPalette.contrastRatio(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('scaffold and canvas follow slots', () {
        expect(theme.scaffoldBackgroundColor, c.background);
        expect(theme.canvasColor, c.surface);
      });

      test('uses material 3', () {
        expect(theme.useMaterial3, isTrue);
      });
    });
  });

  test('selection fill matches the design sidebar values', () {
    expect(CardoColors.light.selectionFill, CardoColors.light.column);
    expect(CardoColors.dark.selectionFill, const Color(0xFF23252D));
  });

  group('component themes', () {
    test('filled button uses emphasis colors', () {
      final style = buildLightTheme().filledButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        CardoColors.light.emphasis,
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        CardoColors.light.onEmphasis,
      );
    });

    test('buttons have a tap target of at least 44', () {
      for (final theme in <ThemeData>[buildLightTheme(), buildDarkTheme()]) {
        expect(
          theme.filledButtonTheme.style!.minimumSize!
              .resolve(<WidgetState>{})!
              .height,
          greaterThanOrEqualTo(44),
        );
        expect(
          theme.outlinedButtonTheme.style!.minimumSize!
              .resolve(<WidgetState>{})!
              .height,
          greaterThanOrEqualTo(44),
        );
      }
    });

    test('snackbar uses snackbar slots', () {
      final dark = buildDarkTheme().snackBarTheme;
      expect(dark.backgroundColor, CardoColors.dark.snackbarBackground);
      expect(dark.actionTextColor, CardoColors.dark.snackbarActionText);
    });

    test('text theme uses Geist family', () {
      expect(
        buildLightTheme().textTheme.bodyMedium!.fontFamily,
        CardoFonts.geist,
      );
    });
  });
}
