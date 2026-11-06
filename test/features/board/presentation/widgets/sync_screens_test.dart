import 'dart:async';

import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/offline_banner.dart';
import 'package:cardo/features/board/presentation/widgets/rejected_ops_sheet.dart';
import 'package:cardo/features/board/presentation/widgets/sync_summary_card.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/event_factory.dart';
import '../../helpers/pump_board.dart';

const Size narrow = Size(360, 640);
const String audit = 'c-audit';
const String presence = 'c-presence';
const String ci = 'c-ci';

class IssueGateway extends ControlledGateway {
  final StreamController<ProtocolIssue> controller =
      StreamController<ProtocolIssue>.broadcast(sync: true);

  @override
  Stream<ProtocolIssue> get issues => controller.stream;
}

Future<ControlledGateway> startOnline(
  WidgetTester tester, {
  Size size = compactSize,
  double textScale = 1,
  Locale locale = const Locale('ru'),
  bool disableAnimations = false,
  ControlledGateway? gateway,
}) async {
  final g = gateway ?? ControlledGateway();
  await pumpBoard(
    tester,
    gateway: g,
    size: size,
    textScale: textScale,
    locale: locale,
    disableAnimations: disableAnimations,
  );
  g.emit(const ReadySignal());
  await tester.pump();
  return g;
}

BoardNotifierHandle handleOf(WidgetTester tester) =>
    BoardNotifierHandle(containerOf(tester));

class BoardNotifierHandle {
  BoardNotifierHandle(this.container);

  final ProviderContainer container;

  BoardSyncState get state => container.read(boardNotifierProvider);

  void move(String cardId) {
    container
        .read(boardNotifierProvider.notifier)
        .moveCard(cardId: cardId, toColumnId: DemoIds.done);
  }
}

Future<void> goOffline(WidgetTester tester, ControlledGateway g) async {
  g.emit(const ConnectionSignal(ConnectionStatus.offline));
  await tester.pump();
}

