import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/core/realtime/realtime_policy.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

DateTime clock = DateTime.utc(2026, 1, 1, 12);

typedef Opened = ({
  ProviderContainer c,
  FakeBoardGateway g,
  List<BoardSyncState> history,
});

Opened open({RejectPolicy? rejectWhen, bool announceConflicts = true}) {
  final g = FakeBoardGateway(
    confirmDelay: Duration.zero,
    rejectWhen: rejectWhen,
    announceConflicts: announceConflicts,
  );
  final ids = IdSequence();
  final history = <BoardSyncState>[];
  final c = ProviderContainer(
    overrides: [
      boardGatewayProvider.overrideWithValue(g),
      idGeneratorProvider.overrideWithValue(ids.call),
      nowProvider.overrideWithValue(() => clock),
      boardSyncConfigProvider.overrideWithValue(
        const BoardSyncConfig(
          nackHold: Duration(seconds: 5),
          retryDelay: Duration(milliseconds: 50),
          maxInternalRetries: 2,
        ),
      ),
    ],
  );
  c.listen(boardNotifierProvider, (_, next) => history.add(next));
  return (c: c, g: g, history: history);
}

BoardSyncState read(ProviderContainer c) => c.read(boardNotifierProvider);

Future<void> run(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));

Future<void> runFor(WidgetTester t, int totalMs, {int step = 100}) async {
  for (var spent = 0; spent < totalMs; spent += step) {
    await run(t, step);
  }
}

