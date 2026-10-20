import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: demoBoard(),
    lastSeq: 1284,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

BoardPresence _presence() {
  return BoardPresence(
    onlineUserIds: const <String>[DemoIds.elena, DemoIds.maxim],
    editingByCard: const <String, String>{
      DemoIds.readOnlyCard: DemoIds.anya,
      DemoIds.rankCard: DemoIds.elena,
    },
  );
}

List<ColumnViewData> _build(List<PendingOp> pending) {
  return buildColumnViewData(
    state: _state(pending),
    presence: _presence(),
    currentUserId: DemoIds.elena,
  );
}

void main() {
  group('buildColumnViewData', () {
    test('orders columns and cards and counts them', () {
      final columns = _build(const <PendingOp>[]);
      expect(columns.map((c) => c.column.id), <String>[
        DemoIds.backlog,
        DemoIds.inProgress,
        DemoIds.review,
        DemoIds.done,
      ]);
      expect(columns.map((c) => c.count), <int>[6, 4, 3, 12]);
      expect(columns[1].cards.map((c) => c.card.id), <String>[
        DemoIds.handshakeCard,
        DemoIds.rankCard,
        DemoIds.readOnlyCard,
        DemoIds.syncStateCard,
      ]);
      expect(columns[1].models.length, 4);
    });

    test('editing presence of others is shown, of the current user hidden', () {
      final cards = _build(const <PendingOp>[])[1].cards;
      expect(
        cards
            .firstWhere((c) => c.card.id == DemoIds.readOnlyCard)
            .editingBy!
            .name,
        'Аня',
      );
      expect(
        cards.firstWhere((c) => c.card.id == DemoIds.rankCard).editingBy,
        isNull,
      );
    });

    test('authors resolve to identities', () {
      final handshake = _build(const <PendingOp>[])[1].cards.first;
      expect(handshake.createdBy!.name, 'Максим');
      expect(handshake.updatedBy!.name, 'Максим');
      expect(handshake.status, CardSyncStatus.confirmed);
      expect(handshake.rejection, isNull);
    });

    test('pending and rejected statuses reach the card data', () {
      const nack = OpRejection(
        reason: NackReason.versionConflict,
        actorId: DemoIds.maxim,
      );
      final columns = _build(<PendingOp>[
        PendingOp(
          op: const MoveCard(
            opId: '1',
            cardId: 'c-audit',
            toColumnId: DemoIds.done,
            baseVersion: 1,
          ),
          status: PendingOpStatus.sent,
          createdAt: DateTime.utc(2026),
        ),
        PendingOp(
          op: const MoveCard(
            opId: '2',
            cardId: 'c-ci',
            toColumnId: DemoIds.backlog,
            baseVersion: 1,
          ),
          status: PendingOpStatus.rejected,
          createdAt: DateTime.utc(2026),
          rejection: nack,
        ),
      ]);
      final all = columns.expand((c) => c.cards).toList();
      final audit = all.firstWhere((c) => c.card.id == 'c-audit');
      final ci = all.firstWhere((c) => c.card.id == 'c-ci');
      expect(audit.status, CardSyncStatus.pending);
      expect(audit.card.columnId, DemoIds.done);
      expect(ci.status, CardSyncStatus.rejected);
      expect(ci.rejection, nack);
      expect(ci.rejectionActorName, 'Максим');
    });

    test('value equality', () {
      final a = _build(const <PendingOp>[]);
      final b = _build(const <PendingOp>[]);
      expect(a, b);
      expect(a.first.hashCode, b.first.hashCode);
      expect(a.first.cards.first.hashCode, b.first.cards.first.hashCode);
    });
  });

  group('BoardSyncConfig', () {
    test('defaults come from the duration tokens', () {
      const config = BoardSyncConfig();
      expect(config.nackHold, const Duration(milliseconds: 2400));
      expect(config.retryDelay, const Duration(milliseconds: 1500));
      expect(config.maxInternalRetries, 2);
      expect(config, const BoardSyncConfig());
      expect(config.hashCode, const BoardSyncConfig().hashCode);
      expect(config, isNot(const BoardSyncConfig(maxInternalRetries: 3)));
    });
  });

  group('session value types', () {
    test('equality', () {
      const user = CurrentUser(
        userId: 'u',
        name: 'n',
        email: 'e',
        avatarColor: '#2D68F5',
      );
      expect(
        user,
        const CurrentUser(
          userId: 'u',
          name: 'n',
          email: 'e',
          avatarColor: '#2D68F5',
        ),
      );
      expect(user.hashCode, isA<int>());
      expect(
        const BoardSummary(id: 'b', title: 't', colorHex: '#2D68F5'),
        const BoardSummary(id: 'b', title: 't', colorHex: '#2D68F5'),
      );
      expect(_presence(), _presence());
      expect(_presence().hashCode, _presence().hashCode);
      expect(const OpConfirmed(seq: 3), const OpConfirmed(seq: 3));
      expect(
        const OpRejected(OpRejection(reason: NackReason.internal)),
        const OpRejected(OpRejection(reason: NackReason.internal)),
      );
    });
  });
}
