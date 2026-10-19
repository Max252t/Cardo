import 'package:flutter/material.dart';

import 'features/design_preview/design_system_preview.dart';
import 'l10n/app_localizations.dart';
import 'theme/cardo_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CardoFontLicenses.register();
  runApp(const CardoApp());
}

class CardoApp extends StatelessWidget {
  const CardoApp({super.key, this.home = const DesignSystemPreview()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      themeAnimationStyle: AnimationStyle.noAnimation,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
