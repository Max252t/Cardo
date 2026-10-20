import 'package:flutter/material.dart';

Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;

@immutable
class ConnectionSwatch {
  const ConnectionSwatch({
    required this.background,
    required this.foreground,
    required this.glyph,
    required this.compactForeground,
    required this.compactGlyph,
  });

  final Color background;
  final Color foreground;
  final Color glyph;
  final Color compactForeground;
  final Color compactGlyph;

  ConnectionSwatch copyWith({
    Color? background,
    Color? foreground,
    Color? glyph,
    Color? compactForeground,
    Color? compactGlyph,
  }) {
    return ConnectionSwatch(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      glyph: glyph ?? this.glyph,
      compactForeground: compactForeground ?? this.compactForeground,
      compactGlyph: compactGlyph ?? this.compactGlyph,
    );
  }

  static ConnectionSwatch lerp(
    ConnectionSwatch a,
    ConnectionSwatch b,
    double t,
  ) {
    return ConnectionSwatch(
      background: lerpColor(a.background, b.background, t),
      foreground: lerpColor(a.foreground, b.foreground, t),
      glyph: lerpColor(a.glyph, b.glyph, t),
      compactForeground: lerpColor(a.compactForeground, b.compactForeground, t),
      compactGlyph: lerpColor(a.compactGlyph, b.compactGlyph, t),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionSwatch &&
        other.background == background &&
        other.foreground == foreground &&
        other.glyph == glyph &&
        other.compactForeground == compactForeground &&
        other.compactGlyph == compactGlyph;
  }

  @override
  int get hashCode => Object.hash(
    background,
    foreground,
    glyph,
    compactForeground,
    compactGlyph,
  );
}

@immutable
class AvatarSwatch {
  const AvatarSwatch({
    required this.fill,
    required this.onFill,
    required this.accent,
    required this.onAccent,
  });

  final Color fill;
  final Color onFill;
  final Color accent;
  final Color onAccent;

  @override
  bool operator ==(Object other) {
    return other is AvatarSwatch &&
        other.fill == fill &&
        other.onFill == onFill &&
        other.accent == accent &&
        other.onAccent == onAccent;
  }

  @override
  int get hashCode => Object.hash(fill, onFill, accent, onAccent);
}
