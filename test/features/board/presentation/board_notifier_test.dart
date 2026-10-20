import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_notices.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

const Duration _tick = Duration(milliseconds: 1);
const Duration _hold = Duration(milliseconds: 100);

Future<void> _flush(WidgetTester tester) => tester.pump(_tick);

BoardSyncState _read(ProviderContainer container) =>
    container.read(boardNotifierProvider);

({ProviderContainer container, List<BoardSyncState> history}) _open(
  WidgetTester tester, {
  required BoardGateway gateway,
  BoardRole role = BoardRole.editor,
  BoardSyncConfig? config,
  DateTime? now,
}) {
  final container = makeContainer(
    gateway: gateway,
    role: role,
    config:
        config ??
        const BoardSyncConfig(
          nackHold: _hold,
          retryDelay: Duration(milliseconds: 50),
          maxInternalRetries: 2,
        ),
    now: now,
  );
  final history = <BoardSyncState>[];
  container.listen<BoardSyncState>(
    boardNotifierProvider,
    (previous, next) => history.add(next),
    fireImmediately: true,
  );
  return (container: container, history: history);
}

FakeBoardGateway _fake({
  RejectPolicy? rejectWhen,
  BoardRole role = BoardRole.editor,
  BoardSnapshot? initial,
}) {
  return FakeBoardGateway(
    initial: initial ?? demoBoardSnapshot(currentUserRole: role),
    confirmDelay: Duration.zero,
    rejectWhen: rejectWhen,
  );
}

