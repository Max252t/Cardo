import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

PendingOp _pending(
  BoardOp op, {
  PendingOpStatus status = PendingOpStatus.sent,
  NackReason? reason,
}) {
  return PendingOp(
    op: op,
    status: status,
    createdAt: _t,
    rejection: reason == null ? null : OpRejection(reason: reason),
  );
}

PendingOp _rejected(BoardOp op, NackReason reason) =>
    _pending(op, status: PendingOpStatus.rejected, reason: reason);

EditCardDescription _describe(String cardId, {String opId = 'd'}) {
  return EditCardDescription(
    opId: opId,
    cardId: cardId,
    description: 'text',
    baseDescriptionVersion: 1,
    actorId: 'u1',
  );
}

EditCardTitle _retitle(String cardId, {String opId = 't'}) {
  return EditCardTitle(opId: opId, cardId: cardId, title: 'new', actorId: 'u1');
}

CreateCard _create(String cardId, {String opId = 'c'}) {
  return CreateCard(
    opId: opId,
    cardId: cardId,
    columnId: colA,
    title: 'fresh',
    actorId: 'u1',
  );
}

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

typedef _Expected = ({
  CardSyncStatus status,
  NackReason? rejection,
  NackReason? blocking,
  bool hasBlocking,
});

void main() {
  group('PendingOp.isBlocking', () {
    test('a queued or sent operation never blocks', () {
      expect(
        _pending(_retitle('a1'), status: PendingOpStatus.queued).isBlocking,
        isFalse,
      );
      expect(_pending(_retitle('a1')).isBlocking, isFalse);
    });

    test('a rejected non-conflict operation blocks', () {
      for (final reason in NackReason.values) {
        expect(
          _rejected(_retitle('a1'), reason).isBlocking,
          isTrue,
          reason: reason.name,
        );
      }
    });

    test('a rejected description conflict does not block', () {
      final item = _rejected(_describe('a1'), NackReason.versionConflict);
      expect(item.isRejected, isTrue);
      expect(item.isDescriptionConflict, isTrue);
      expect(item.isBlocking, isFalse);
    });

    test('a rejected description edit with another reason blocks', () {
      expect(
        _rejected(_describe('a1'), NackReason.forbidden).isBlocking,
        isTrue,
      );
    });

    test('a version conflict on a non-description operation blocks', () {
      expect(
        _rejected(_retitle('a1'), NackReason.versionConflict).isBlocking,
        isTrue,
      );
    });
  });

  group('BoardSyncState.hasRejectedCreate', () {
    test('is true only for a rejected CreateCard of that card', () {
      final state = _state(<PendingOp>[
        _rejected(_create('n1'), NackReason.forbidden),
        _pending(_create('n2', opId: 'c2')),
        _rejected(_retitle('n3', opId: 't3'), NackReason.forbidden),
      ]);
      expect(state.hasRejectedCreate('n1'), isTrue);
      expect(state.hasRejectedCreate('n2'), isFalse);
      expect(state.hasRejectedCreate('n3'), isFalse);
      expect(state.hasRejectedCreate('missing'), isFalse);
    });

    test('is false without pending operations', () {
      expect(_state(const <PendingOp>[]).hasRejectedCreate('n1'), isFalse);
    });
  });

  group('card level status and rejection', () {
    final scenarios = <String, (List<PendingOp>, _Expected)>{
      'no operations': (
        const <PendingOp>[],
        (
          status: CardSyncStatus.confirmed,
          rejection: null,
          blocking: null,
          hasBlocking: false,
        ),
      ),
      'only a live operation': (
        <PendingOp>[_pending(_retitle('a1'))],
        (
          status: CardSyncStatus.pending,
          rejection: null,
          blocking: null,
          hasBlocking: false,
        ),
      ),
      'only a queued operation': (
        <PendingOp>[_pending(_retitle('a1'), status: PendingOpStatus.queued)],
        (
          status: CardSyncStatus.pending,
          rejection: null,
          blocking: null,
          hasBlocking: false,
        ),
      ),
      'a blocking rejection': (
        <PendingOp>[_rejected(_retitle('a1'), NackReason.forbidden)],
        (
          status: CardSyncStatus.rejected,
          rejection: NackReason.forbidden,
          blocking: NackReason.forbidden,
          hasBlocking: true,
        ),
      ),
      'only a description conflict': (
        <PendingOp>[_rejected(_describe('a1'), NackReason.versionConflict)],
        (
          status: CardSyncStatus.rejected,
          rejection: NackReason.versionConflict,
          blocking: null,
          hasBlocking: false,
        ),
      ),
      'a conflict followed by a blocking rejection': (
        <PendingOp>[
          _rejected(_describe('a1'), NackReason.versionConflict),
          _rejected(_retitle('a1'), NackReason.notFound),
        ],
        (
          status: CardSyncStatus.rejected,
          rejection: NackReason.versionConflict,
          blocking: NackReason.notFound,
          hasBlocking: true,
        ),
      ),
      'a blocking rejection followed by a conflict': (
        <PendingOp>[
          _rejected(_retitle('a1'), NackReason.internal),
          _rejected(_describe('a1', opId: 'd2'), NackReason.versionConflict),
        ],
        (
          status: CardSyncStatus.rejected,
          rejection: NackReason.internal,
          blocking: NackReason.internal,
          hasBlocking: true,
        ),
      ),
      'a live operation then a conflict': (
        <PendingOp>[
          _pending(_retitle('a1')),
          _rejected(_describe('a1'), NackReason.versionConflict),
        ],
        (
          status: CardSyncStatus.rejected,
          rejection: NackReason.versionConflict,
          blocking: null,
          hasBlocking: false,
        ),
      ),
      'operations of another card only': (
        <PendingOp>[_rejected(_retitle('a2'), NackReason.forbidden)],
        (
          status: CardSyncStatus.confirmed,
          rejection: null,
          blocking: null,
          hasBlocking: false,
        ),
      ),
    };

    for (final entry in scenarios.entries) {
      test(entry.key, () {
        final state = _state(entry.value.$1);
        final expected = entry.value.$2;
        expect(state.cardStatus('a1'), expected.status);
        expect(state.cardRejection('a1')?.reason, expected.rejection);
        expect(state.blockingRejection('a1')?.reason, expected.blocking);
        expect(state.hasBlockingRejection('a1'), expected.hasBlocking);
      });
    }

    test('cardRejection returns the first rejection of the card', () {
      final state = _state(<PendingOp>[
        _rejected(_retitle('a1', opId: 't1'), NackReason.forbidden),
        _rejected(_retitle('a1', opId: 't2'), NackReason.internal),
      ]);
      expect(state.cardRejection('a1')?.reason, NackReason.forbidden);
      expect(state.blockingRejection('a1')?.reason, NackReason.forbidden);
    });
  });

  group('BoardModel.activeCard', () {
    test('returns null when the card does not exist', () {
      expect(makeBoard().activeCard('missing'), isNull);
    });

    test('returns the card when it is active', () {
      final board = makeBoard();
      expect(board.activeCard('a1'), isNotNull);
      expect(board.activeCard('a1'), board.cardById('a1'));
    });

    test('returns null for an archived card that is still stored', () {
      final source = makeBoard();
      final board = BoardModel(
        id: source.id,
        title: source.title,
        seq: source.seq,
        columns: source.columns,
        members: source.members,
        cards: <CardModel>[
          makeCard('x1', colA, 'a', archived: true),
          makeCard('x2', colA, 'b'),
        ],
      );
      expect(board.cardById('x1'), isNotNull);
      expect(board.cardById('x1')!.archived, isTrue);
      expect(board.activeCard('x1'), isNull);
      expect(board.activeCard('x2'), isNotNull);
    });
  });
}