Future<void> reconnect(WidgetTester tester, ControlledGateway g) async {
  g.emit(const ConnectionSignal(ConnectionStatus.syncing));
  g.emit(const ReadySignal());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void backgroundAndBack(WidgetTester tester) {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final ru = AppLocalizationsRu();
  final en = AppLocalizationsEn();

  group('offline banner', () {
    testWidgets('narrow screen with large text: shows the count and retries', (
      tester,
    ) async {
      final g = await startOnline(tester, size: narrow, textScale: 2);
      final board = handleOf(tester);
      expect(find.byType(OfflineBannerBody), findsNothing);

      await goOffline(tester, g);
      expect(find.byType(OfflineBannerBody), findsNothing);

      board
        ..move(audit)
        ..move(presence)
        ..move(ci);
      await settle(tester);

      expect(find.text(ru.syncOfflineBanner(3)), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final button = tester.getSize(
        find.widgetWithText(TextButton, 'Повторить'),
      );
      expect(button.height, greaterThanOrEqualTo(44));

      await tester.ensureVisible(find.text('Повторить'));
      await tester.pump();
      await tester.tap(find.text('Повторить'));
      await tester.pump();

      expect(g.retries, 1);
    });

    testWidgets('english plural forms and a banner that pushes content down', (
      tester,
    ) async {
      final g = await startOnline(tester, locale: const Locale('en'));
      final board = handleOf(tester);
      final before = tester.getTopLeft(find.text('Бэклог').first).dy;
      await goOffline(tester, g);

      board.move(audit);
      await settle(tester);

      expect(find.text(en.syncOfflineBanner(1)), findsOneWidget);
      expect(find.text('No connection · 1 change waiting'), findsOneWidget);
      final after = tester.getTopLeft(find.text('Бэклог').first).dy;
      expect(after, greaterThan(before));

      board.move(presence);
      await settle(tester);

      expect(find.text('No connection · 2 changes waiting'), findsOneWidget);
    });

    testWidgets('reconnecting without pending ops shows only the pill', (
      tester,
    ) async {
      final g = await startOnline(tester);

      g.emit(
        const ConnectionSignal(
          ConnectionStatus.reconnecting,
          reconnectSeconds: 4,
        ),
      );
      await settle(tester);

      expect(find.byType(OfflineBannerBody), findsNothing);
      expect(find.textContaining('Переподключение'), findsOneWidget);
    });

    testWidgets('reconnecting with pending ops shows the banner', (
      tester,
    ) async {
      final g = await startOnline(tester);
      final board = handleOf(tester);
      g.emit(const ConnectionSignal(ConnectionStatus.reconnecting));
      board.move(audit);
      await settle(tester);

      expect(find.text(ru.syncOfflineBanner(1)), findsOneWidget);
    });

    testWidgets('it disappears once the connection is back', (tester) async {
      final g = await startOnline(tester);
      final board = handleOf(tester);
      await goOffline(tester, g);
      board.move(audit);
      await settle(tester);
      expect(find.byType(OfflineBannerBody), findsOneWidget);

      await reconnect(tester, g);
      await settle(tester);

      expect(find.byType(OfflineBannerBody), findsNothing);
    });

    testWidgets('with reduced motion it appears at once', (tester) async {
      final g = await startOnline(tester, disableAnimations: true);
      final board = handleOf(tester);
      await goOffline(tester, g);

      board.move(audit);
      await tester.pump();

      expect(find.byType(OfflineBannerBody), findsOneWidget);
      expect(
        tester.getSize(find.byType(OfflineBanner)).height,
        greaterThan(40),
      );
    });

    testWidgets('on a wide screen it sits in the board header', (tester) async {
      final g = await startOnline(tester, size: expandedSize);
      final board = handleOf(tester);
      await goOffline(tester, g);

      board.move(audit);
      await settle(tester);

      expect(find.text(ru.syncOfflineBanner(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('summary after reconnect', () {
    Future<(ControlledGateway, BoardNotifierHandle)> twoOfThreeFail(
      WidgetTester tester, {
      Size size = narrow,
      double textScale = 2,
      Locale locale = const Locale('ru'),
    }) async {
      final g = await startOnline(
        tester,
        size: size,
        textScale: textScale,
        locale: locale,
      );
      final board = handleOf(tester);
      await goOffline(tester, g);
      board
        ..move(audit)
        ..move(presence)
        ..move(ci);
      await settle(tester);
      await reconnect(tester, g);
      expect(g.calls, hasLength(3));
      g.calls[0].reject(NackReason.forbidden);
      g.calls[1].reject(NackReason.versionConflict);
      g.calls[2].confirm(g.snapshot().board.seq + 1);
      await settle(tester);
      return (g, board);
    }

    testWidgets('one summary instead of a snackbar per rejection', (
      tester,
    ) async {
      await twoOfThreeFail(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SyncSummaryCard), findsOneWidget);
      expect(find.text(ru.syncSummaryTitle(2)), findsOneWidget);
      expect(find.text(ru.syncSummaryBody), findsOneWidget);
      expect(find.text('Скрыть'), findsOneWidget);
      expect(find.text('Подробнее'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final details = tester.getSize(
        find.widgetWithText(FilledButton, 'Подробнее'),
      );
      expect(details.height, greaterThanOrEqualTo(44));
    });

    testWidgets('hide removes the card but keeps nothing on screen', (
      tester,
    ) async {
      await twoOfThreeFail(tester);

      await tester.tap(find.text('Скрыть'));
      await settle(tester);

      expect(find.byType(SyncSummaryCard), findsNothing);
    });

    testWidgets('details open the list; closing it clears the journal', (
      tester,
    ) async {
      final (_, board) = await twoOfThreeFail(tester);

      await tester.tap(find.text('Подробнее'));
      await settle(tester);

      expect(find.byType(RejectedOpsSheet), findsOneWidget);
      expect(find.text(ru.rejectedTitle(2)), findsOneWidget);
      expect(find.text(ru.rejectedSubtitleSaved(1)), findsOneWidget);
      final scrollable = find.descendant(
        of: find.byType(RejectedOpsSheet),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text(ru.nackForbidden),
        100,
        scrollable: scrollable,
      );
      expect(find.text(ru.rejectedKindMove), findsWidgets);
      expect(find.textContaining('Журнал действий'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(board.state.rejections.entries, hasLength(2));

      await tester.tap(find.text(ru.rejectedClose));
      await settle(tester);

      expect(find.byType(RejectedOpsSheet), findsNothing);
      expect(find.byType(SyncSummaryCard), findsNothing);
      expect(board.state.rejections.isEmpty, isTrue);
      expect(board.state.summary, isNull);
    });

    testWidgets('the title keeps its count while the sheet closes', (
      tester,
    ) async {
      final (_, board) = await twoOfThreeFail(tester);
      await tester.tap(find.text('Подробнее'));
      await settle(tester);

      await tester.tap(find.text(ru.rejectedClose));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(RejectedOpsSheet), findsOneWidget);
      expect(find.text(ru.rejectedTitle(0)), findsNothing);
      expect(find.text(ru.rejectedTitle(2)), findsOneWidget);
      await settle(tester);
      expect(board.state.rejections.isEmpty, isTrue);
    });

    testWidgets('show on board closes the list and opens the card', (
      tester,
    ) async {
      await twoOfThreeFail(tester, size: compactSize, textScale: 1);

      await tester.tap(find.text('Подробнее'));
      await settle(tester);
      await tester.tap(find.text(ru.rejectedShowOnBoard).first);
      await settle(tester);

      expect(find.byType(RejectedOpsSheet), findsNothing);
      expect(find.byType(CardSheet), findsOneWidget);
    });

    testWidgets('english texts', (tester) async {
      await twoOfThreeFail(
        tester,
        size: compactSize,
        textScale: 1,
        locale: const Locale('en'),
      );

      expect(find.text(en.syncSummaryTitle(2)), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await settle(tester);

      expect(find.text('2 changes not applied'), findsOneWidget);
      expect(find.text(en.rejectedSubtitleSaved(1)), findsOneWidget);
      expect(find.text('Show on board'), findsWidgets);
    });

    testWidgets('the list names who changed the board', (tester) async {
      final g = await startOnline(tester, locale: const Locale('en'));
      final board = handleOf(tester);
      await goOffline(tester, g);
      board.move(audit);
      await settle(tester);
      await reconnect(tester, g);

      g.calls.single.rejectWith(
        const OpRejection(
          reason: NackReason.versionConflict,
          actorId: DemoIds.maxim,
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Details'));
      await settle(tester);

      expect(find.text(en.nackVersionConflict('Максим')), findsOneWidget);
      expect(find.text(en.rejectedSubtitle), findsOneWidget);
    });

    testWidgets('on a wide screen the details are a dialog', (tester) async {
      final (_, board) = await twoOfThreeFail(
        tester,
        size: expandedSize,
        textScale: 1,
      );

      await tester.tap(find.text('Подробнее'));
      await settle(tester);

      expect(find.byType(RejectedOpsDialog), findsOneWidget);
      expect(find.byType(RejectedOpsSheet), findsNothing);

      await tester.tap(find.text(ru.rejectedClose));
      await settle(tester);

      expect(find.byType(RejectedOpsDialog), findsNothing);
      expect(board.state.rejections.isEmpty, isTrue);
    });

    testWidgets('silently dropped ops are reported with their reason', (
      tester,
    ) async {
      final g = await startOnline(tester, locale: const Locale('en'));
      final board = handleOf(tester);
      await goOffline(tester, g);
      board
        ..move(audit)
        ..move(presence);
      g.push(cardArchived(g.snapshot().board.seq + 1, audit, DemoIds.review));
      await settle(tester);

      await reconnect(tester, g);
      g.calls.single.confirm(g.snapshot().board.seq + 2);
      await settle(tester);

      expect(find.text(en.syncSummaryTitle(1)), findsOneWidget);
      await tester.tap(find.text('Details'));
      await settle(tester);
      expect(find.text(en.rejectedDropGone), findsOneWidget);
      expect(find.text(en.rejectedSubtitleSaved(1)), findsOneWidget);
    });

    testWidgets('a rejection outside the batch is still a snackbar', (
      tester,
    ) async {
      final g = await startOnline(tester);
      final board = handleOf(tester);
      await goOffline(tester, g);
      board.move(audit);
      await settle(tester);
      await reconnect(tester, g);
      g.calls.single.confirm(g.snapshot().board.seq + 1);
      await settle(tester);
      expect(find.byType(SyncSummaryCard), findsNothing);

      board.move(presence);
      await tester.pump();
      g.calls.last.reject(NackReason.forbidden);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(ru.nackForbidden), findsOneWidget);
      expect(find.byType(SyncSummaryCard), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('returning from the background', () {
    testWidgets('resuming offline retries the connection', (tester) async {
      final g = await startOnline(tester);
      await goOffline(tester, g);

      backgroundAndBack(tester);
      await tester.pump();

      expect(g.retries, 1);
    });

    testWidgets('resuming while connected does nothing', (tester) async {
      final g = await startOnline(tester);

      backgroundAndBack(tester);
      await tester.pump();

      expect(g.retries, 0);
    });

    testWidgets('resuming after the board ended does nothing', (tester) async {
      final g = await startOnline(tester);
      g.emit(const EndedSignal(BoardEndReason.sessionEnded));
      await tester.pump();

      backgroundAndBack(tester);
      await tester.pump();

      expect(g.retries, 0);
    });
  });

  group('protocol issues', () {
    testWidgets('repeated unknown message types ask to update, once', (
      tester,
    ) async {
      final g = IssueGateway();
      addTearDown(g.controller.close);
      await startOnline(tester, gateway: g);

      g.controller.add(const UnknownMessageType('a'));
      g.controller.add(const MalformedMessage('x'));
      g.controller.add(const UnknownMessageType('b'));
      await tester.pump();
      expect(find.text(ru.protocolUpdateApp), findsNothing);

      g.controller.add(const UnknownMessageType('c'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(ru.protocolUpdateApp), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      g.controller.add(const UnknownMessageType('d'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(ru.protocolUpdateApp), findsNothing);
    });
  });
}