void main() {
  group('move lifecycle', () {
    testWidgets('pending first, then confirmed with lastSeq + 1', (
      tester,
    ) async {
      final gateway = _fake();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      final start = _read(container);
      expect(start.lastSeq, 1284);
      expect(start.pending, isEmpty);
      expect(start.view, start.confirmed);

      notifier.moveCard(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.review,
        afterId: 'c-refresh',
      );

      final pending = _read(container);
      expect(pending.pending.length, 1);
      expect(pending.pending.single.status, PendingOpStatus.sent);
      expect(pending.pending.single.createdAt, DateTime.utc(2026, 1, 1, 12));
      final op = pending.pending.single.op as MoveCard;
      expect(op.opId, 'id-0');
      expect(op.baseVersion, 3);
      expect(op.toColumnId, DemoIds.review);
      expect(op.afterId, 'c-refresh');
      expect(op.beforeId, 'c-presence');
      expect(pending.cardStatus(DemoIds.rankCard), CardSyncStatus.pending);
      expect(
        pending.confirmed.cardById(DemoIds.rankCard)!.columnId,
        isNot(DemoIds.review),
      );
      expect(pending.view.cardById(DemoIds.rankCard)!.columnId, DemoIds.review);
      expect(pending.lastSeq, 1284);

      await _flush(tester);

      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(done.lastSeq, 1285);
      expect(done.confirmed.seq, 1285);
      expect(done.view, done.confirmed);
      expect(done.cardStatus(DemoIds.rankCard), CardSyncStatus.confirmed);
      expect(ids(done.confirmed, DemoIds.review), <String>[
        'c-refresh',
        DemoIds.rankCard,
        'c-presence',
        'c-nack',
      ]);
      expect(gateway.serverBoard.seq, 1285);
      expect(gateway.serverBoard.cardById(DemoIds.rankCard)!.version, 4);
      expect(done.confirmed.cardById(DemoIds.rankCard)!.version, 4);
      container.dispose();
    });

    testWidgets('two consecutive moves advance seq twice', (tester) async {
      final session = _open(tester, gateway: _fake());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-ci', toColumnId: DemoIds.backlog);
      expect(_read(container).pending.length, 2);
      await _flush(tester);
      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(done.lastSeq, 1286);
      expect(done.view, done.confirmed);
      container.dispose();
    });

    testWidgets('same-card chained moves confirm in order', (tester) async {
      final gateway = _fake();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.review);
      final first = _read(container).pending.first.op as MoveCard;
      final second = _read(container).pending.last.op as MoveCard;
      expect(first.baseVersion, 1);
      expect(second.baseVersion, 2);
      await _flush(tester);
      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(done.confirmed.cardById('c-audit')!.columnId, DemoIds.review);
      expect(done.confirmed.cardById('c-audit')!.version, 3);
      container.dispose();
    });

    testWidgets('offline connection queues without sending', (tester) async {
      final base = demoBoardSnapshot();
      final offline = BoardSnapshot(
        board: base.board,
        currentUser: base.currentUser,
        boards: base.boards,
        presence: base.presence,
        connection: ConnectionStatus.offline,
      );
      final gateway = ControlledGateway(initial: offline);
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await _flush(tester);
      final state = _read(container);
      expect(state.pending.single.status, PendingOpStatus.queued);
      expect(gateway.calls, isEmpty);
      expect(state.cardStatus('c-audit'), CardSyncStatus.pending);
      container.dispose();
    });
  });

  group('nack', () {
    testWidgets('rejected, then removed after nackHold', (tester) async {
      final gateway = _fake(
        rejectWhen: (op) => const OpRejection(reason: NackReason.forbidden),
      );
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await _flush(tester);

      final rejected = _read(container);
      expect(rejected.pending.single.status, PendingOpStatus.rejected);
      expect(rejected.cardStatus('c-audit'), CardSyncStatus.rejected);
      expect(rejected.cardRejection('c-audit')!.reason, NackReason.forbidden);
      expect(rejected.cardRejection('c-audit')!.atSeq, 1284);
      expect(rejected.lastSeq, 1284);
      expect(rejected.confirmed, session.history.first.confirmed);

      await tester.pump(const Duration(milliseconds: 90));
      expect(_read(container).pending.length, 1);

      await tester.pump(const Duration(milliseconds: 20));
      final after = _read(container);
      expect(after.pending, isEmpty);
      expect(after.view, after.confirmed);
      expect(after.cardStatus('c-audit'), CardSyncStatus.confirmed);
      expect(after.lastSeq, 1284);
      container.dispose();
    });

    testWidgets('stale baseVersion from a remote move is a version conflict', (
      tester,
    ) async {
      final gateway = _fake();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      gateway.simulateRemoteMove(
        cardId: 'c-audit',
        toColumnId: DemoIds.review,
        actorId: DemoIds.anya,
      );
      await _flush(tester);
      final state = _read(container);
      expect(state.pending.single.isRejected, isTrue);
      expect(
        state.pending.single.rejection!.reason,
        NackReason.versionConflict,
      );
      await tester.pump(_hold);
      container.dispose();
    });

    testWidgets('rejected CreateCard removes dependent operations', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);

      notifier.createCard(columnId: DemoIds.backlog, title: 'Новая');
      final create = _read(container).pending.single.op as CreateCard;
      notifier.editCardTitle(cardId: create.cardId, title: 'Новая 2');
      notifier.moveCard(cardId: create.cardId, toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      expect(_read(container).pending.length, 4);

      gateway.calls.first.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await _flush(tester);
      expect(_read(container).pending.length, 4);
      expect(
        _read(container).cardStatus(create.cardId),
        CardSyncStatus.rejected,
      );

      await tester.pump(_hold);
      final after = _read(container);
      expect(after.pending.length, 1);
      expect((after.pending.single.op as MoveCard).cardId, 'c-audit');
      expect(after.view.cardById(create.cardId), isNull);
      container.dispose();
    });

    testWidgets('rejected move keeps unrelated pending ops', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-ci', toColumnId: DemoIds.backlog);
      gateway.calls.first.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.notFound)),
      );
      await _flush(tester);
      await tester.pump(_hold);
      final after = _read(container);
      expect(after.pending.length, 1);
      expect((after.pending.single.op as MoveCard).cardId, 'c-ci');
      expect(after.pending.single.status, PendingOpStatus.sent);
      container.dispose();
    });

    testWidgets('disposing the container cancels the hold timer', (
      tester,
    ) async {
      final gateway = _fake(
        rejectWhen: (op) => const OpRejection(reason: NackReason.forbidden),
      );
      final session = _open(tester, gateway: gateway);
      session.container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await _flush(tester);
      session.container.dispose();
    });
  });

  group('internal errors', () {
    testWidgets(
      'same opId is retried up to maxInternalRetries, then rejected',
      (tester) async {
        final gateway = ControlledGateway();
        final session = _open(tester, gateway: gateway);
        final container = session.container;
        container
            .read(boardNotifierProvider.notifier)
            .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
        expect(gateway.calls.length, 1);

        const internal = OpRejected(OpRejection(reason: NackReason.internal));
        gateway.calls[0].completer.complete(internal);
        await _flush(tester);
        var item = _read(container).pending.single;
        expect(item.status, PendingOpStatus.sent);
        expect(item.failedAttempts, 1);
        expect(gateway.calls.length, 1);

        await tester.pump(const Duration(milliseconds: 50));
        expect(gateway.calls.length, 2);
        gateway.calls[1].completer.complete(internal);
        await _flush(tester);
        item = _read(container).pending.single;
        expect(item.failedAttempts, 2);
        expect(item.isRejected, isFalse);

        await tester.pump(const Duration(milliseconds: 50));
        expect(gateway.calls.length, 3);
        gateway.calls[2].completer.complete(internal);
        await _flush(tester);

        item = _read(container).pending.single;
        expect(item.isRejected, isTrue);
        expect(item.rejection!.reason, NackReason.internal);
        expect(gateway.calls.map((c) => c.op.opId).toSet(), <String>{'id-0'});
        expect(gateway.calls.length, 3);

        await tester.pump(_hold);
        expect(_read(container).pending, isEmpty);
        container.dispose();
      },
    );

    testWidgets('a retry can still succeed', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      gateway.calls[0].completer.complete(
        const OpRejected(OpRejection(reason: NackReason.internal)),
      );
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 50));
      gateway.calls[1].completer.complete(const OpConfirmed(seq: 1285));
      await _flush(tester);
      final state = _read(container);
      expect(state.pending, isEmpty);
      expect(state.lastSeq, 1285);
      expect(state.confirmed.cardById('c-audit')!.columnId, DemoIds.done);
      container.dispose();
    });

    testWidgets('a thrown gateway error counts as internal', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      gateway.calls[0].completer.completeError(StateError('boom'));
      await _flush(tester);
      expect(_read(container).pending.single.failedAttempts, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(gateway.calls.length, 2);
      gateway.calls[1].completer.complete(const OpConfirmed(seq: 1285));
      await _flush(tester);
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('non-internal nack is never retried', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      gateway.calls[0].completer.complete(
        const OpRejected(OpRejection(reason: NackReason.rateLimited)),
      );
      await _flush(tester);
      await tester.pump(const Duration(milliseconds: 80));
      expect(gateway.calls.length, 1);
      await tester.pump(_hold);
      container.dispose();
    });
  });

  group('confirm edge cases', () {
    testWidgets('a stale seq drops the op without applying it', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      gateway.calls[0].completer.complete(const OpConfirmed(seq: 1284));
      await _flush(tester);
      final state = _read(container);
      expect(state.pending, isEmpty);
      expect(state.lastSeq, 1284);
      expect(state.confirmed.cardById('c-audit')!.columnId, DemoIds.backlog);
      container.dispose();
    });

    testWidgets('outcome after dispose is ignored', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      expect(gateway.calls, hasLength(1));
      final recorded = session.history.length;
      final lastState = session.history.last;
      expect(lastState.pending, hasLength(1));
      container.dispose();
      gateway.calls[0].completer.complete(const OpConfirmed(seq: 1285));
      await _flush(tester);
      expect(tester.takeException(), isNull);
      expect(session.history, hasLength(recorded));
      expect(session.history.last, same(lastState));
      expect(session.history.last.lastSeq, 1284);
    });
  });

  group('base version and anchors ignore rejected operations', () {
    testWidgets('move after a nack uses the confirmed version', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCardToColumnEnd(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.review,
      );
      gateway.calls[0].completer.complete(
        OpRejected(rejection(NackReason.versionConflict)),
      );
      await _flush(tester);
      final rejected = _read(container);
      expect(rejected.cardStatus(DemoIds.rankCard), CardSyncStatus.rejected);
      expect(
        rejected.view.cardById(DemoIds.rankCard)!.columnId,
        DemoIds.review,
      );
      expect(rejected.view.cardById(DemoIds.rankCard)!.version, 4);
      expect(
        rejected.liveView.cardById(DemoIds.rankCard)!.columnId,
        DemoIds.inProgress,
      );
      expect(rejected.liveView.cardById(DemoIds.rankCard)!.version, 3);

      notifier.moveCardToColumnEnd(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.done,
      );
      await _flush(tester);
      expect(gateway.calls, hasLength(2));
      final retry = gateway.calls[1].op as MoveCard;
      expect(retry.baseVersion, 3);
      expect(retry.toColumnId, DemoIds.done);
      expect(retry.afterId, 'c-roles');
      expect(retry.beforeId, isNull);
      await tester.pump(_hold * 2);
    });

    testWidgets('move after a nack in the same column ignores the rejected '
        'position', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCardToColumnEnd(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
      );
      gateway.calls[0].completer.complete(
        OpRejected(rejection(NackReason.versionConflict)),
      );
      await _flush(tester);
      notifier.moveCardToIndex(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        index: 1,
      );
      await _flush(tester);
      expect(gateway.calls, hasLength(1));
      notifier.moveCardToIndex(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        index: 0,
      );
      await _flush(tester);
      final second = gateway.calls[1].op as MoveCard;
      expect(second.baseVersion, 3);
      expect(second.afterId, isNull);
      expect(second.beforeId, DemoIds.handshakeCard);
      await tester.pump(_hold * 2);
    });

    testWidgets('two quick moves chain the optimistic version', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final notifier = session.container.read(boardNotifierProvider.notifier);
      notifier.moveCardToColumnEnd(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.review,
      );
      notifier.moveCardToColumnEnd(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.done,
      );
      await _flush(tester);
      expect(gateway.calls, hasLength(2));
      expect((gateway.calls[0].op as MoveCard).baseVersion, 3);
      expect((gateway.calls[1].op as MoveCard).baseVersion, 4);
    });

    testWidgets('archive after a nack targets the live card', (tester) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.archiveCard(DemoIds.rankCard);
      gateway.calls[0].completer.complete(
        OpRejected(rejection(NackReason.notFound)),
      );
      await _flush(tester);
      expect(
        _read(container).view.cardsIn(DemoIds.inProgress).map((c) => c.id),
        isNot(contains(DemoIds.rankCard)),
      );
      notifier.archiveCard(DemoIds.rankCard);
      await _flush(tester);
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls[1].op, isA<ArchiveCard>());
      await tester.pump(_hold * 2);
    });
  });

  group('permissions and no-ops', () {
    testWidgets('viewer cannot change anything', (tester) async {
      final gateway = ControlledGateway(
        initial: demoBoardSnapshot(currentUserRole: BoardRole.viewer),
      );
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.moveCardToColumnEnd(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.createCard(columnId: DemoIds.backlog, title: 'x');
      notifier.editCardTitle(cardId: 'c-audit', title: 'x');
      notifier.archiveCard('c-audit');
      await _flush(tester);
      expect(_read(container).pending, isEmpty);
      expect(gateway.calls, isEmpty);
      expect(container.read(canEditBoardProvider), isFalse);
      expect(container.read(currentRoleProvider), BoardRole.viewer);
      container.dispose();
    });

    testWidgets('moving to the same place creates no operation', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        afterId: DemoIds.handshakeCard,
        beforeId: DemoIds.readOnlyCard,
      );
      notifier.moveCard(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        afterId: DemoIds.handshakeCard,
      );
      notifier.moveCardToIndex(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        index: 1,
      );
      notifier.moveCard(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.inProgress,
        beforeId: DemoIds.readOnlyCard,
      );
      expect(_read(container).pending, isEmpty);
      expect(gateway.calls, isEmpty);
      container.dispose();
    });

    testWidgets('last card to the end of its own column is a no-op', (
      tester,
    ) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(
            cardId: DemoIds.syncStateCard,
            toColumnId: DemoIds.inProgress,
          );
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('unknown card or column is ignored', (tester) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'nope', toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-audit', toColumnId: 'nope');
      notifier.createCard(columnId: 'nope', title: 'x');
      notifier.archiveCard('nope');
      notifier.editCardTitle(cardId: 'nope', title: 'x');
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('moving an archived card is ignored', (tester) async {
      final gateway = _fake();
      final session = _open(tester, gateway: gateway);
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.archiveCard('c-audit');
      await _flush(tester);
      expect(_read(container).confirmed.cardById('c-audit')!.archived, isTrue);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });
  });

  group('other intents', () {
    testWidgets('createCard trims the title and appends to the column', (
      tester,
    ) async {
      final session = _open(tester, gateway: _fake());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.createCard(columnId: DemoIds.review, title: '   Тест   ');
      final op = _read(container).pending.single.op as CreateCard;
      expect(op.title, 'Тест');
      expect(op.actorId, DemoIds.elena);
      expect(op.afterId, 'c-nack');
      expect(_read(container).view.cardById(op.cardId), isNotNull);
      await _flush(tester);
      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(ids(done.confirmed, DemoIds.review).last, op.cardId);
      expect(done.lastSeq, 1285);
      container.dispose();
    });

    testWidgets('blank titles are ignored', (tester) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.createCard(columnId: DemoIds.review, title: '   ');
      notifier.editCardTitle(cardId: 'c-audit', title: '   ');
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('editCardTitle skips unchanged titles', (tester) async {
      final session = _open(tester, gateway: _fake());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      final title = _read(container).view.cardById('c-audit')!.title;
      notifier.editCardTitle(cardId: 'c-audit', title: '  $title ');
      expect(_read(container).pending, isEmpty);
      notifier.editCardTitle(cardId: 'c-audit', title: 'Другое');
      await _flush(tester);
      expect(_read(container).confirmed.cardById('c-audit')!.title, 'Другое');
      container.dispose();
    });

    testWidgets('archiveCard removes the card from the column', (tester) async {
      final session = _open(tester, gateway: _fake());
      final container = session.container;
      container.read(boardNotifierProvider.notifier).archiveCard('c-audit');
      expect(
        ids(_read(container).view, DemoIds.backlog),
        isNot(contains('c-audit')),
      );
      await _flush(tester);
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('moveCardToIndex and moveCardToColumnEnd use anchors', (
      tester,
    ) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.moveCardToIndex(
        cardId: 'c-audit',
        toColumnId: DemoIds.done,
        index: 0,
      );
      var op = _read(container).pending.last.op as MoveCard;
      expect(op.afterId, isNull);
      expect(op.beforeId, 'c-migrations');
      notifier.moveCardToColumnEnd(cardId: 'c-ci', toColumnId: DemoIds.review);
      op = _read(container).pending.last.op as MoveCard;
      expect(op.afterId, 'c-nack');
      expect(op.beforeId, isNull);
      container.dispose();
    });
  });

  group('version conflict with a remote move', () {
    testWidgets('moveCard with a stale version names the other author', (
      tester,
    ) async {
      final gateway = _fake();
      final session = _open(tester, gateway: gateway);
      final container = session.container;

      gateway.simulateRemoteMove(
        cardId: DemoIds.rankCard,
        toColumnId: DemoIds.done,
        actorId: DemoIds.maxim,
      );
      expect(gateway.serverBoard.seq, 1285);

      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: DemoIds.rankCard, toColumnId: DemoIds.review);
      await _flush(tester);

      final state = _read(container);
      final item = state.pending.single;
      expect(item.isRejected, isTrue);
      expect(item.rejection!.reason, NackReason.versionConflict);
      expect(item.rejection!.actorId, DemoIds.maxim);
      expect(item.rejection!.atSeq, 1285);
      expect(state.lastSeq, 1284);

      final notices = <BoardNotice>[];
      for (var i = 1; i < session.history.length; i++) {
        notices.addAll(
          noticesBetween(session.history[i - 1], session.history[i]),
        );
      }
      expect(notices.length, 1);
      expect(notices.single.actorName, 'Максим');
      expect(notices.single.rejection.reason, NackReason.versionConflict);
      expect(notices.single.retrying, isFalse);

      final column = container
          .read(boardColumnsProvider)
          .firstWhere((c) => c.column.id == DemoIds.review);
      final card = column.cards.firstWhere(
        (c) => c.card.id == DemoIds.rankCard,
      );
      expect(card.rejectionActorName, 'Максим');

      await tester.pump(_hold);
      expect(_read(container).pending, isEmpty);
      container.dispose();
    });
  });

  group('derived providers', () {
    testWidgets('boardViewProvider follows pending ops', (tester) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      container
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      expect(
        container.read(boardViewProvider).cardById('c-audit')!.columnId,
        DemoIds.done,
      );
      expect(container.read(selectedCardProvider), isNull);
      container.read(selectedCardIdProvider.notifier).select('c-audit');
      expect(container.read(selectedCardProvider)!.card.id, 'c-audit');
      expect(
        container.read(selectedCardProvider)!.status,
        CardSyncStatus.pending,
      );
      container.read(selectedCardIdProvider.notifier).clear();
      expect(container.read(selectedCardProvider), isNull);
      container.dispose();
    });

    testWidgets('presence hides the current user as editor', (tester) async {
      final session = _open(tester, gateway: ControlledGateway());
      final container = session.container;
      final readOnly = container
          .read(boardColumnsProvider)
          .expand((c) => c.cards)
          .firstWhere((c) => c.card.id == DemoIds.readOnlyCard);
      expect(readOnly.editingBy!.name, 'Аня');
      expect(container.read(onlineMembersProvider).length, 3);
      container.dispose();
    });
  });
}
