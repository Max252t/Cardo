import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrapApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1.0,
}) {
  return MaterialApp(
    themeAnimationDuration: Duration.zero,
    theme: brightness == Brightness.light
        ? buildLightTheme()
        : buildDarkTheme(),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      );
    },
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    wrapApp(
      child,
      brightness: brightness,
      disableAnimations: disableAnimations,
      textScale: textScale,
    ),
  );
  await tester.pump();
}
