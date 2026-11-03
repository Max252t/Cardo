import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/core/realtime/realtime_policy.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/event_factory.dart';

final DateTime t0 = DateTime.utc(2026, 1, 1, 12);

PendingOp pendingOp(
  BoardOp op, {
  DateTime? at,
  PendingOpStatus status = PendingOpStatus.sent,
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

void main() {
  group('applyServerEvents', () {
    test('no events return the same state', () {
      final state = stateOf([pendingOp(move('o', 'a1', colB))]);

      expect(identical(state.applyServerEvents(const []), state), isTrue);
    });

    test('events advance confirmed and lastSeq', () {
      final state = stateOf(const []);

      final next = state.applyServerEvents([
        renamed(11, title: 'One'),
        renamed(12, title: 'Two'),
      ]);

      expect(next.confirmed.title, 'Two');
      expect(next.confirmed.seq, 12);
      expect(next.lastSeq, 12);
    });

    test('the event carrying its op_id resolves the pending op', () {
      final state = stateOf([
        pendingOp(move('mine', 'a1', colB)),
        pendingOp(move('other', 'a2', colB)),
      ]);

      final next = state.applyServerEvents([
        cardMoved(11, 'a1', colA, colB, 'q', opId: 'mine'),
      ]);

      expect(next.pending.map((p) => p.opId), ['other']);
      expect(next.confirmed.cardById('a1')!.columnId, colB);
      expect(next.confirmed.cardById('a1')!.rank, 'q');
    });

    test('an event without op_id leaves pending alone', () {
      final state = stateOf([pendingOp(move('mine', 'a1', colB))]);

      final next = state.applyServerEvents([renamed(11)]);

      expect(next.pending, state.pending);
    });

    test('an op_id that is not pending changes nothing in the queue', () {
      final state = stateOf([pendingOp(move('mine', 'a1', colB))]);

      final next = state.applyServerEvents([renamed(11, opId: 'stranger')]);

      expect(next.pending.single.opId, 'mine');
    });

    test('a rejected op with the resolved op_id is removed as well', () {
      final state = stateOf([
        pendingOp(
          move('mine', 'a1', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.internal),
        ),
      ]);

      final next = state.applyServerEvents([
        cardMoved(11, 'a1', colA, colB, 'q', opId: 'mine'),
      ]);

      expect(next.pending, isEmpty);
    });

    test('the view re-applies the remaining pending on the new confirmed', () {
      final state = stateOf([pendingOp(move('mine', 'a1', colC))]);

      final next = state.applyServerEvents([renamed(11, title: 'Remote')]);

      expect(next.view.title, 'Remote');
      expect(next.view.cardById('a1')!.columnId, colC);
      expect(next.confirmed.cardById('a1')!.columnId, colA);
    });

    test('the connection, ended and countdown are preserved', () {
      final state = BoardSyncState(
        confirmed: makeBoard(),
        lastSeq: 10,
        pending: const [],
        connection: ConnectionStatus.reconnecting,
        reconnectSeconds: 4,
        ended: BoardEndReason.removed,
      );

      final next = state.applyServerEvents([renamed(11)]);

      expect(next.connection, ConnectionStatus.reconnecting);
      expect(next.reconnectSeconds, 4);
      expect(next.ended, BoardEndReason.removed);
    });
  });

  group('replaceConfirmed', () {
    test('swaps the board and lastSeq but keeps pending', () {
      final state = stateOf([pendingOp(move('mine', 'a1', colB))]);
      final snapshot = makeBoard().copyWith(seq: 99, title: 'From snapshot');

      final next = state.replaceConfirmed(snapshot);

      expect(next.confirmed.title, 'From snapshot');
      expect(next.lastSeq, 99);
      expect(next.pending.single.opId, 'mine');
    });
  });

  group('withoutStale', () {
    const maxAge = RealtimePolicy.pendingMaxAge;

    test('nothing stale returns the same state', () {
      final state = stateOf([pendingOp(move('o', 'a1', colB))]);

      final next = state.withoutStale(t0.add(const Duration(hours: 5)), maxAge);

      expect(identical(next, state), isTrue);
    });

    test('exactly 24 hours is kept, one microsecond over is dropped', () {
      final state = stateOf([pendingOp(move('o', 'a1', colB))]);

      final kept = state.withoutStale(t0.add(maxAge), maxAge);
      final dropped = state.withoutStale(
        t0.add(maxAge + const Duration(microseconds: 1)),
        maxAge,
      );

      expect(kept.pending, hasLength(1));
      expect(dropped.pending, isEmpty);
    });

    test('only the old operations go', () {
      final state = stateOf([
        pendingOp(move('old', 'a1', colB), at: t0),
        pendingOp(
          move('young', 'a2', colB),
          at: t0.add(const Duration(hours: 20)),
        ),
      ]);

      final next = state.withoutStale(
        t0.add(const Duration(hours: 30)),
        maxAge,
      );

      expect(next.pending.map((p) => p.opId), ['young']);
    });

    test('a stale create takes every dependant of that card with it', () {
      final state = stateOf([
        pendingOp(
          const CreateCard(
            opId: 'create',
            cardId: 'new',
            columnId: colA,
            title: 'T',
            actorId: 'u1',
          ),
          at: t0,
        ),
        pendingOp(
          const EditCardTitle(
            opId: 'edit',
            cardId: 'new',
            title: 'T2',
            actorId: 'u1',
          ),
          at: t0.add(const Duration(hours: 20)),
        ),
        pendingOp(
          move('mv', 'new', colB),
          at: t0.add(const Duration(hours: 21)),
        ),
        pendingOp(
          move('unrelated', 'a1', colB),
          at: t0.add(const Duration(hours: 22)),
        ),
      ]);

      final next = state.withoutStale(
        t0.add(const Duration(hours: 30)),
        maxAge,
      );

      expect(next.pending.map((p) => p.opId), ['unrelated']);
    });

    test('a stale non-create does not drop the later ops of that card', () {
      final state = stateOf([
        pendingOp(move('old', 'a1', colB), at: t0),
        pendingOp(
          move('young', 'a1', colC),
          at: t0.add(const Duration(hours: 20)),
        ),
      ]);

      final next = state.withoutStale(
        t0.add(const Duration(hours: 30)),
        maxAge,
      );

      expect(next.pending.map((p) => p.opId), ['young']);
    });

    test('rejected operations are never dropped by age', () {
      final state = stateOf([
        pendingOp(
          move('rej', 'a1', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.forbidden),
        ),
      ]);

      final next = state.withoutStale(t0.add(const Duration(days: 3)), maxAge);

      expect(next.pending, hasLength(1));
    });
  });

  group('rebased', () {
    test('everything still applicable keeps the same state', () {
      final state = stateOf([pendingOp(move('o', 'a1', colB))]);

      expect(identical(state.rebased(), state), isTrue);
    });

    test('an op on a card archived remotely is dropped', () {
      final state = stateOf([
        pendingOp(move('mine', 'a1', colB)),
        pendingOp(move('kept', 'a2', colB)),
      ]).applyServerEvents([cardArchived(11, 'a1', colA)]);

      final next = state.rebased();

      expect(next.pending.map((p) => p.opId), ['kept']);
    });

    test('an op into a column archived remotely is dropped', () {
      final state = stateOf([pendingOp(move('mine', 'a1', colB))])
          .replaceConfirmed(
            makeBoard().copyWith(
              columns: makeBoard().columns.where((c) => c.id != colB).toList(),
            ),
          );

      expect(state.rebased().pending, isEmpty);
    });

    test('a dependant of a create that cannot apply is dropped too', () {
      final state = stateOf([
        pendingOp(
          const CreateCard(
            opId: 'create',
            cardId: 'new',
            columnId: 'gone',
            title: 'T',
            actorId: 'u1',
          ),
        ),
        pendingOp(move('mv', 'new', colB)),
      ]);

      expect(state.rebased().pending, isEmpty);
    });

    test('a create followed by its edit applies in sequence', () {
      final state = stateOf([
        pendingOp(
          const CreateCard(
            opId: 'create',
            cardId: 'new',
            columnId: colA,
            title: 'T',
            actorId: 'u1',
          ),
        ),
        pendingOp(
          const EditCardTitle(
            opId: 'edit',
            cardId: 'new',
            title: 'T2',
            actorId: 'u1',
          ),
        ),
      ]);

      expect(state.rebased().pending, hasLength(2));
    });

    test('rejected ones always stay', () {
      final state = stateOf([
        pendingOp(
          move('rej', 'ghost', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.notFound),
        ),
      ]);

      expect(state.rebased().pending, hasLength(1));
    });
  });

  group('views', () {
    test('view includes rejected ops while liveView excludes them', () {
      final state = stateOf([
        pendingOp(
          move('rej', 'a1', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.forbidden),
        ),
        pendingOp(move('live', 'a2', colC)),
      ]);

      expect(state.view.cardById('a1')!.columnId, colB);
      expect(state.liveView.cardById('a1')!.columnId, colA);
      expect(state.liveView.cardById('a2')!.columnId, colC);
    });

    test('cardStatus tracks confirmed, pending and rejected', () {
      final state = stateOf([
        pendingOp(move('p', 'a1', colB)),
        pendingOp(
          move('r', 'a2', colB),
          status: PendingOpStatus.rejected,
          rejection: const OpRejection(reason: NackReason.forbidden),
        ),
      ]);

      expect(state.cardStatus('a1'), CardSyncStatus.pending);
      expect(state.cardStatus('a2'), CardSyncStatus.rejected);
      expect(state.cardStatus('a3'), CardSyncStatus.confirmed);
    });

    test('withoutOps removes exactly the named ops', () {
      final state = stateOf([
        pendingOp(move('a', 'a1', colB)),
        pendingOp(move('b', 'a2', colB)),
      ]);

      expect(state.withoutOps({'a'}).pending.map((p) => p.opId), ['b']);
      expect(identical(state.withoutOps({'zzz'}), state), isTrue);
      expect(identical(state.withoutOps({}), state), isTrue);
    });
  });

  group('BoardEndReason', () {
    test('lists the reasons the UI distinguishes', () {
      expect(BoardEndReason.values.map((r) => r.name), [
        'removed',
        'boardDeleted',
        'accessLost',
        'sessionEnded',
        'unsupported',
      ]);
    });
  });
}
