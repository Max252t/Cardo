import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/sync_views.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/event_factory.dart';

final DateTime t0 = DateTime.utc(2026, 1, 1, 12);
const Duration maxAge = Duration(hours: 24);

PendingOp queued(
  BoardOp op, {
  DateTime? at,
  PendingOpStatus status = PendingOpStatus.queued,
  OpRejection? rejection,
}) {
  return PendingOp(
    op: op,
    status: status,
    createdAt: at ?? t0,
    rejection: rejection,
  );
}

BoardSyncState stateOf(List<PendingOp> pending, {BoardModel? confirmed}) {
  final board = confirmed ?? makeBoard();
  return BoardSyncState(
    confirmed: board,
    lastSeq: board.seq,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

MoveCard move(String opId, String cardId, String to) =>
    MoveCard(opId: opId, cardId: cardId, toColumnId: to, baseVersion: 1);

BoardSyncState reject(
  BoardSyncState state,
  String opId,
  NackReason reason, {
  String? actorId,
}) {
  final marked = state.copyWith(
    pending: <PendingOp>[
      for (final item in state.pending)
        item.opId == opId
            ? item.copyWith(
                status: PendingOpStatus.rejected,
                rejection: OpRejection(reason: reason, actorId: actorId),
              )
            : item,
    ],
  );
  return marked.withRejectionLogged(opId).settleBatch();
}

BoardSyncState confirm(BoardSyncState state, String opId) {
  return state.withoutOps(<String>{opId}).settleBatch();
}

void main() {
  group('describeRejected', () {
    final board = makeBoard();

    test('a move names the card and the destination column', () {
      final entry = describeRejected(move('m', 'a1', colB), board, board);

      expect(entry.kind, RejectedOpKind.move);
      expect(entry.subject, 'Card a1');
      expect(entry.destination, 'B');
      expect(entry.cardId, 'a1');
      expect(entry.copyText, isEmpty);
    });

    test('a create keeps its own title and description to copy', () {
      const op = CreateCard(
        opId: 'c',
        cardId: 'new',
        columnId: colA,
        title: 'Title',
        description: 'Body',
        actorId: 'u1',
      );

      final entry = describeRejected(op, board, board);

      expect(entry.kind, RejectedOpKind.create);
      expect(entry.subject, 'Title');
      expect(entry.copyText, 'Title\nBody');
      expect(entry.cardId, isNull);
    });

    test('a description edit offers its text for copying', () {
      const op = EditCardDescription(
        opId: 'd',
        cardId: 'a1',
        description: 'Draft',
        baseDescriptionVersion: 0,
        actorId: 'u1',
      );

      final entry = describeRejected(op, board, board);

      expect(entry.kind, RejectedOpKind.editDescription);
      expect(entry.copyText, 'Draft');
    });

    test('the title is taken from the confirmed board, not from the op', () {
      const op = EditCardTitle(
        opId: 't',
        cardId: 'a1',
        title: 'Renamed',
        actorId: 'u1',
      );

      final entry = describeRejected(op, board, board);

      expect(entry.subject, 'Card a1');
      expect(entry.copyText, 'Renamed');
    });

    test('column ops name the column', () {
      const rename = RenameColumn(opId: 'r', columnId: colA, title: 'X');
      const archive = ArchiveColumn(opId: 'a', columnId: colB);

      expect(describeRejected(rename, board, board).subject, 'A');
      expect(
        describeRejected(archive, board, board).kind,
        RejectedOpKind.archiveColumn,
      );
      expect(describeRejected(archive, board, board).subject, 'B');
    });

    test('the actor comes from the rejection', () {
      final entry = describeRejected(
        move('m', 'a1', colB),
        board,
        board,
        rejection: const OpRejection(
          reason: NackReason.versionConflict,
          actorId: 'u2',
        ),
      );

      expect(entry.actorId, 'u2');
      expect(entry.dropped, isFalse);
    });
  });

  group('RejectionLog', () {
    RejectedOp entry(String id) =>
        RejectedOp(opId: id, kind: RejectedOpKind.move);

    test('keeps order and ignores duplicates', () {
      final log = const RejectionLog.empty().add([entry('a'), entry('b')]);

      expect(log.add([entry('a')]), same(log));
      expect(log.entries.map((e) => e.opId), ['a', 'b']);
    });

    test('cap drops the oldest unprotected entries only', () {
      final log = const RejectionLog.empty().add([
        for (var i = 0; i < RejectionLog.maxEntries + 5; i++) entry('op$i'),
      ]);

      final capped = log.capped({'op0'});

      expect(capped.entries, hasLength(RejectionLog.maxEntries));
      expect(capped.contains('op0'), isTrue);
      expect(capped.contains('op1'), isFalse);
      expect(capped.contains('op5'), isFalse);
      expect(capped.contains('op6'), isTrue);
    });

    test('fills the actor only once', () {
      final log = const RejectionLog.empty().add([entry('a')]);

      final named = log.withActor('a', 'u2');

      expect(named.entries.single.actorId, 'u2');
      expect(identical(named.withActor('a', 'u3'), named), isTrue);
      expect(named.withActor('missing', 'u3'), same(named));
    });

    test('forIds filters in log order', () {
      final log = const RejectionLog.empty().add([
        entry('a'),
        entry('b'),
        entry('c'),
      ]);

      expect(log.forIds(['c', 'a']).map((e) => e.opId), ['a', 'c']);
    });
  });

  group('silent drops are journaled', () {
    test('rebased logs an op whose target is gone', () {
      final state = stateOf([
        queued(move('mine', 'a1', colB)),
        queued(move('kept', 'a2', colB)),
      ]).applyServerEvents([cardArchived(11, 'a1', colA)]);

      final next = state.rebased();

      final logged = next.rejections.entries.single;
      expect(logged.opId, 'mine');
      expect(logged.dropCause, DropCause.targetGone);
      expect(logged.subject, 'Card a1');
      expect(next.abandoned, contains('mine'));
    });

    test('withoutStale logs the stale op and its dependants', () {
      const create = CreateCard(
        opId: 'create',
        cardId: 'new',
        columnId: colA,
        title: 'T',
        actorId: 'u1',
      );
      final state = stateOf([
        queued(create, at: t0),
        queued(move('mv', 'new', colB), at: t0.add(const Duration(hours: 30))),
      ]);

      final next = state.withoutStale(
        t0.add(const Duration(hours: 40)),
        maxAge,
      );

      final causes = {
        for (final entry in next.rejections.entries)
          entry.opId: entry.dropCause,
      };
      expect(causes, {'create': DropCause.stale, 'mv': DropCause.targetGone});
    });

    test('a description conflict is not journaled when it is dropped', () {
      const edit = EditCardDescription(
        opId: 'd',
        cardId: 'a1',
        description: 'x',
        baseDescriptionVersion: 0,
        actorId: 'u1',
      );
      final state = stateOf([
        queued(
          edit,
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.versionConflict),
        ),
      ]);

      expect(state.withRejectionLogged('d'), same(state));
    });
  });

  group('reconnect batch', () {
    test('the first connection does not start a batch', () {
      final state = stateOf([queued(move('a', 'a1', colB))]);

      final next = state.afterReady(t0, maxAge, reconnect: false);

      expect(next.batch, isNull);
      expect(next.summary, isNull);
    });

    test('a reconnect with nothing pending starts nothing', () {
      final next = stateOf(const []).afterReady(t0, maxAge);

      expect(next.batch, isNull);
      expect(next.summary, isNull);
    });

    test('the batch is the queue that was waiting at ready', () {
      final state = stateOf([
        queued(move('a', 'a1', colB)),
        queued(move('b', 'a2', colB)),
      ]);

      final next = state.afterReady(t0, maxAge);

      expect(next.batch!.ids, ['a', 'b']);
      expect(next.summary, isNull);
    });

    test('ops created after ready do not belong to the batch', () {
      final started = stateOf([queued(move('a', 'a1', colB))])
          .afterReady(t0, maxAge);
      final later = started.copyWith(
        pending: [
          ...started.pending,
          queued(move('late', 'a2', colB), status: PendingOpStatus.sent),
        ],
      );

      final done = confirm(later, 'a');

      expect(done.batch, isNull);
      expect(done.summary, isNull);
      expect(done.pendingById('late'), isNotNull);
    });

    test('a fully confirmed batch ends without a summary', () {
      var state = stateOf([
        queued(move('a', 'a1', colB)),
        queued(move('b', 'a2', colB)),
      ]).afterReady(t0, maxAge);

      state = confirm(state, 'a');
      expect(state.batch, isNotNull);
      state = confirm(state, 'b');

      expect(state.batch, isNull);
      expect(state.summary, isNull);
    });

    test('the batch waits for every op and then summarises failures', () {
      var state = stateOf([
        queued(move('a', 'a1', colB)),
        queued(move('b', 'a2', colB)),
        queued(move('c', 'a3', colB)),
      ]).afterReady(t0, maxAge);

      state = reject(state, 'b', NackReason.versionConflict, actorId: 'u2');
      expect(state.batch, isNotNull);
      expect(state.summary, isNull);
      state = confirm(state, 'a');
      expect(state.summary, isNull);
      state = confirm(state, 'c');

      expect(state.batch, isNull);
      expect(state.summary!.failedIds, ['b']);
      expect(state.summary!.savedCount, 2);
      expect(state.rejections.entries.single.actorId, 'u2');
    });

    test('silently dropped ops count as failed right away', () {
      final state = stateOf([
        queued(move('gone', 'a1', colB)),
        queued(move('ok', 'a2', colB)),
      ]).applyServerEvents([cardArchived(11, 'a1', colA)]);

      var next = state.afterReady(t0, maxAge);
      expect(next.summary, isNull);
      next = confirm(next, 'ok');

      expect(next.summary!.failedIds, ['gone']);
      expect(next.summary!.savedCount, 1);
      expect(next.rejections.entries.single.dropCause, DropCause.targetGone);
    });

    test('a stale op is reported through the same summary', () {
      final state = stateOf([
        queued(move('old', 'a1', colB), at: t0),
        queued(move('new', 'a2', colB), at: t0.add(const Duration(hours: 30))),
      ]);

      var next = state.afterReady(t0.add(const Duration(hours: 40)), maxAge);
      next = confirm(next, 'new');

      expect(next.summary!.failedIds, ['old']);
      expect(next.rejections.entries.single.dropCause, DropCause.stale);
    });

    test('a batch that lost every op reports it immediately', () {
      final state = stateOf([queued(move('gone', 'a1', colB))])
          .applyServerEvents([cardArchived(11, 'a1', colA)]);

      final next = state.afterReady(t0, maxAge);

      expect(next.batch, isNull);
      expect(next.summary!.failedCount, 1);
      expect(next.summary!.savedCount, 0);
    });

    test('dependants of a rejected create fail with it and do not wait', () {
      const create = CreateCard(
        opId: 'create',
        cardId: 'new',
        columnId: colA,
        title: 'Fresh',
        actorId: 'u1',
      );
      var state = stateOf([
        queued(create),
        queued(move('mv', 'new', colB)),
        queued(move('other', 'a1', colB)),
      ]).afterReady(t0, maxAge);

      state = reject(state, 'create', NackReason.notFound);
      state = confirm(state, 'other');

      expect(state.batch, isNull);
      expect(state.summary!.failedIds, ['create', 'mv']);
      expect(state.summary!.savedCount, 1);
      final byId = {for (final e in state.rejections.entries) e.opId: e};
      expect(byId['mv']!.dropCause, DropCause.targetGone);
      expect(byId['create']!.rejection!.reason, NackReason.notFound);
    });

    test('a description conflict is neither failed nor saved', () {
      const edit = EditCardDescription(
        opId: 'd',
        cardId: 'a1',
        description: 'x',
        baseDescriptionVersion: 0,
        actorId: 'u1',
      );
      var state = stateOf([queued(edit), queued(move('ok', 'a2', colB))])
          .afterReady(t0, maxAge);

      state = reject(state, 'd', NackReason.versionConflict);
      state = confirm(state, 'ok');

      expect(state.summary, isNull);
      expect(state.rejections.isEmpty, isTrue);
      expect(state.pendingById('d')!.isDescriptionConflict, isTrue);
    });

    test('rejections made before the batch are not part of its summary', () {
      var state = stateOf([
        queued(
          move('old', 'a3', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.forbidden),
        ),
        queued(move('a', 'a1', colB)),
        queued(move('b', 'a2', colB)),
      ]).withRejectionLogged('old');

      state = state.afterReady(t0, maxAge);
      state = reject(state, 'a', NackReason.forbidden);
      state = confirm(state, 'b');

      expect(state.summary!.failedIds, ['a']);
      expect(state.rejections.entries, hasLength(2));
    });

    test('a second reconnect before the end extends the same batch', () {
      var state = stateOf([queued(move('a', 'a1', colB))])
          .afterReady(t0, maxAge);
      state = state.copyWith(
        pending: [...state.pending, queued(move('b', 'a2', colB))],
      );

      state = state.afterReady(t0, maxAge);

      expect(state.batch!.ids, ['a', 'b']);
    });

    test('summaries of consecutive batches accumulate until dismissed', () {
      var state = stateOf([queued(move('a', 'a1', colB))])
          .afterReady(t0, maxAge);
      state = reject(state, 'a', NackReason.forbidden);
      state = state.copyWith(pending: [queued(move('b', 'a2', colB))]);
      state = state.afterReady(t0, maxAge);
      state = reject(state, 'b', NackReason.forbidden);

      expect(state.summary!.failedIds, ['a', 'b']);
      expect(state.dismissedSummary().summary, isNull);
      expect(state.dismissedSummary().rejections.entries, hasLength(2));
    });

    test('acknowledging clears the summary and the journal', () {
      var state = stateOf([queued(move('a', 'a1', colB))])
          .afterReady(t0, maxAge);
      state = reject(state, 'a', NackReason.forbidden);

      final cleared = state.acknowledgedRejections();

      expect(cleared.summary, isNull);
      expect(cleared.rejections.isEmpty, isTrue);
      expect(identical(cleared.acknowledgedRejections(), cleared), isTrue);
    });
  });

  group('journal limits and acknowledgement', () {
    test('a batch of 60 rejections keeps every entry and counts', () {
      var state = stateOf([
        for (var i = 0; i < 60; i++) queued(move('o$i', 'a1', colB)),
      ]).afterReady(t0, maxAge);

      for (var i = 0; i < 60; i++) {
        state = reject(state, 'o$i', NackReason.forbidden);
      }

      expect(state.summary!.failedCount, 60);
      expect(state.summary!.savedCount, 0);
      expect(state.rejections.entries, hasLength(60));
      expect(
        rejectedItemsOf(state.summary, state.rejections, state.view),
        hasLength(60),
      );
    });

    test('acknowledging keeps entries of a batch that is still open', () {
      var state = stateOf([queued(move('a', 'a1', colB))])
          .afterReady(t0, maxAge);
      state = reject(state, 'a', NackReason.forbidden);
      state = state.copyWith(
        pending: [queued(move('x', 'a2', colB)), queued(move('y', 'a3', colB))],
      );
      state = state.afterReady(t0, maxAge);
      state = reject(state, 'x', NackReason.forbidden);

      state = state.acknowledgedRejections();
      expect(state.summary, isNull);
      state = confirm(state, 'y');

      expect(state.summary!.failedIds, ['x']);
      expect(state.summary!.savedCount, 1);
    });

    test('a description conflict dropped later is not counted as saved', () {
      const edit = EditCardDescription(
        opId: 'd',
        cardId: 'a1',
        description: 'x',
        baseDescriptionVersion: 0,
        actorId: 'u1',
      );
      var state = stateOf([
        queued(edit),
        queued(move('f', 'a2', colB)),
        queued(move('ok', 'a3', colB)),
      ]).afterReady(t0, maxAge);

      state = reject(state, 'd', NackReason.versionConflict);
      state = reject(state, 'f', NackReason.forbidden);
      state = state.withoutOps({'d'});
      state = confirm(state, 'ok');

      expect(state.summary!.failedIds, ['f']);
      expect(state.summary!.savedCount, 1);
    });
  });

  group('afterSnapshot', () {
    test('ops dropped by a resync are summarised', () {
      final state = stateOf([
        queued(move('gone', 'a1', colB), status: PendingOpStatus.sent),
        queued(move('ok', 'a2', colB), status: PendingOpStatus.sent),
      ]);
      final snapshot = makeBoard().copyWith(
        cards: makeBoard().cards.where((c) => c.id != 'a1').toList(),
      );

      final next = state.afterSnapshot(snapshot);

      expect(next.batch, isNull);
      expect(next.summary!.failedIds, ['gone']);
      expect(next.summary!.savedCount, 0);
      expect(next.rejections.entries.single.dropCause, DropCause.targetGone);
      expect(next.pendingById('ok'), isNotNull);
    });

    test('a snapshot that keeps every op reports nothing', () {
      final state = stateOf([queued(move('a', 'a1', colB))]);

      final next = state.afterSnapshot(makeBoard());

      expect(next.batch, isNull);
      expect(next.summary, isNull);
    });
  });

  group('waitingCount', () {
    test('counts only ops that still wait for the server', () {
      final state = stateOf([
        queued(move('a', 'a1', colB)),
        queued(
          move('b', 'a2', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.forbidden),
        ),
      ]);

      expect(state.waitingCount, 1);
    });
  });
}
