import 'dart:math' as math;

import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake/fake_board_server.dart';
import 'package:cardo/features/board/data/realtime/board_sync_engine.dart';
import 'package:cardo/features/board/data/realtime/realtime_credentials.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

class Creds implements RealtimeCredentials {
  Creds(this.now, {this.ttl = const Duration(hours: 1)});
  final DateTime Function() now;
  final Duration ttl;
  int issued = 0;
  int renews = 0;
  bool ended = false;

  AccessGrant grant() =>
      AccessGrant(token: 'tok-$issued', expiresAt: now().add(ttl));

  @override
  Future<AccessGrant?> current() async => ended ? null : grant();

  @override
  Future<CredentialRenewal> renew({String? staleAccess}) async {
    renews++;
    if (ended) return const CredentialsSessionEnded();
    issued++;
    return CredentialsRenewed(grant());
  }
}

typedef H = ({
  BoardSyncEngine engine,
  FakeBoardServer server,
  List<SyncSignal> signals,
  Creds creds,
});

H make({Duration ttl = const Duration(hours: 1)}) {
  final snap = demoBoardSnapshot();
  final server = FakeBoardServer(
    initial: snap.board,
    currentUserId: snap.currentUser.userId,
  );
  final creds = Creds(DateTime.now, ttl: ttl);
  final engine = BoardSyncEngine(
    boardId: snap.board.id,
    currentUser: snap.currentUser,
    wsBaseUri: Uri(scheme: 'ws', host: 'x.test', path: '/pre'),
    transport: server,
    credentials: creds,
    catchUp: server,
    initialSeq: snap.board.seq,
    random: math.Random(1),
  );
  final signals = <SyncSignal>[];
  engine.signals.listen(signals.add);
  return (engine: engine, server: server, signals: signals, creds: creds);
}

Future<void> run(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));

MoveCard mv(String id) => MoveCard(
  opId: id,
  cardId: 'c-audit',
  toColumnId: DemoIds.done,
  baseVersion: 1,
);

