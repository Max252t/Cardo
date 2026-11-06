import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_notices.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

PendingOp _item(String opId, {bool rejected = false, int failedAttempts = 0}) {
  return PendingOp(
    op: moveOp('a1', colB, opId: opId),
    status: rejected ? PendingOpStatus.rejected : PendingOpStatus.sent,
    createdAt: _t,
    rejection: rejected
        ? const OpRejection(reason: NackReason.forbidden)
        : null,
    failedAttempts: failedAttempts,
  );
}

BoardSyncState _state(
  List<PendingOp> pending, {
  ReconnectBatch? batch,
  SyncSummary? summary,
}) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
    batch: batch,
    summary: summary,
  );
}

void main() {
  group('noticesBetween with a reconnect batch', () {
    test('a rejection inside the batch makes no notice', () {
      final batch = ReconnectBatch(ids: const ['a', 'b']);
      final before = _state([_item('a'), _item('b')], batch: batch);
      final after = _state([
        _item('a', rejected: true),
        _item('b'),
      ], batch: batch);

      expect(noticesBetween(before, after), isEmpty);
    });

    test('the rejection that completes the batch makes no notice', () {
      final batch = ReconnectBatch(ids: const ['a']);
      final before = _state([_item('a')], batch: batch);
      final after = _state([
        _item('a', rejected: true),
      ], summary: SyncSummary(failedIds: const ['a'], savedCount: 0));

      expect(noticesBetween(before, after), isEmpty);
    });

    test('an internal retry inside the batch makes no notice', () {
      final batch = ReconnectBatch(ids: const ['a']);
      final before = _state([_item('a')], batch: batch);
      final after = _state([_item('a', failedAttempts: 1)], batch: batch);

      expect(noticesBetween(before, after), isEmpty);
    });

    test('an op outside the batch still makes its own notice', () {
      final batch = ReconnectBatch(ids: const ['a']);
      final before = _state([_item('a'), _item('late')], batch: batch);
      final after = _state([
        _item('a'),
        _item('late', rejected: true),
      ], batch: batch);

      final notices = noticesBetween(before, after);

      expect(notices.map((n) => n.opId), ['late']);
    });

    test('without a batch nothing changes', () {
      final before = _state([_item('a')]);
      final after = _state([_item('a', rejected: true)]);

      expect(noticesBetween(before, after), hasLength(1));
    });
  });
}
