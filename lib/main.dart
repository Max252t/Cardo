import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/board/data/demo_board_fixture.dart';
import 'features/board/data/fake_board_gateway.dart';
import 'features/board/presentation/board_providers.dart';
import 'features/board/presentation/board_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/cardo_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CardoFontLicenses.register();
  runApp(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(
          FakeBoardGateway(
            initial: demoBoardSnapshot(now: DateTime.now()),
            confirmDelay: CardoDurations.syncConfirmDelay,
          ),
        ),
      ],
      child: const CardoApp(),
    ),
  );
}

class CardoApp extends StatelessWidget {
  const CardoApp({super.key, this.home = const BoardScreen()});

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
