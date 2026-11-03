import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

BoardSyncState read(ProviderContainer c) => c.read(boardNotifierProvider);

DateTime clock = DateTime.utc(2026, 1, 1, 12);

({ProviderContainer c, FakeBoardGateway g}) open() {
  final g = FakeBoardGateway(confirmDelay: Duration.zero);
  final ids = IdSequence();
  final c = ProviderContainer(
    overrides: [
      boardGatewayProvider.overrideWithValue(g),
      idGeneratorProvider.overrideWithValue(ids.call),
      nowProvider.overrideWithValue(() => clock),
    ],
  );
  c.listen(boardNotifierProvider, (_, _) {});
  return (c: c, g: g);
}

Future<void> run(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));

void main() {
  setUp(() => clock = DateTime.utc(2026, 1, 1, 12));

  testWidgets('offline queue resent with the same op id', (t) async {
    final o = open();
    await run(t, 10);
    expect(read(o.c).connection, ConnectionStatus.connected);
    o.g.server.dropConnections();
    await run(t, 1);
    expect(read(o.c).connection, ConnectionStatus.reconnecting);
    expect(read(o.c).reconnectSeconds, 1);
    o.c
        .read(boardNotifierProvider.notifier)
        .createCard(columnId: DemoIds.backlog, title: 'Offline');
    expect(read(o.c).pending.single.status, PendingOpStatus.queued);
    expect(o.g.server.receivedOps, isEmpty);
    await run(t, 700);
    expect(read(o.c).connection, ConnectionStatus.connected);
    expect(o.g.server.receivedOps.map((op) => op.opId), ['id-0']);
    expect(read(o.c).pending, isEmpty);
    expect(read(o.c).confirmed.cards.any((c) => c.title == 'Offline'), isTrue);
    o.c.dispose();
  });

  testWidgets('applied while offline resolves itself via delta', (t) async {
    final o = open();
    await run(t, 10);
    o.g.server.suppressNextBroadcasts(1);
    o.c
        .read(boardNotifierProvider.notifier)
        .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
    await run(t, 10);
    expect(read(o.c).pending, hasLength(1));
    expect(o.g.server.seq, 1285);
    o.g.server.dropConnections();
    await run(t, 700);
    expect(read(o.c).pending, isEmpty);
    expect(o.g.server.receivedOps, hasLength(1));
    expect(read(o.c).lastSeq, 1285);
    o.c.dispose();
  });

  testWidgets('role change, removal and deletion', (t) async {
    final o = open();
    await run(t, 10);
    o.g.server.changeRole(DemoIds.elena, BoardRole.viewer);
    await run(t, 10);
    expect(o.c.read(currentRoleProvider), BoardRole.viewer);
    o.c
        .read(boardNotifierProvider.notifier)
        .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
    expect(read(o.c).pending, isEmpty);
    o.g.server.removeMember(DemoIds.elena);
    await run(t, 10);
    expect(read(o.c).ended, BoardEndReason.removed);
    expect(read(o.c).connection, ConnectionStatus.offline);
    await run(t, 60000);
    expect(o.g.server.connectAttempts, 1);
    o.c.dispose();

    final p = open();
    await run(t, 10);
    p.g.server.renameBoard('New name');
    await run(t, 10);
    expect(p.c.read(boardViewProvider).title, 'New name');
    p.g.server.deleteBoard();
    await run(t, 10);
    expect(read(p.c).ended, BoardEndReason.boardDeleted);
    p.c.dispose();
  });

  testWidgets('stale pending is dropped at ready', (t) async {
    final o = open();
    await run(t, 10);
    o.g.server.dropConnections();
    await run(t, 1);
    o.c
        .read(boardNotifierProvider.notifier)
        .createCard(columnId: DemoIds.backlog, title: 'Old');
    clock = clock.add(const Duration(hours: 25));
    await run(t, 700);
    expect(read(o.c).pending, isEmpty);
    expect(o.g.server.receivedOps, isEmpty);
    o.c.dispose();
  });

  testWidgets('resync_required drops the op and resends the rest', (t) async {
    final o = open();
    await run(t, 10);
    o.g.server.resyncRequiredFor('id-0');
    final n = o.c.read(boardNotifierProvider.notifier);
    n.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
    n.moveCard(cardId: 'c-ci', toColumnId: DemoIds.backlog);
    await run(t, 10);
    expect(read(o.c).pending, isEmpty);
    expect(o.g.server.receivedOps.map((op) => op.opId).toList(), [
      'id-0',
      'id-1',
      'id-1',
    ]);
    expect(o.g.server.snapshotLoads, 1);
    expect(read(o.c).confirmed.cardById('c-ci')!.columnId, DemoIds.backlog);
    o.c.dispose();
  });

  testWidgets('presence from the server', (t) async {
    final o = open();
    await run(t, 10);
    expect(o.c.read(onlineMembersProvider).map((m) => m.userId), [
      DemoIds.elena,
      DemoIds.maxim,
      DemoIds.anya,
    ]);
    o.g.server.userLeft(DemoIds.maxim);
    await run(t, 10);
    expect(o.c.read(onlineMembersProvider).map((m) => m.userId), [
      DemoIds.elena,
      DemoIds.anya,
    ]);
    o.c.dispose();
  });

  testWidgets('remote events change confirmed', (t) async {
    final o = open();
    await run(t, 10);
    o.g.server.commitEvent(
      (seq, ts) => ColumnRenamedEvent(
        seq: seq,
        serverTs: ts,
        actorId: DemoIds.maxim,
        columnId: DemoIds.review,
        title: 'Renamed',
        version: 2,
      ),
    );
    await run(t, 10);
    expect(read(o.c).confirmed.columnById(DemoIds.review)!.title, 'Renamed');
    expect(read(o.c).lastSeq, 1285);
    o.c.dispose();
  });
}
