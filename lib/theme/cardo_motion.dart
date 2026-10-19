import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

Duration resolveMotion(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

@immutable
class CardoMotion extends ThemeExtension<CardoMotion> {
  const CardoMotion({
    required this.lift,
    required this.liftCurve,
    required this.reorder,
    required this.reorderCurve,
    required this.dragTiltTurns,
    required this.dragScale,
  });

  static const CardoMotion standard = CardoMotion(
    lift: Duration(milliseconds: 150),
    liftCurve: Curves.easeOut,
    reorder: Duration(milliseconds: 200),
    reorderCurve: Curves.easeOutCubic,
    dragTiltTurns: -3 / 360,
    dragScale: 1.02,
  );

  final Duration lift;
  final Curve liftCurve;
  final Duration reorder;
  final Curve reorderCurve;
  final double dragTiltTurns;
  final double dragScale;

  static CardoMotion of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoMotion>();
    assert(
      extension != null,
      'CardoMotion missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  @override
  CardoMotion copyWith({
    Duration? lift,
    Curve? liftCurve,
    Duration? reorder,
    Curve? reorderCurve,
    double? dragTiltTurns,
    double? dragScale,
  }) {
    return CardoMotion(
      lift: lift ?? this.lift,
      liftCurve: liftCurve ?? this.liftCurve,
      reorder: reorder ?? this.reorder,
      reorderCurve: reorderCurve ?? this.reorderCurve,
      dragTiltTurns: dragTiltTurns ?? this.dragTiltTurns,
      dragScale: dragScale ?? this.dragScale,
    );
  }

  @override
  CardoMotion lerp(covariant ThemeExtension<CardoMotion>? other, double t) {
    if (other is! CardoMotion) {
      return this;
    }
    final snap = t < 0.5;
    return CardoMotion(
      lift: _duration(lift, other.lift, t),
      liftCurve: snap ? liftCurve : other.liftCurve,
      reorder: _duration(reorder, other.reorder, t),
      reorderCurve: snap ? reorderCurve : other.reorderCurve,
      dragTiltTurns:
          lerpDouble(dragTiltTurns, other.dragTiltTurns, t) ??
          other.dragTiltTurns,
      dragScale: lerpDouble(dragScale, other.dragScale, t) ?? other.dragScale,
    );
  }

  static Duration _duration(Duration a, Duration b, double t) {
    final micros =
        a.inMicroseconds + ((b.inMicroseconds - a.inMicroseconds) * t).round();
    return Duration(microseconds: micros);
  }
}
