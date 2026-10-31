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
    required this.columnTitle,
    required this.columnTitleDense,
    required this.sheetTitle,
    required this.sheetField,
    required this.bannerText,
    required this.panelField,
    required this.tab,
    required this.avatarInitialSteps,
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
    columnTitle: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.35,
    ),
    columnTitleDense: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.35,
    ),
    sheetTitle: TextStyle(
      fontFamily: CardoFonts.bricolage,
      fontFamilyFallback: CardoFonts.bricolageFallback,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.52,
      height: 1.12,
    ),
    sheetField: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.55,
    ),
    bannerText: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.45,
    ),
    panelField: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.6,
    ),
    tab: TextStyle(
      fontFamily: CardoFonts.geist,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.3,
    ),
    avatarInitialSteps: <AvatarInitialStep>[
      AvatarInitialStep(maxDiameter: 22, fontSize: 11),
      AvatarInitialStep(maxDiameter: 30, fontSize: 12),
      AvatarInitialStep(maxDiameter: 34, fontSize: 13),
      AvatarInitialStep(maxDiameter: double.infinity, fontSize: 14),
    ],
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
  final TextStyle columnTitle;
  final TextStyle columnTitleDense;
  final TextStyle sheetTitle;
  final TextStyle sheetField;
  final TextStyle bannerText;
  final TextStyle panelField;
  final TextStyle tab;
  final List<AvatarInitialStep> avatarInitialSteps;

  static CardoTypography of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoTypography>();
    assert(
      extension != null,
      'CardoTypography missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  TextStyle columnTitleFor({required bool dense}) =>
      dense ? columnTitleDense : columnTitle;

  double avatarInitialSize(double diameter) {
    for (final step in avatarInitialSteps) {
      if (diameter <= step.maxDiameter) {
        return step.fontSize;
      }
    }
    return avatarInitialSteps.last.fontSize;
  }

  TextStyle avatarInitial(double diameter) {
    return label.copyWith(fontSize: avatarInitialSize(diameter), height: 1);
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
    TextStyle? columnTitle,
    TextStyle? columnTitleDense,
    TextStyle? sheetTitle,
    TextStyle? sheetField,
    TextStyle? bannerText,
    TextStyle? panelField,
    TextStyle? tab,
    List<AvatarInitialStep>? avatarInitialSteps,
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
      columnTitle: columnTitle ?? this.columnTitle,
      columnTitleDense: columnTitleDense ?? this.columnTitleDense,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      sheetField: sheetField ?? this.sheetField,
      bannerText: bannerText ?? this.bannerText,
      panelField: panelField ?? this.panelField,
      tab: tab ?? this.tab,
      avatarInitialSteps: avatarInitialSteps ?? this.avatarInitialSteps,
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
      columnTitle: s(columnTitle, other.columnTitle),
      columnTitleDense: s(columnTitleDense, other.columnTitleDense),
      sheetTitle: s(sheetTitle, other.sheetTitle),
      sheetField: s(sheetField, other.sheetField),
      bannerText: s(bannerText, other.bannerText),
      panelField: s(panelField, other.panelField),
      tab: s(tab, other.tab),
      avatarInitialSteps: t < 0.5
          ? avatarInitialSteps
          : other.avatarInitialSteps,
    );
  }
}

@immutable
class AvatarInitialStep {
  const AvatarInitialStep({required this.maxDiameter, required this.fontSize});

  final double maxDiameter;
  final double fontSize;

  @override
  bool operator ==(Object other) {
    return other is AvatarInitialStep &&
        other.maxDiameter == maxDiameter &&
        other.fontSize == fontSize;
  }

  @override
  int get hashCode => Object.hash(maxDiameter, fontSize);
}
