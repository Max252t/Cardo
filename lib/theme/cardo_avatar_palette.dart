import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cardo_primitives.dart';
import 'cardo_swatches.dart';

abstract final class CardoAvatarPalette {
  static const String blue = '#2D68F5';
  static const String green = '#13804F';
  static const String violet = '#7C4DEB';
  static const String pink = '#D23A6E';
  static const String amber = '#F2A516';

  static const List<String> choices = <String>[
    blue,
    green,
    violet,
    pink,
    amber,
  ];

  static final Map<Color, Color> _darkAccents = <Color, Color>{
    CardoPrimitives.blue2D68F5: CardoPrimitives.blue6E97FF,
    CardoPrimitives.green13804F: CardoPrimitives.green2FBF7F,
    CardoPrimitives.violet7C4DEB: CardoPrimitives.violet9B7BFF,
    CardoPrimitives.pinkD23A6E: CardoPrimitives.pinkF0729B,
    CardoPrimitives.amberF2A516: CardoPrimitives.amberF2A516,
  };

  static final RegExp _hexDigits = RegExp(r'^[0-9a-fA-F]{6}$');

  static const double _darkLightnessBoost = 0.13;
  static const double _darkSaturationBoost = 0.2;

  static Color? parseHex(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    final digits = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    if (!_hexDigits.hasMatch(digits)) {
      return null;
    }
    return Color(0xFF000000 | int.parse(digits, radix: 16));
  }

  static AvatarSwatch resolve({
    required String? hex,
    required Brightness brightness,
    required Color fallback,
    required Color fallbackAccent,
    required Color lightText,
    required Color darkText,
  }) {
    final parsed = parseHex(hex);
    final fill = parsed ?? fallback;
    final accent = switch (parsed) {
      null => fallbackAccent,
      final Color color when brightness == Brightness.dark => darkAccentFor(
        color,
      ),
      final Color color => color,
    };
    return AvatarSwatch(
      fill: fill,
      onFill: readableOn(fill, lightText: lightText, darkText: darkText),
      accent: accent,
      onAccent: readableOn(accent, lightText: lightText, darkText: darkText),
    );
  }

  static Color darkAccentFor(Color fill) {
    final known = _darkAccents[fill];
    if (known != null) {
      return known;
    }
    final hsl = HSLColor.fromColor(fill);
    return hsl
        .withLightness(math.min(1, hsl.lightness + _darkLightnessBoost))
        .withSaturation(math.min(1, hsl.saturation + _darkSaturationBoost))
        .toColor();
  }

  static Color readableOn(
    Color background, {
    required Color lightText,
    required Color darkText,
  }) {
    final light = contrastRatio(lightText, background);
    final dark = contrastRatio(darkText, background);
    return light >= dark ? lightText : darkText;
  }

  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }
}