void main() {
  testWidgets('A handshake', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    expect(h.signals.whereType<ReadySignal>().length, 1);
    expect(h.server.connectTokens, ['tok-0']);
    expect(h.server.receivedHelloSeqs, [1284]);
    expect(
      h.engine.socketUri.toString(),
      startsWith('ws://x.test/pre/ws/boards/'),
    );
    expect(h.server.receivedTypes, ['hello']);
    await h.engine.dispose();
  });

  testWidgets('B gap -> REST after 1s', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.suppressNextBroadcasts(1);
    h.server.commitRemote(mv('r1'), actorId: DemoIds.anya);
    h.server.commitRemote(
      const EditCardTitle(
        opId: 'r2',
        cardId: 'c-ci',
        title: 'T',
        actorId: DemoIds.anya,
      ),
      actorId: DemoIds.anya,
    );
    await run(t, 10);
    expect(h.engine.lastSeq, 1284);
    expect(h.server.eventFetches, 0);
    await run(t, 900);
    expect(h.server.eventFetches, 0);
    await run(t, 200);
    expect(h.server.eventFetches, 1);
    expect(h.engine.lastSeq, 1286);
    final seqs = h.signals
        .whereType<EventsSignal>()
        .expand((e) => e.events)
        .map((e) => e.seq)
        .toList();
    expect(seqs, [1285, 1286]);
    await h.engine.dispose();
  });

  testWidgets('C gone -> snapshot', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.suppressNextBroadcasts(1);
    h.server.commitRemote(mv('r1'), actorId: DemoIds.anya);
    h.server.commitRemote(
      const EditCardTitle(
        opId: 'r2',
        cardId: 'c-ci',
        title: 'T',
        actorId: DemoIds.anya,
      ),
      actorId: DemoIds.anya,
    );
    h.server.pruneLog(1285);
    await run(t, 1100);
    expect(h.server.snapshotLoads, 1);
    final snap = h.signals.whereType<SnapshotSignal>().single;
    expect(snap.board.seq, 1286);
    expect(h.engine.lastSeq, 1286);
    await h.engine.dispose();
  });

  testWidgets('D reconnect with backoff and delta', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.dropConnections();
    await run(t, 1);
    final rec = h.signals.whereType<ConnectionSignal>().last;
    expect(rec.status, ConnectionStatus.reconnecting);
    expect(rec.reconnectSeconds, 1);
    h.server.commitRemote(mv('r1'), actorId: DemoIds.anya);
    await run(t, 700);
    expect(h.server.connectAttempts, 2);
    expect(h.server.receivedHelloSeqs, [1284, 1284]);
    expect(h.signals.whereType<ReadySignal>().length, 2);
    expect(h.server.deltasSent, 2);
    expect(h.engine.lastSeq, 1285);
    h.server.failNextConnections(3);
    h.server.dropConnections();
    for (var i = 0; i < 4; i++) {
      await run(t, 40000);
    }
    expect(h.server.connectAttempts, 6);
    expect(h.signals.whereType<ReadySignal>().length, 3);
    await h.engine.dispose();
  });

  testWidgets('E 4001 renews and reconnects', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.expireTokens();
    await run(t, 10);
    expect(h.creds.renews, 1);
    expect(h.server.connectTokens, ['tok-0', 'tok-1']);
    expect(h.signals.whereType<ReadySignal>().length, 2);
    h.creds.ended = true;
    h.server.expireTokens();
    await run(t, 10);
    expect(
      h.signals.whereType<EndedSignal>().single.reason,
      BoardEndReason.sessionEnded,
    );
    final attempts = h.server.connectAttempts;
    await run(t, 60000);
    expect(h.server.connectAttempts, attempts);
    await h.engine.dispose();
  });

  testWidgets('F 4003 and 4004 are terminal', (t) async {
    for (final code in [4003, 4004]) {
      final h = make();
      h.engine.start();
      await run(t, 10);
      h.server.closeConnections(code);
      await run(t, 60000);
      expect(h.server.connectAttempts, 1);
      expect(
        h.signals.whereType<EndedSignal>().single.reason,
        code == 4003 ? BoardEndReason.removed : BoardEndReason.boardDeleted,
      );
      expect(
        h.signals.whereType<ConnectionSignal>().last.status,
        ConnectionStatus.offline,
      );
      await h.engine.dispose();
    }
  });

  testWidgets('G in-socket token refresh', (t) async {
    final h = make(ttl: const Duration(seconds: 100));
    h.engine.start();
    await run(t, 10);
    await run(t, 38000);
    expect(h.server.receivedRefreshTokens, isEmpty);
    await run(t, 3000);
    expect(h.server.receivedRefreshTokens, ['tok-1']);
    expect(h.server.connectAttempts, 1);
    await h.engine.dispose();
  });

  testWidgets('H resync_required', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.resyncRequiredFor('x1');
    h.engine.send(mv('x1'));
    await run(t, 10);
    expect(
      h.signals.whereType<NackSignal>().single.rejection.reason,
      NackReason.resyncRequired,
    );
    expect(h.server.snapshotLoads, 1);
    expect(h.signals.last, isA<ResyncedSignal>());
    await h.engine.dispose();
  });

  testWidgets('I presence', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.userJoined(
      const PresenceUser(userId: 'u9', name: 'N', avatarColor: '#111111'),
    );
    h.server.userLeft('u9');
    await run(t, 10);
    expect(h.signals.whereType<PresenceListSignal>().length, 1);
    expect(h.signals.whereType<PresenceJoinSignal>().single.user.userId, 'u9');
    expect(h.signals.whereType<PresenceLeaveSignal>().single.userId, 'u9');
    await h.engine.dispose();
  });

  testWidgets('K 4008 waits long', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    h.server.closeConnections(4008);
    await run(t, 1);
    final secs = h.signals.whereType<ConnectionSignal>().last.reconnectSeconds!;
    expect(secs, greaterThanOrEqualTo(30));
    await h.engine.dispose();
  });

  testWidgets('L big messages', (t) async {
    final h = make();
    h.engine.start();
    await run(t, 10);
    final big = EditCardDescription(
      opId: 'b',
      cardId: 'c-ci',
      description: 'x' * 70000,
      baseDescriptionVersion: 1,
      actorId: 'u',
    );
    expect(h.engine.send(big).name, 'tooLarge');
    await h.engine.dispose();
  });
}
