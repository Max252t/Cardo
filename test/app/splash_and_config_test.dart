import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_server.dart';
import '../helpers/pump_cardo_app.dart';

const String refreshKey = 'POST /api/auth/refresh';

void main() {
  group('splash while restoring', () {
    for (final variant in allVariants) {
      testWidgets('renders for $variant', (tester) async {
        final server = FakeServer();
        server.gate(refreshKey);
        await pumpCardoApp(tester, server: server, variant: variant);

        expect(find.text(variant.l10n.splashRestoring), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the splash and hides the login until restored', (
      tester,
    ) async {
      final server = FakeServer();
      final gate = server.gate(refreshKey);
      final app = await pumpCardoApp(tester, server: server);

      expect(app.location, startsWith('/splash'));
      expect(find.text(app.l10n.loginTitle), findsNothing);
      expect(app.container.read(sessionProvider), const SessionRestoring());

      gate.complete();
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(find.text(app.l10n.splashRestoring), findsNothing);
    });

    testWidgets('no stored session goes straight to the login', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      expect(app.location, '/login');
      expect(app.server.count(refreshKey), 0);
    });
  });

  group('splash when the server is unavailable', () {
    FakeServer offline() {
      return FakeServer()..on(
        refreshKey,
        FakeResponse.network(DioExceptionType.connectionError),
      );
    }

    for (final variant in allVariants) {
      testWidgets('renders for $variant', (tester) async {
        await pumpCardoApp(tester, server: offline(), variant: variant);

        expect(find.text(variant.l10n.splashUnavailableTitle), findsOneWidget);
        expect(find.text(variant.l10n.commonRetry), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows the retry button and keeps the credential', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, server: offline());

      expect(app.container.read(sessionProvider), const SessionUnavailable());
      expect(app.location, startsWith('/splash'));
      expect(app.store.current?.token, 'stored-refresh');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Retry restores once the server is back', (tester) async {
      final server = offline();
      final app = await pumpCardoApp(tester, server: server);

      server.clear(refreshKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(app.container.read(sessionProvider), isA<SessionSignedIn>());
      expect(app.location, '/boards');
      expect(server.count(refreshKey), 2);
    });

    testWidgets('Retry while still offline stays on the splash', (
      tester,
    ) async {
      final server = offline();
      final app = await pumpCardoApp(tester, server: server);

      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(app.container.read(sessionProvider), const SessionUnavailable());
      expect(find.text(app.l10n.splashUnavailableTitle), findsOneWidget);
      expect(server.count(refreshKey), 2);
    });

    testWidgets('Retry shows the progress state while it runs', (tester) async {
      final server = offline();
      final app = await pumpCardoApp(tester, server: server);
      server.clear(refreshKey);
      final gate = server.gate(refreshKey);

      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester, 2);

      expect(find.text(app.l10n.splashRestoring), findsOneWidget);

      gate.complete();
      await pumpFrames(tester);
    });

    testWidgets('a server error on refresh is unavailable too', (tester) async {
      final server = FakeServer()
        ..on(refreshKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(tester, server: server);

      expect(app.container.read(sessionProvider), const SessionUnavailable());
    });

    testWidgets('/api/me failing after a good refresh is unavailable', (
      tester,
    ) async {
      final server = FakeServer()
        ..on('GET /api/me', FakeResponse.error(503, 'busy'));
      final app = await pumpCardoApp(tester, server: server);

      expect(app.container.read(sessionProvider), const SessionUnavailable());
    });

    testWidgets('English texts', (tester) async {
      await pumpCardoApp(tester, server: offline(), variant: enPhone);

      expect(find.text("Couldn't connect"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('config screen', () {
    for (final variant in allVariants) {
      testWidgets('renders for an empty value in $variant', (tester) async {
        await pumpCardoApp(tester, variant: variant, config: '');

        expect(find.text(variant.l10n.configTitle), findsOneWidget);
        expect(find.text(variant.l10n.configValueEmpty), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('renders for a bad value in $variant', (tester) async {
        await pumpCardoApp(tester, variant: variant, config: 'ftp://nope');

        expect(find.text('ftp://nope'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an empty value routes everything to /config', (tester) async {
      final app = await pumpCardoApp(tester, config: '');

      expect(app.location, '/config');
      expect(app.server.adapter.requests, isEmpty);
      expect(app.container.read(sessionProvider), const SessionSignedOut());

      for (final path in <String>[
        '/login',
        '/boards',
        '/profile',
        '/boards/1',
      ]) {
        app.router.go(path);
        await pumpFrames(tester, 3);
        expect(app.location, '/config', reason: path);
      }
    });

    testWidgets('the demo button shows only for an empty value (debug)', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, config: '');

      expect(find.text(app.l10n.configOpenDemo), findsOneWidget);
    });

    testWidgets('a non-empty bad value has no demo button', (tester) async {
      final app = await pumpCardoApp(tester, config: 'localhost:8080');

      expect(find.text(app.l10n.configOpenDemo), findsNothing);
      expect(find.text('localhost:8080'), findsOneWidget);
    });

    testWidgets('a whitespace-only value counts as empty', (tester) async {
      final app = await pumpCardoApp(tester, config: '   ');

      expect(find.text(app.l10n.configValueEmpty), findsOneWidget);
      expect(find.text(app.l10n.configOpenDemo), findsOneWidget);
    });

    testWidgets('the demo button opens the demo board without network', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, config: '');

      await tester.tap(find.text(app.l10n.configOpenDemo));
      await pumpFrames(tester);

      expect(app.location, '/demo');
      expect(find.byType(BoardScreen), findsOneWidget);
      expect(app.server.adapter.requests, isEmpty);
    });

    testWidgets('back from the demo returns to the config', (tester) async {
      final app = await pumpCardoApp(tester, config: '');
      await tester.tap(find.text(app.l10n.configOpenDemo));
      await pumpFrames(tester);

      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/config');
    });

    testWidgets('a valid config makes /config unreachable', (tester) async {
      final app = await pumpCardoApp(tester, signedIn: false);

      app.router.go('/config');
      await pumpFrames(tester, 3);

      expect(app.location, '/login');
    });

    testWidgets('the English texts', (tester) async {
      await pumpCardoApp(tester, variant: enPhone, config: '');

      expect(find.text(AppLocalizationsEn().configTitle), findsOneWidget);
      expect(find.text('Open demo board'), findsOneWidget);
      expect(find.text('not set'), findsOneWidget);
      expect(
        find.textContaining('--dart-define-from-file=env/local.json'),
        findsOneWidget,
      );
    });
  });
}
