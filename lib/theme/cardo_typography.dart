import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

abstract final class CardoFonts {
  static const String bricolage = 'BricolageGrotesque';
  static const String geist = 'Geist';
  static const String geistMono = 'GeistMono';

  static const List<String> bricolageFallback = <String>[geist];
}

@immutable
class CardoTypography extends ThemeExtension<CardoTypography> {
  const CardoTypography({
    required this.display,
    required this.title,
    required this.titleLarge,
    required this.cardTitle,
    required this.logo,
    required this.logoLarge,
    required this.body,
    required this.bodyDense,
    required this.paragraph,
    required this.message,
    required this.button,
    required this.buttonCompact,
    required this.buttonSmall,
    required this.label,
    required this.pill,
    required this.caption,
    required this.captionLarge,
    required this.tag,
    required this.overline,
    required this.mono,
    required this.avatarInitialRatio,
    required this.avatarInitialMin,
  });

  static const CardoTypography standard = CardoTypography(
    display: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.05,
    ),
    title: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.1,
    ),
    titleLarge: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.52,
      height: 1.1,
    ),
    cardTitle: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.48,
      height: 1.12,
    ),
    logo: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.88,
      height: 1,
    ),
    logoLarge: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.76,
      height: 1,
    ),
    body: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.35,
    ),
    bodyDense: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.35,
    ),
    paragraph: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.55,
    ),
    message: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.4,
    ),
    button: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    buttonCompact: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    buttonSmall: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    label: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.4,
    ),
    pill: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
    ),
    caption: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
    ),
    captionLarge: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
    ),
    tag: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.4,
    ),
    overline: TextStyle(
      fontFamily: CardoFonts.geistMono,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.96,
      height: 1.4,
    ),
    mono: TextStyle(
      fontFamily: CardoFonts.geistMono,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.4,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    avatarInitialRatio: 0.4,
    avatarInitialMin: 10,
  );

  final TextStyle display;
  final TextStyle title;
  final TextStyle titleLarge;
  final TextStyle cardTitle;
  final TextStyle logo;
  final TextStyle logoLarge;
  final TextStyle body;
  final TextStyle bodyDense;
  final TextStyle paragraph;
  final TextStyle message;
  final TextStyle button;
  final TextStyle buttonCompact;
  final TextStyle buttonSmall;
  final TextStyle label;
  final TextStyle pill;
  final TextStyle caption;
  final TextStyle captionLarge;
  final TextStyle tag;
  final TextStyle overline;
  final TextStyle mono;
  final double avatarInitialRatio;
  final double avatarInitialMin;

  static CardoTypography of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoTypography>();
    assert(
      extension != null,
      'CardoTypography missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  TextStyle avatarInitial(double diameter) {
    return label.copyWith(
      fontSize: math.max(
        avatarInitialMin,
        (diameter * avatarInitialRatio).roundToDouble(),
      ),
      height: 1,
    );
  }

  @override
  CardoTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? titleLarge,
    TextStyle? cardTitle,
    TextStyle? logo,
    TextStyle? logoLarge,
    TextStyle? body,
    TextStyle? bodyDense,
    TextStyle? paragraph,
    TextStyle? message,
    TextStyle? button,
    TextStyle? buttonCompact,
    TextStyle? buttonSmall,
    TextStyle? label,
    TextStyle? pill,
    TextStyle? caption,
    TextStyle? captionLarge,
    TextStyle? tag,
    TextStyle? overline,
    TextStyle? mono,
    double? avatarInitialRatio,
    double? avatarInitialMin,
  }) {
    return CardoTypography(
      display: display ?? this.display,
      title: title ?? this.title,
      titleLarge: titleLarge ?? this.titleLarge,
      cardTitle: cardTitle ?? this.cardTitle,
      logo: logo ?? this.logo,
      logoLarge: logoLarge ?? this.logoLarge,
      body: body ?? this.body,
      bodyDense: bodyDense ?? this.bodyDense,
      paragraph: paragraph ?? this.paragraph,
      message: message ?? this.message,
      button: button ?? this.button,
      buttonCompact: buttonCompact ?? this.buttonCompact,
      buttonSmall: buttonSmall ?? this.buttonSmall,
      label: label ?? this.label,
      pill: pill ?? this.pill,
      caption: caption ?? this.caption,
      captionLarge: captionLarge ?? this.captionLarge,
      tag: tag ?? this.tag,
      overline: overline ?? this.overline,
      mono: mono ?? this.mono,
      avatarInitialRatio: avatarInitialRatio ?? this.avatarInitialRatio,
      avatarInitialMin: avatarInitialMin ?? this.avatarInitialMin,
    );
  }

  @override
  CardoTypography lerp(
    covariant ThemeExtension<CardoTypography>? other,
    double t,
  ) {
    if (other is! CardoTypography) {
      return this;
    }
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t) ?? b;
    double d(double a, double b) => lerpDouble(a, b, t) ?? b;
    return CardoTypography(
      display: s(display, other.display),
      title: s(title, other.title),
      titleLarge: s(titleLarge, other.titleLarge),
      cardTitle: s(cardTitle, other.cardTitle),
      logo: s(logo, other.logo),
      logoLarge: s(logoLarge, other.logoLarge),
      body: s(body, other.body),
      bodyDense: s(bodyDense, other.bodyDense),
      paragraph: s(paragraph, other.paragraph),
      message: s(message, other.message),
      button: s(button, other.button),
      buttonCompact: s(buttonCompact, other.buttonCompact),
      buttonSmall: s(buttonSmall, other.buttonSmall),
      label: s(label, other.label),
      pill: s(pill, other.pill),
      caption: s(caption, other.caption),
      captionLarge: s(captionLarge, other.captionLarge),
      tag: s(tag, other.tag),
      overline: s(overline, other.overline),
      mono: s(mono, other.mono),
      avatarInitialRatio: d(avatarInitialRatio, other.avatarInitialRatio),
      avatarInitialMin: d(avatarInitialMin, other.avatarInitialMin),
    );
  }
}
