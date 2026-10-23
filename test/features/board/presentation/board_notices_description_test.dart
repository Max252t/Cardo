import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_notices.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

PendingOp _rejected(BoardOp op, OpRejection rejection) {
  return PendingOp(
    op: op,
    status: PendingOpStatus.rejected,
    createdAt: _t,
    rejection: rejection,
  );
}

PendingOp _sent(BoardOp op) {
  return PendingOp(op: op, status: PendingOpStatus.sent, createdAt: _t);
}

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

const EditCardDescription _description = EditCardDescription(
  opId: 'd',
  cardId: 'a1',
  description: 'text',
  baseDescriptionVersion: 1,
  actorId: 'u1',
);

void main() {
  const conflict = OpRejection(
    reason: NackReason.versionConflict,
    actorId: 'u1',
  );

  group('description conflicts', () {
    test('a version_conflict on a description produces no notice', () {
      final before = _state([_sent(_description)]);
      final after = _state([_rejected(_description, conflict)]);
      expect(noticesBetween(before, after), isEmpty);
      expect(noticesBetween(null, after), isEmpty);
    });

    test('a version_conflict on a move still produces a notice', () {
      final move = moveOp('a1', colB, opId: 'm');
      final notices = noticesBetween(
        _state([_sent(move)]),
        _state([_rejected(move, conflict)]),
      );
      expect(notices.length, 1);
      expect(notices.single.actorName, 'One');
    });

    test('a version_conflict on a title still produces a notice', () {
      const title = EditCardTitle(
        opId: 't',
        cardId: 'a1',
        title: 'x',
        actorId: 'u1',
      );
      expect(
        noticesBetween(
          _state([_sent(title)]),
          _state([_rejected(title, conflict)]),
        ),
        hasLength(1),
      );
    });

    test('other nacks on a description still produce a notice', () {
      for (final reason in <NackReason>[
        NackReason.forbidden,
        NackReason.notFound,
        NackReason.validationError,
        NackReason.rateLimited,
        NackReason.internal,
      ]) {
        final notices = noticesBetween(
          _state([_sent(_description)]),
          _state([_rejected(_description, OpRejection(reason: reason))]),
        );
        expect(notices, hasLength(1), reason: reason.name);
        expect(notices.single.rejection.reason, reason);
      }
    });

    test('a skipped description notice does not hide a following one', () {
      final move = moveOp('a1', colB, opId: 'm');
      final notices = noticesBetween(
        _state([_sent(_description), _sent(move)]),
        _state([
          _rejected(_description, conflict),
          _rejected(move, const OpRejection(reason: NackReason.notFound)),
        ]),
      );
      expect(notices.map((n) => n.opId), <String>['m']);
    });
  });
}
