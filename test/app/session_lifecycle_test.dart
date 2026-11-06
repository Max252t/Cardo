import 'dart:async';

import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board_settings/presentation/self_exit.dart';
import 'package:cardo/features/boards/presentation/boards_providers.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_server.dart';
import '../helpers/pump_cardo_app.dart';

const String refreshKey = 'POST ${ApiPaths.refresh}';
const String logoutKey = 'POST ${ApiPaths.logout}';
const String listKey = 'GET ${ApiPaths.boards}';

Finder signOutButton(AppHandle app) =>
    find.widgetWithText(CardoSecondaryButton, app.l10n.profileSignOut);

Future<void> runRequests(
  WidgetTester tester,
  AppHandle app,
  int count, {
  bool parallel = false,
}) async {
  final api = app.container.read(boardsApiProvider);
  if (parallel) {
    final all = Future.wait([for (var i = 0; i < count; i++) api.listBoards()]);
    await pumpFrames(tester, 4);
    await all;
    return;
  }
  for (var i = 0; i < count; i++) {
    final one = api.listBoards();
    await pumpFrames(tester, 2);
    await one;
  }
}

RefreshCredential credentialFor(DateTime clock) {
  return RefreshCredential(
    token: 'stored-refresh',
    expiresAt: clock.add(const Duration(days: 20)),
  );
}

