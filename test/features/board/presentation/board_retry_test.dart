import 'package:cardo/features/board/presentation/board_load_views.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String snapshotKey = 'GET /api/boards/$boardId1';

void main() {
  group('retry on the board error screen', () {
    testWidgets('shows the loading screen without a retry button', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/boards/$boardId1',
      );
      expect(find.text(app.l10n.boardLoadErrorTitle), findsOneWidget);

      server.clear(snapshotKey);
      final gate = server.gate(snapshotKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.boardLoadingTitle), findsOneWidget);
      expect(find.byType(BoardSkeletonColumns), findsOneWidget);
      expect(find.text(app.l10n.commonRetry), findsNothing);
      expect(find.text(app.l10n.boardLoadErrorTitle), findsNothing);

      gate.complete();
      await pumpFrames(tester);

      expect(find.byType(BoardScreen), findsOneWidget);
    });

    testWidgets('exactly one repeated request is sent', (tester) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/boards/$boardId1',
      );
      expect(server.count(snapshotKey), 1);

      final retry = find.text(app.l10n.commonRetry);
      final retryCenter = tester.getCenter(retry);
      server.clear(snapshotKey);
      final gate = server.gate(snapshotKey);
      await tester.tap(retry);
      await pumpFrames(tester, 2);
      await tester.tapAt(retryCenter);
      await pumpFrames(tester, 2);
      await tester.tapAt(retryCenter);
      await pumpFrames(tester, 2);

      expect(server.count(snapshotKey), 2);

      gate.complete();
      await pumpFrames(tester);

      expect(server.count(snapshotKey), 2);
      expect(find.byType(BoardScreen), findsOneWidget);
    });

    testWidgets('a failing repeat returns to the error with a fresh button', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/boards/$boardId1',
      );

      final gate = server.gate(snapshotKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester, 2);
      expect(find.text(app.l10n.commonRetry), findsNothing);

      server.on(
        snapshotKey,
        FakeResponse.network(DioExceptionType.connectionError),
      );
      gate.complete();
      await pumpFrames(tester);

      expect(find.text(app.l10n.errorNetworkOffline), findsOneWidget);
      expect(find.text(app.l10n.commonRetry), findsOneWidget);

      server.clear(snapshotKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester);

      expect(find.byType(BoardScreen), findsOneWidget);
      expect(server.count(snapshotKey), 3);
    });

    testWidgets('the loading screen after a retry can still go back', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(snapshotKey, FakeResponse.error(500, 'internal'));
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/boards/$boardId1',
      );

      server.clear(snapshotKey);
      server.gate(snapshotKey);
      await tester.tap(find.text(app.l10n.commonRetry));
      await pumpFrames(tester, 2);
      await tester.tap(find.byTooltip(app.l10n.boardBack));
      await pumpFrames(tester);

      expect(app.location, '/boards');
    });
  });
}
