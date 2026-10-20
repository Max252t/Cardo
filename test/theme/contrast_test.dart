import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Pair {
  const Pair(this.name, this.fg, this.bg, {this.min = 4.5});

  final String name;
  final Color fg;
  final Color bg;
  final double min;
}

const Set<String> decorativeTokensDuplicatedByShapeOrLabel = <String>{
  'outlineMuted',
};

List<Pair> pairsFor(CardoColors c) {
  final backgrounds = <String, Color>{
    'background': c.background,
    'surface': c.surface,
    'card': c.card,
    'column': c.column,
  };
  final pairs = <Pair>[];
  backgrounds.forEach((name, bg) {
    pairs.add(Pair('textPrimary on $name', c.textPrimary, bg));
    pairs.add(Pair('textSoft on $name', c.textSoft, bg));
  });
  pairs
    ..add(Pair('textSecondary on surface', c.textSecondary, c.surface))
    ..add(Pair('textSecondary on card', c.textSecondary, c.card))
    ..add(Pair('textSecondary on column', c.textSecondary, c.column))
    ..add(Pair('textSecondary on background', c.textSecondary, c.background))
    ..add(Pair('onEmphasis on emphasis', c.onEmphasis, c.emphasis))
    ..add(Pair('onAccent on accent', c.onAccent, c.accent))
    ..add(Pair('nackText on nackBackground', c.nackText, c.nackBackground))
    ..add(Pair('nackText on card', c.nackText, c.card))
    ..add(
      Pair(
        'textSecondary on nackBackground',
        c.textSecondary,
        c.nackBackground,
      ),
    )
    ..add(
      Pair(
        'conflictTitle on conflictBackground',
        c.conflictTitle,
        c.conflictBackground,
      ),
    )
    ..add(
      Pair(
        'conflictText on conflictBackground',
        c.conflictText,
        c.conflictBackground,
      ),
    )
    ..add(
      Pair(
        'snackbarText on snackbarBackground',
        c.snackbarText,
        c.snackbarBackground,
      ),
    )
    ..add(
      Pair(
        'snackbarActionText on snackbarAction',
        c.snackbarActionText,
        c.snackbarAction,
      ),
    )
    ..add(
      Pair(
        'snackbarIcon on snackbarBackground',
        c.snackbarIcon,
        c.snackbarBackground,
        min: 3,
      ),
    )
    ..add(
      Pair(
        'roleViewerText on roleViewerBackground',
        c.roleViewerText,
        c.roleViewerBackground,
      ),
    )
    ..add(Pair('textPrimary on card (editor badge)', c.textPrimary, c.card))
    ..add(
      Pair(
        'avatarOverflowText on avatarOverflowBackground',
        c.avatarOverflowText,
        c.avatarOverflowBackground,
      ),
    )
    ..add(Pair('textSecondary on field', c.textSecondary, c.field))
    ..add(Pair('textPrimary on field', c.textPrimary, c.field))
    ..add(Pair('dragBorder on card', c.dragBorder, c.card, min: 3))
    ..add(Pair('tabActiveCount on emphasis', c.tabActiveCount, c.emphasis))
    ..add(
      Pair('textSecondary on sidebarField', c.textSecondary, c.sidebarField),
    )
    ..add(Pair('textPrimary on sidebarField', c.textPrimary, c.sidebarField));
  final swatches = <String, ConnectionSwatch>{
    'connected': c.connected,
    'syncing': c.syncing,
    'reconnecting': c.reconnecting,
    'offline': c.offline,
  };
  swatches.forEach((name, s) {
    pairs
      ..add(Pair('$name foreground on pill', s.foreground, s.background))
      ..add(Pair('$name glyph on pill', s.glyph, s.background, min: 3))
      ..add(
        Pair(
          '$name compactForeground on background',
          s.compactForeground,
          c.background,
        ),
      )
      ..add(
        Pair(
          '$name compactForeground on surface',
          s.compactForeground,
          c.surface,
        ),
      )
      ..add(
        Pair(
          '$name compactGlyph on background',
          s.compactGlyph,
          c.background,
          min: 3,
        ),
      )
      ..add(
        Pair(
          '$name compactGlyph on surface',
          s.compactGlyph,
          c.surface,
          min: 3,
        ),
      );
  });
  final avatarColors = <String?>[...CardoAvatarPalette.choices, null];
  for (final hex in avatarColors) {
    final s = c.avatarSwatch(hex);
    pairs
      ..add(
        Pair('avatar ${hex ?? 'fallback'} onFill on fill', s.onFill, s.fill),
      )
      ..add(
        Pair(
          'avatar ${hex ?? 'fallback'} onAccent on accent',
          s.onAccent,
          s.accent,
        ),
      );
  }
  return pairs;
}

void main() {
  final themes = <String, CardoColors>{
    'light': CardoColors.light,
    'dark': CardoColors.dark,
  };

  themes.forEach((themeName, colors) {
    group('contrast $themeName', () {
      for (final pair in pairsFor(colors)) {
        test('${pair.name} >= ${pair.min}', () {
          final ratio = CardoAvatarPalette.contrastRatio(pair.fg, pair.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(pair.min),
            reason:
                '$themeName: ${pair.name} = ${ratio.toStringAsFixed(2)} (min ${pair.min})',
          );
        });
      }

      test('decorative tokens are not among checked pairs', () {
        final checkedTokens = <String>{
          for (final pair in pairsFor(colors)) ...pair.name.split(' '),
        };
        expect(
          checkedTokens.intersection(decorativeTokensDuplicatedByShapeOrLabel),
          isEmpty,
        );
      });
    });
  });

  group('contrastRatio', () {
    test('black on white is 21', () {
      expect(
        CardoAvatarPalette.contrastRatio(
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ),
        closeTo(21, 0.001),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF2D68F5);
      const b = Color(0xFF111318);
      expect(
        CardoAvatarPalette.contrastRatio(a, b),
        CardoAvatarPalette.contrastRatio(b, a),
      );
    });

    test('same color is 1', () {
      const a = Color(0xFF2D68F5);
      expect(CardoAvatarPalette.contrastRatio(a, a), closeTo(1, 0.0001));
    });
  });
}
