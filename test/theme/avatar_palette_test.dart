import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHex', () {
    test('accepts #RRGGBB', () {
      expect(CardoAvatarPalette.parseHex('#2D68F5'), const Color(0xFF2D68F5));
    });

    test('accepts RRGGBB', () {
      expect(CardoAvatarPalette.parseHex('2D68F5'), const Color(0xFF2D68F5));
    });

    test('accepts lowercase and surrounding whitespace', () {
      expect(CardoAvatarPalette.parseHex(' #7c4deb '), const Color(0xFF7C4DEB));
    });

    test('returns null for garbage', () {
      for (final value in <String?>[
        null,
        '',
        '#',
        'zzzzzz',
        '#12345',
        '#1234567',
        '#GGGGGG',
        'not a color',
        '##2D68F5',
        '#2F6B FF',
        '0x2D68F5',
      ]) {
        expect(CardoAvatarPalette.parseHex(value), isNull, reason: '$value');
      }
    });

    test('result is fully opaque', () {
      expect(CardoAvatarPalette.parseHex('000000')!.a, 1);
    });
  });

  group('choices', () {
    test('has five parsable colors', () {
      expect(CardoAvatarPalette.choices.length, 5);
      for (final hex in CardoAvatarPalette.choices) {
        expect(CardoAvatarPalette.parseHex(hex), isNotNull);
      }
    });
  });

  group('darkAccentFor', () {
    test('table values', () {
      expect(
        CardoAvatarPalette.darkAccentFor(const Color(0xFF2D68F5)),
        const Color(0xFF6E97FF),
      );
      expect(
        CardoAvatarPalette.darkAccentFor(const Color(0xFF13804F)),
        const Color(0xFF2FBF7F),
      );
      expect(
        CardoAvatarPalette.darkAccentFor(const Color(0xFF7C4DEB)),
        const Color(0xFF9B7BFF),
      );
      expect(
        CardoAvatarPalette.darkAccentFor(const Color(0xFFD23A6E)),
        const Color(0xFFF0729B),
      );
      expect(
        CardoAvatarPalette.darkAccentFor(const Color(0xFFF2A516)),
        const Color(0xFFF2A516),
      );
    });

    test('unknown color is lightened', () {
      const unknown = Color(0xFF336699);
      final accent = CardoAvatarPalette.darkAccentFor(unknown);
      expect(
        HSLColor.fromColor(accent).lightness,
        greaterThan(HSLColor.fromColor(unknown).lightness),
      );
      expect(accent.a, 1);
    });

    test('unknown white stays valid', () {
      final accent = CardoAvatarPalette.darkAccentFor(const Color(0xFFFFFFFF));
      expect(accent.a, 1);
    });
  });

  group('resolve', () {
    const fallback = Color(0xFF5B616E);
    const fallbackAccent = Color(0xFF8A93A3);
    const light = Color(0xFFFFFFFF);
    const ink = Color(0xFF111318);

    AvatarSwatch run(String? hex, Brightness brightness) {
      return CardoAvatarPalette.resolve(
        hex: hex,
        brightness: brightness,
        fallback: fallback,
        fallbackAccent: fallbackAccent,
        lightText: light,
        darkText: ink,
      );
    }

    test('light keeps accent equal to fill', () {
      final s = run('#7C4DEB', Brightness.light);
      expect(s.fill, const Color(0xFF7C4DEB));
      expect(s.accent, s.fill);
    });

    test('dark uses lighter accent', () {
      final s = run('#7C4DEB', Brightness.dark);
      expect(s.fill, const Color(0xFF7C4DEB));
      expect(s.accent, const Color(0xFF9B7BFF));
    });

    test('unknown hex falls back', () {
      for (final b in Brightness.values) {
        expect(run('garbage', b).fill, fallback);
        expect(run(null, b).fill, fallback);
      }
    });

    test('unknown hex uses explicit fallback accent', () {
      for (final b in Brightness.values) {
        expect(run(null, b).accent, fallbackAccent);
        expect(run('garbage', b).accent, fallbackAccent);
      }
    });

    test('amber gets ink text, others white', () {
      expect(run('#F2A516', Brightness.light).onFill, ink);
      expect(run('#13804F', Brightness.light).onFill, light);
    });

    test('equality', () {
      expect(run('#7C4DEB', Brightness.dark), run('#7C4DEB', Brightness.dark));
      expect(
        run('#7C4DEB', Brightness.dark).hashCode,
        run('#7C4DEB', Brightness.dark).hashCode,
      );
      expect(
        run('#7C4DEB', Brightness.dark) == run('#13804F', Brightness.dark),
        isFalse,
      );
    });
  });

  group('readableOn', () {
    test('picks the higher contrast', () {
      const light = Color(0xFFFFFFFF);
      const ink = Color(0xFF111318);
      expect(
        CardoAvatarPalette.readableOn(
          const Color(0xFF000000),
          lightText: light,
          darkText: ink,
        ),
        light,
      );
      expect(
        CardoAvatarPalette.readableOn(
          const Color(0xFFFFFFFF),
          lightText: light,
          darkText: ink,
        ),
        ink,
      );
    });
  });
}
