import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/cardo_app.dart';
import 'core/config/app_config.dart';
import 'shared/providers/app_config_provider.dart';
import 'theme/cardo_theme.dart';

export 'app/cardo_app.dart' show CardoApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CardoFontLicenses.register();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
      ],
      child: const CardoApp(),
    ),
  );
}
