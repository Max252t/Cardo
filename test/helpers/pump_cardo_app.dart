import 'package:cardo/app/app_router.dart';
import 'package:cardo/app/cardo_app.dart';
import 'package:cardo/core/config/app_config.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/presentation/realtime_providers.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/shared/providers/app_config_provider.dart';
import 'package:cardo/shared/time/now_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'api_json.dart';
import 'fake_server.dart';
import 'hanging_transport.dart';
import 'memory_token_store.dart';

const Size compactPhone = Size(375, 812);
const Size expandedDesktop = Size(1280, 800);

class Variant {
  const Variant(this.locale, this.size, this.textScale);

  final Locale locale;
  final Size size;
  final double textScale;

  AppLocalizations get l10n => lookupAppLocalizations(locale);

  @override
  String toString() =>
      '${locale.languageCode} ${size.width.toInt()}px x$textScale';
}

final List<Variant> allVariants = <Variant>[
  for (final locale in const <Locale>[Locale('ru'), Locale('en')])
    for (final size in const <Size>[compactPhone, expandedDesktop])
      for (final scale in const <double>[1, 2]) Variant(locale, size, scale),
];

const Variant ruPhone = Variant(Locale('ru'), Size(375, 812), 1);
const Variant enPhone = Variant(Locale('en'), Size(375, 812), 1);
const Variant ruDesktop = Variant(Locale('ru'), Size(1280, 800), 1);
const Variant enDesktop = Variant(Locale('en'), Size(1280, 800), 1);

final DateTime appNow = t0.add(const Duration(hours: 2));

class AppHandle {
  AppHandle(this.container, this.server, this.store, this.variant);

  final ProviderContainer container;
  final FakeServer server;
  final MemoryTokenStore store;
  final Variant variant;

  AppLocalizations get l10n => variant.l10n;

  GoRouter get router => container.read(routerProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

RefreshCredential validCredential() {
  return RefreshCredential(
    token: 'stored-refresh',
    expiresAt: appNow.add(const Duration(days: 20)),
  );
}

Future<void> pumpFrames(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppHandle> pumpCardoApp(
  WidgetTester tester, {
  FakeServer? server,
  Variant variant = ruPhone,
  bool signedIn = true,
  String config = 'http://api.test',
  String? openLocation,
  bool settle = true,
  DateTime Function()? clock,
  RefreshCredential? credential,
  RealtimeTransport? transport,
}) async {
  final fake = server ?? FakeServer();
  final store = MemoryTokenStore(
    signedIn ? (credential ?? validCredential()) : null,
  );
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = <Locale>[variant.locale];
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.parse(config)),
        dioAdapterProvider.overrideWithValue(fake.adapter),
        tokenStoreProvider.overrideWithValue(store),
        realtimeTransportProvider.overrideWithValue(
          transport ?? HangingTransport(),
        ),
        nowProvider.overrideWithValue(clock ?? () => appNow),
      ],
      child: const CardoApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CardoApp)),
  );
  final handle = AppHandle(container, fake, store, variant);
  if (settle) {
    await pumpFrames(tester);
  }
  if (openLocation != null) {
    handle.router.go(openLocation);
    await pumpFrames(tester);
  }
  return handle;
}

Future<void> enterAt(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextFormField).at(index), text);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}