void main() {
  group('401 unauthorized with a sent access token', () {
    testWidgets('a protected request ends the session as expired', (
      tester,
    ) async {
      final server = FakeServer();
      final app = await pumpCardoApp(tester, server: server);
      expect(app.location, '/boards');
      final refreshesBefore = server.count(refreshKey);
      final reasons = <SignOutReason>[];
      final subscription = app.container
          .read(tokenManagerProvider)
          .sessionEnds
          .listen(reasons.add);
      addTearDown(subscription.cancel);

      server.on(listKey, FakeResponse.error(401, 'unauthorized'));
      app.container.invalidate(boardsListProvider);
      await pumpFrames(tester);

      expect(
        app.container.read(sessionProvider),
        const SessionSignedOut(reason: SignOutReason.expired),
      );
      expect(reasons, <SignOutReason>[SignOutReason.expired]);
      expect(app.location, '/login');
      expect(find.text(app.l10n.errorSessionExpired), findsOneWidget);
      expect(app.store.current, isNull);
      expect(server.count(refreshKey), refreshesBefore);
    });

    testWidgets('the banner is shown on the wide layout in English', (
      tester,
    ) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        variant: enDesktop,
      );

      server.on(listKey, FakeResponse.error(401, 'unauthorized'));
      app.container.invalidate(boardsListProvider);
      await pumpFrames(tester);

      expect(app.location, '/login');
      expect(find.text('Your session expired. Sign in again.'), findsOneWidget);
    });

    testWidgets('the next sign-in leaves the login screen', (tester) async {
      final server = FakeServer();
      final app = await pumpCardoApp(tester, server: server);
      server.on(listKey, FakeResponse.error(401, 'unauthorized'));
      app.container.invalidate(boardsListProvider);
      await pumpFrames(tester);
      expect(find.text(app.l10n.errorSessionExpired), findsOneWidget);

      server.clear(listKey);
      await enterAt(tester, 0, 'anna@example.com');
      await enterAt(tester, 1, 'secret-pass');
      await tester.tap(find.byType(CardoPrimaryButton));
      await pumpFrames(tester);

      expect(app.location, '/boards');
      expect(app.container.read(sessionProvider), isA<SessionSignedIn>());
    });
  });

  group('logout answered with 401 unauthorized', () {
    testWidgets('is a plain sign-out and never a forced one', (tester) async {
      final server = FakeServer()
        ..on(logoutKey, FakeResponse.error(401, 'unauthorized'));
      final app = await pumpCardoApp(tester, server: server);
      app.router.go('/profile');
      await pumpFrames(tester);
      final reasons = <SignOutReason>[];
      final subscription = app.container
          .read(tokenManagerProvider)
          .sessionEnds
          .listen(reasons.add);
      addTearDown(subscription.cancel);
      final states = <Session>[];
      app.container.listen(sessionProvider, (_, next) => states.add(next));

      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      expect(server.count(logoutKey), 1);
      expect(reasons, isEmpty);
      expect(
        states.whereType<SessionSignedOut>().map((state) => state.reason),
        everyElement(isNull),
      );
      expect(app.container.read(sessionProvider), const SessionSignedOut());
      expect(app.location, '/login');
      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
      expect(app.store.current, isNull);
    });
  });

  group('device clock far ahead of the server', () {
    final skewed = appNow.add(const Duration(minutes: 75));

    testWidgets('five sequential requests refresh at most once', (
      tester,
    ) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        clock: () => skewed,
        credential: credentialFor(skewed),
      );
      expect(server.count(refreshKey), 1);

      await runRequests(tester, app, 5);

      expect(server.count(refreshKey), lessThanOrEqualTo(1));
      final lists = server.requests(listKey);
      expect(lists.length, greaterThanOrEqualTo(5));
      expect(
        lists.skip(lists.length - 5).map((request) => request.authorization),
        everyElement('Bearer access-r1'),
      );
    });

    testWidgets('five parallel requests refresh at most once', (tester) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        clock: () => skewed,
        credential: credentialFor(skewed),
      );

      await runRequests(tester, app, 5, parallel: true);

      expect(server.count(refreshKey), lessThanOrEqualTo(1));
    });

    testWidgets('after a fresh sign-in no refresh is needed at all', (
      tester,
    ) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        signedIn: false,
        clock: () => skewed,
      );

      await enterAt(tester, 0, 'anna@example.com');
      await enterAt(tester, 1, 'secret-pass');
      await tester.tap(find.byType(CardoPrimaryButton));
      await pumpFrames(tester);
      expect(app.location, '/boards');
      await runRequests(tester, app, 5);

      expect(server.count(refreshKey), 0);
    });

    testWidgets('the local TTL still triggers one proactive refresh', (
      tester,
    ) async {
      var current = skewed;
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        clock: () => current,
        credential: credentialFor(skewed),
      );
      await runRequests(tester, app, 3);
      final before = server.count(refreshKey);

      current = skewed.add(const Duration(minutes: 14, seconds: 30));
      await runRequests(tester, app, 5);

      expect(server.count(refreshKey), before + 1);
    });
  });

  group('restoring with a locally expired refresh_expires_at', () {
    testWidgets('the session is restored when the server accepts', (
      tester,
    ) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        credential: RefreshCredential(
          token: 'stored-refresh',
          expiresAt: appNow.subtract(const Duration(days: 1)),
        ),
      );

      expect(server.requests(refreshKey).single.body, <String, Object?>{
        'refresh_token': 'stored-refresh',
      });
      expect(app.container.read(sessionProvider), isA<SessionSignedIn>());
      expect(app.location, '/boards');
      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
      expect(find.text(app.l10n.errorSessionReused), findsNothing);
      expect(app.store.current?.token, 'refresh-r1');
    });

    testWidgets('the server decides: a rejection still ends the session', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(refreshKey, FakeResponse.error(401, 'token_expired'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        credential: RefreshCredential(
          token: 'stored-refresh',
          expiresAt: appNow.subtract(const Duration(days: 1)),
        ),
      );

      expect(app.location, '/login');
      expect(find.text(app.l10n.errorSessionExpired), findsOneWidget);
      expect(app.store.current, isNull);
    });
  });

  group('sign-out with an almost expired access token', () {
    testWidgets('sends one logout without a refresh and clears everything', (
      tester,
    ) async {
      var current = appNow;
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        clock: () => current,
      );
      expect(server.count(refreshKey), 1);
      final manager = app.container.read(tokenManagerProvider);
      final refreshToken = manager.currentRefreshToken;
      final access = manager.currentAccessToken;

      current = appNow.add(const Duration(minutes: 14, seconds: 30));
      app.router.go('/profile');
      await pumpFrames(tester);
      await tester.ensureVisible(signOutButton(app));
      await tester.tap(signOutButton(app));
      await pumpFrames(tester, 4);

      expect(server.count(refreshKey), 1);
      final logout = server.requests(logoutKey).single;
      expect(logout.body, <String, Object?>{'refresh_token': refreshToken});
      expect(logout.authorization, 'Bearer $access');
      expect(app.location, '/login');
      expect(app.container.read(sessionProvider), const SessionSignedOut());
      expect(app.store.current, isNull);
      expect(manager.currentRefreshToken, isNull);
      expect(manager.currentAccessToken, isNull);
      expect(find.text(app.l10n.errorSessionExpired), findsNothing);
    });
  });

  group('own-exit marks', () {
    testWidgets('signing out drops them', (tester) async {
      final app = await pumpCardoApp(tester, server: FakeServer());
      app.container.read(selfExitProvider.notifier).mark('board-1');
      expect(app.container.read(selfExitProvider), isNotEmpty);

      unawaited(app.container.read(sessionProvider.notifier).signOut());
      await pumpFrames(tester, 4);

      expect(app.container.read(selfExitProvider), isEmpty);
    });
  });
}