void main() {
  setUp(() => clock = DateTime.utc(2026, 1, 1, 12));

  group('an offline queue is paced', () {
    testWidgets('60 offline operations are all applied without a nack', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      for (var i = 0; i < 60; i++) {
        notifier.createCard(columnId: DemoIds.backlog, title: 'off$i');
      }
      expect(read(o.c).pending, hasLength(60));

      await runFor(t, 8000);

      expect(o.g.server.rateLimitedOps, 0);
      expect(read(o.c).pending, isEmpty);
      expect(o.history.any((state) => state.rejected.isNotEmpty), isFalse);
      expect(
        read(o.c).confirmed.cards.where((c) => c.title.startsWith('off')),
        hasLength(60),
      );
      expect(o.g.server.receivedOps, hasLength(60));
      o.c.dispose();
    });

    testWidgets('120 offline operations never close the socket with 4008', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      for (var i = 0; i < 120; i++) {
        notifier.createCard(columnId: DemoIds.backlog, title: 'bulk$i');
      }

      await runFor(t, 12000);

      expect(o.g.server.connectAttempts, 2);
      expect(o.g.server.rateLimitedOps, 0);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('no more than the burst leaves in the first instant', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      for (var i = 0; i < 40; i++) {
        notifier.createCard(columnId: DemoIds.backlog, title: 'burst$i');
      }
      while (read(o.c).connection != ConnectionStatus.connected) {
        await run(t, 20);
      }
      await run(t, 5);
      final before = o.g.server.receivedOps.length;

      expect(before, greaterThan(0));
      expect(before, lessThanOrEqualTo(RealtimePolicy.opBurst));
      await runFor(t, 6000);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('a rate_limited nack pauses the queue and keeps the op id', (
      t,
    ) async {
      var refuse = 3;
      final o = open(
        rejectWhen: (op) => refuse-- > 0
            ? const OpRejection(reason: NackReason.rateLimited)
            : null,
      );
      await run(t, 10);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      notifier.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      notifier.moveCard(cardId: 'c-ci', toColumnId: DemoIds.backlog);

      await runFor(t, 6000);

      expect(read(o.c).pending, isEmpty);
      expect(o.history.any((state) => state.rejected.isNotEmpty), isFalse);
      expect(read(o.c).confirmed.cardById('c-audit')!.columnId, DemoIds.done);
      expect(read(o.c).confirmed.cardById('c-ci')!.columnId, DemoIds.backlog);
      final ids = o.g.server.receivedOps.map((op) => op.opId).toSet();
      expect(ids, {'id-0', 'id-1'});
      o.c.dispose();
    });
  });

  group('a rate_limited retry keeps the original order', () {
    testWidgets('three nacks in a row resend A, B, C', (t) async {
      var refuse = 3;
      final o = open(
        rejectWhen: (op) => refuse-- > 0
            ? const OpRejection(reason: NackReason.rateLimited)
            : null,
      );
      await run(t, 10);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      for (final title in <String>['a', 'ab', 'abc']) {
        notifier.editCardTitle(cardId: 'c-audit', title: title);
      }

      await runFor(t, 8000);

      final sent = o.g.server.receivedOps.whereType<EditCardTitle>().toList();
      expect(sent.map((op) => op.title).toList(), [
        'a',
        'ab',
        'abc',
        'a',
        'ab',
        'abc',
      ]);
      expect(read(o.c).confirmed.cardById('c-audit')!.title, 'abc');
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });
  });

  group('dependants wait for a CreateCard', () {
    testWidgets('an internal nack on the create holds the later ops back', (
      t,
    ) async {
      var failed = false;
      final o = open(
        rejectWhen: (op) {
          if (op is CreateCard && !failed) {
            failed = true;
            return const OpRejection(reason: NackReason.internal);
          }
          return null;
        },
      );
      await run(t, 10);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      notifier.createCard(columnId: DemoIds.backlog, title: 'Fresh');
      final create = read(o.c).pending.single.op as CreateCard;
      notifier.editCardTitle(cardId: create.cardId, title: 'Renamed');
      notifier.moveCard(cardId: create.cardId, toColumnId: DemoIds.done);

      await runFor(t, 1000);

      expect(o.g.server.receivedOps.map((op) => op.runtimeType).toList(), [
        CreateCard,
        CreateCard,
        EditCardTitle,
        MoveCard,
      ]);
      expect(o.history.any((state) => state.rejected.isNotEmpty), isFalse);
      expect(read(o.c).pending, isEmpty);
      final card = read(o.c).confirmed.cardById(create.cardId)!;
      expect(card.title, 'Renamed');
      expect(card.columnId, DemoIds.done);
      o.c.dispose();
    });

    testWidgets('a create that is finally rejected sends nothing after it', (
      t,
    ) async {
      final o = open(
        rejectWhen: (op) => op is CreateCard
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      await run(t, 10);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      notifier.createCard(columnId: DemoIds.backlog, title: 'Doomed');
      final create = read(o.c).pending.single.op as CreateCard;
      notifier.editCardTitle(cardId: create.cardId, title: 'Never');
      notifier.moveCard(cardId: create.cardId, toColumnId: DemoIds.done);

      await runFor(t, 1000);

      expect(o.g.server.receivedOps.map((op) => op.runtimeType).toList(), [
        CreateCard,
      ]);
      expect(read(o.c).pending.where((item) => item.isRejected), hasLength(1));
      o.c.dispose();
    });
  });

  group('the conflict author', () {
    testWidgets('is filled in once the events reach the nack seq', (t) async {
      final o = open(announceConflicts: false);
      await run(t, 10);
      o.g.simulateRemoteMove(
        cardId: 'c-audit',
        toColumnId: DemoIds.review,
        actorId: DemoIds.anya,
        deliver: false,
      );
      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);

      final waiting = read(o.c).cardRejection('c-audit')!;
      expect(waiting.reason, NackReason.versionConflict);
      expect(waiting.atSeq, 1285);
      expect(waiting.actorId, isNull);

      o.g.publishCard('c-audit');
      await run(t, 10);

      expect(read(o.c).cardRejection('c-audit')!.actorId, DemoIds.anya);
      o.c.dispose();
    });
  });

  group('the board title in the sidebar', () {
    testWidgets('follows board.renamed', (t) async {
      final o = open();
      await run(t, 10);
      expect(o.c.read(boardListProvider).first.title, 'Запуск Cardo 1.0');

      o.g.server.renameBoard('Новое имя');
      await run(t, 10);

      expect(o.c.read(boardListProvider).first.title, 'Новое имя');
      expect(
        o.c.read(boardListProvider).skip(1).map((item) => item.title),
        isNot(contains('Новое имя')),
      );
      o.c.dispose();
    });
  });

  group('a draft whose submitted op was abandoned', () {
    testWidgets('stays editable instead of becoming a false conflict', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      final notifier = o.c.read(boardNotifierProvider.notifier);
      final opId = notifier.editCardDescription(
        cardId: DemoIds.handshakeCard,
        description: 'my text',
        baseDescriptionVersion: 1,
      )!;
      final draft = CardDraft(
        cardId: DemoIds.handshakeCard,
        text: 'my text',
        baseDescriptionVersion: 1,
      ).submittedAs(opId);
      clock = clock.add(const Duration(hours: 25));
      await run(t, 900);

      final state = read(o.c);
      expect(state.pending, isEmpty);
      expect(state.abandoned, contains(opId));
      final next = reconcileDraft(draft, state)!;
      expect(next.conflict, isFalse);
      expect(next.submitted, isFalse);
      expect(next.text, 'my text');
      expect(next.baseDescriptionVersion, 1);
      o.c.dispose();
    });

    test('an op that vanished without being abandoned still rebases', () {
      final confirmed = demoBoard();
      final state = BoardSyncState(
        confirmed: confirmed,
        lastSeq: confirmed.seq,
        pending: const <PendingOp>[],
        connection: ConnectionStatus.connected,
      );
      final draft = CardDraft(
        cardId: DemoIds.handshakeCard,
        text: 'my text',
        baseDescriptionVersion: 1,
      ).submittedAs('gone');

      final next = reconcileDraft(draft, state)!;

      expect(next.baseDescriptionVersion, 2);
    });
  });
}
