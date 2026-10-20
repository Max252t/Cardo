import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

PendingOp _pending(
  BoardOp op, {
  PendingOpStatus status = PendingOpStatus.sent,
  OpRejection? rejection,
}) {
  return PendingOp(op: op, status: status, createdAt: _t, rejection: rejection);
}

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

void main() {
  group('liveView', () {
    test('skips rejected ops but keeps live ones in order', () {
      final state = _state(<PendingOp>[
        _pending(
          moveOp('a1', colB, opId: '1'),
          status: PendingOpStatus.rejected,
          rejection: rejection(NackReason.versionConflict),
        ),
        _pending(moveOp('a2', colB, opId: '2')),
      ]);
      expect(ids(state.view, colB), contains('a1'));
      expect(ids(state.liveView, colB), isNot(contains('a1')));
      expect(ids(state.liveView, colB), contains('a2'));
      expect(ids(state.liveView, colA), contains('a1'));
      expect(state.liveView.cardById('a1'), state.confirmed.cardById('a1'));
    });

    test('equals view without rejected ops', () {
      final state = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(state.liveView, state.view);
    });
  });

  group('view', () {
    test('equals confirmed with no pending ops', () {
      final state = _state(const <PendingOp>[]);
      expect(state.view, state.confirmed);
    });

    test('folds pending ops over confirmed in order', () {
      final ops = <BoardOp>[
        moveOp('a1', colB, opId: '1'),
        moveOp('a2', colB, afterId: 'a1', opId: '2'),
        const ArchiveCard(opId: '3', cardId: 'b1'),
      ];
      final state = _state(ops.map(_pending).toList());
      expect(state.view, applyOps(state.confirmed, ops));
      expect(ids(state.view, colB), <String>['b2', 'a1', 'a2']);
    });

    test('does not change confirmed', () {
      final state = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(ids(state.confirmed, colA), <String>['a1', 'a2', 'a3']);
      expect(ids(state.view, colA), <String>['a2', 'a3']);
    });

    test('rejected ops still participate in the view', () {
      final state = _state(<PendingOp>[
        _pending(
          moveOp('a1', colB),
          status: PendingOpStatus.rejected,
          rejection: rejection(NackReason.notFound),
        ),
      ]);
      expect(ids(state.view, colB), contains('a1'));
    });
  });

  group('cardStatus', () {
    test('confirmed when nothing pending touches the card', () {
      final state = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(state.cardStatus('a2'), CardSyncStatus.confirmed);
    });

    test('pending for queued and sent ops', () {
      for (final status in <PendingOpStatus>[
        PendingOpStatus.queued,
        PendingOpStatus.sent,
      ]) {
        final state = _state(<PendingOp>[
          _pending(moveOp('a1', colB), status: status),
        ]);
        expect(state.cardStatus('a1'), CardSyncStatus.pending);
      }
    });

    test('rejected wins over pending', () {
      final state = _state(<PendingOp>[
        _pending(moveOp('a1', colB, opId: '1')),
        _pending(
          moveOp('a1', colC, opId: '2'),
          status: PendingOpStatus.rejected,
          rejection: rejection(NackReason.versionConflict),
        ),
        _pending(moveOp('a1', colA, opId: '3')),
      ]);
      expect(state.cardStatus('a1'), CardSyncStatus.rejected);
    });

    test('other cards are unaffected by a rejection', () {
      final state = _state(<PendingOp>[
        _pending(
          moveOp('a1', colB),
          status: PendingOpStatus.rejected,
          rejection: rejection(NackReason.versionConflict),
        ),
      ]);
      expect(state.cardStatus('a2'), CardSyncStatus.confirmed);
    });
  });

  group('cardRejection', () {
    test('null without rejected ops', () {
      final state = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(state.cardRejection('a1'), isNull);
    });

    test('returns the rejection of that card', () {
      const nack = OpRejection(
        reason: NackReason.versionConflict,
        actorId: 'u2',
        atSeq: 11,
      );
      final state = _state(<PendingOp>[
        _pending(
          moveOp('a1', colB),
          status: PendingOpStatus.rejected,
          rejection: nack,
        ),
      ]);
      expect(state.cardRejection('a1'), nack);
      expect(state.cardRejection('a2'), isNull);
      expect(state.rejected.length, 1);
    });
  });

  group('value semantics', () {
    test('pending list is unmodifiable', () {
      final state = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(() => state.pending.clear(), throwsUnsupportedError);
    });

    test('equality and copyWith', () {
      final a = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      final b = _state(<PendingOp>[_pending(moveOp('a1', colB))]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(lastSeq: 11), isNot(a));
      expect(a.copyWith(connection: ConnectionStatus.offline), isNot(a));
      expect(a.copyWith(), a);
    });

    test('OpRejection.withSeq keeps an existing seq', () {
      const first = OpRejection(reason: NackReason.internal, atSeq: 3);
      expect(first.withSeq(9).atSeq, 3);
      const second = OpRejection(reason: NackReason.internal);
      expect(second.withSeq(9).atSeq, 9);
    });

    test('PendingOp copyWith and isRejected', () {
      final item = _pending(moveOp('a1', colB));
      expect(item.isRejected, isFalse);
      expect(item.opId, 'op');
      final rejected = item.copyWith(status: PendingOpStatus.rejected);
      expect(rejected.isRejected, isTrue);
      expect(rejected, isNot(item));
    });
  });

  group('BoardOp equality', () {
    test('MoveCard', () {
      expect(moveOp('a', colA), moveOp('a', colA));
      expect(moveOp('a', colA).hashCode, moveOp('a', colA).hashCode);
      expect(moveOp('a', colA), isNot(moveOp('a', colB)));
      expect(moveOp('a', colA, afterId: 'x'), isNot(moveOp('a', colA)));
    });

    test('Create, Edit, Archive', () {
      const create = CreateCard(
        opId: 'o',
        cardId: 'c',
        columnId: colA,
        title: 't',
        actorId: 'u',
      );
      expect(
        create,
        const CreateCard(
          opId: 'o',
          cardId: 'c',
          columnId: colA,
          title: 't',
          actorId: 'u',
        ),
      );
      expect(create.hashCode, isA<int>());
      const edit = EditCardTitle(
        opId: 'o',
        cardId: 'c',
        title: 't',
        actorId: 'u',
      );
      expect(
        edit,
        const EditCardTitle(opId: 'o', cardId: 'c', title: 't', actorId: 'u'),
      );
      expect(edit, isNot(create));
      expect(
        const ArchiveCard(opId: 'o', cardId: 'c'),
        const ArchiveCard(opId: 'o', cardId: 'c'),
      );
      expect(
        const ArchiveCard(opId: 'o', cardId: 'c'),
        isNot(const ArchiveCard(opId: 'p', cardId: 'c')),
      );
    });
  });
}
