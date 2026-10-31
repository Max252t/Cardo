import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../shared/locale/resolve_app_locale.dart';
import '../theme/cardo_theme.dart';
import 'app_router.dart';

class CardoApp extends ConsumerWidget {
  const CardoApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = this.home;
    if (home != null) {
      return MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        themeAnimationStyle: AnimationStyle.noAnimation,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolveAppLocale,
        debugShowCheckedModeBanner: false,
        home: home,
      );
    }
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      themeAnimationStyle: AnimationStyle.noAnimation,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveAppLocale,
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
