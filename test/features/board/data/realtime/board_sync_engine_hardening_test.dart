import 'dart:async';

import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/core/realtime/realtime_policy.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/realtime/event_codec.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/engine_rig.dart';
import '../../helpers/event_factory.dart';
import '../../helpers/manual_transport.dart';

Map<String, Object?> eventJson(int seq, {String? opId}) =>
    encodeEventEnvelope(renamed(seq, opId: opId, title: 'e$seq'));

class GatedCatchUp extends StubCatchUp {
  final Completer<Result<ServerBoard, ApiFailure>> gate = Completer();
  int gated = 0;

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId) {
    if (gated == 0) {
      gated++;
      boardRequests++;
      return gate.future;
    }
    return super.getBoard(boardId);
  }
}

Map<String, Object?> nackJson(String reason, int atSeq, {String opId = 'x'}) {
  return <String, Object?>{
    'v': 1,
    'type': 'nack',
    'op_id': opId,
    'payload': <String, Object?>{
      'reason': reason,
      'at_seq': atSeq,
      'message': '',
    },
  };
}

void main() {
  group('upgrade rejection', () {
    for (final status in <int>[403, 404]) {
      rigTest('HTTP $status ends the board without reconnecting', (rig) async {
        final m = ManualEngine(rig);
        m.transport
          ..failures = 1
          ..failWith = RealtimeUpgradeRejected(status);
        m.engine.start();
        await rig.run(120000);

        expect(m.transport.uris, hasLength(1));
        expect(m.of<EndedSignal>().single.reason, BoardEndReason.accessLost);
        expect(m.of<ConnectionSignal>().last.status, ConnectionStatus.offline);
        await m.engine.dispose();
      });
    }

    rigTest('HTTP 401 renews the token and reconnects at once', (rig) async {
      final m = ManualEngine(rig);
      m.transport
        ..failures = 1
        ..failWith = const RealtimeUpgradeRejected(401);
      m.engine.start();
      await rig.run(50);

      expect(rig.creds.renews, 1);
      expect(m.transport.uris, hasLength(2));
      expect(m.transport.headers[0]['Authorization'], 'Bearer tok-0');
      expect(m.transport.headers[1]['Authorization'], 'Bearer tok-1');
      expect(m.of<EndedSignal>(), isEmpty);
      await m.engine.dispose();
    });

    rigTest('repeated HTTP 401 falls back to the backoff', (rig) async {
      final m = ManualEngine(rig);
      m.transport
        ..failures = 50
        ..failWith = const RealtimeUpgradeRejected(401);
      m.engine.start();
      await rig.run(100);

      expect(m.transport.uris.length, lessThanOrEqualTo(5));
      expect(m.of<EndedSignal>(), isEmpty);
      expect(m.trail.last.$1, 'reconnecting');
      await m.engine.dispose();
    });

    rigTest('HTTP 503 is an ordinary backoff', (rig) async {
      final m = ManualEngine(rig);
      m.transport
        ..failures = 1
        ..failWith = const RealtimeUpgradeRejected(503);
      m.engine.start();
      await rig.run(10);

      expect(m.of<EndedSignal>(), isEmpty);
      expect(m.trail.last, ('reconnecting', 1));
      await rig.run(2000);
      expect(m.transport.uris, hasLength(2));
      await m.engine.dispose();
    });

    rigTest('the fake server can refuse the upgrade too', (rig) async {
      rig.server.rejectUpgrades(404);
      await rig.start();

      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.accessLost);
      expect(rig.server.connectAttempts, 1);
    });
  });

  group('a stale REST snapshot', () {
    testWidgets('never rewinds lastSeq and the resync still completes', (
      tester,
    ) async {
      final rig = EngineRig(tester);
      final m = ManualEngine(rig);
      final catchUp = GatedCatchUp();
      final engine = buildEngine(
        transport: m.transport,
        credentials: rig.creds,
        catchUp: catchUp,
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(1);
      m.channel.pushJson(nackJson('resync_required', 10));
      await rig.run(1);
      m.channel.pushJson(eventJson(11));
      m.channel.pushJson(eventJson(12));
      await rig.run(1);
      expect(engine.lastSeq, 12);

      catchUp.gate.complete(stubBoard(seq: 10));
      await rig.run(1);

      expect(engine.lastSeq, 12);
      expect(signals.whereType<SnapshotSignal>(), isEmpty);
      expect(signals.whereType<ResyncedSignal>(), isEmpty);

      catchUp.boardFallback = stubBoard(seq: 12);
      await rig.run(1100);

      final snapshots = signals.whereType<SnapshotSignal>().toList();
      expect(snapshots.single.board.seq, 12);
      expect(engine.lastSeq, 12);
      expect(signals.whereType<ResyncedSignal>(), hasLength(1));
      await engine.dispose();
      await rig.dispose();
    });

    rigTest('a websocket snapshot below lastSeq is still accepted', (
      rig,
    ) async {
      final m = ManualEngine(rig, initialSeq: 50);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.snapshot', snapshotJson(seq: 5)));
      await rig.run(1);

      expect(m.of<SnapshotSignal>().single.board.seq, 5);
      expect(m.engine.lastSeq, 5);
      await m.engine.dispose();
    });
  });

  group('a lost tail of events', () {
    rigTest('a nack above lastSeq starts the one second gap timer', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults.add(stubPage([renamed(11), renamed(12)]));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(1);
      m.channel.pushJson(nackJson('version_conflict', 12));
      await rig.run(900);
      expect(m.catchUp.eventRequests, isEmpty);

      await rig.run(200);

      expect(m.catchUp.eventRequests, [10]);
      expect(m.engine.lastSeq, 12);
      await m.engine.dispose();
    });

    rigTest('an idle poll finds events nobody pushed', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults.add(stubPage([renamed(11)]));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(RealtimePolicy.idlePoll.inMilliseconds - 100);
      expect(m.catchUp.eventRequests, isEmpty);

      await rig.run(200);

      expect(m.catchUp.eventRequests, [10]);
      expect(m.engine.lastSeq, 11);
      expect(m.of<EventsSignal>().single.events.single.seq, 11);
      await m.engine.dispose();
    });

    rigTest('the idle poll does not run before ready or after a drop', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(20000);
      expect(m.catchUp.eventRequests, isEmpty);

      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.serverClose(1006);
      await rig.run(1);
      final before = m.catchUp.eventRequests.length;
      await rig.run(400);
      expect(m.catchUp.eventRequests.length, before);
      await m.engine.dispose();
    });

    rigTest('a failed idle poll is silent and retried at the next tick', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(11000);

      expect(m.catchUp.eventRequests, [10, 10]);
      expect(m.catchUp.boardRequests, 0);
      await m.engine.dispose();
    });
  });

  group('clock skew', () {
    rigTest('auth.refreshed with a past expires_at causes no refresh loop', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(1);
      final start = rig.creds.renews;

      for (var i = 0; i < 20; i++) {
        m.channel.pushJson(
          serverMessage('auth.refreshed', {
            'expires_at': rig
                .now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          }),
        );
        await rig.run(2);
      }

      expect(rig.creds.renews - start, 0);
      await rig.run(5000);
      expect(rig.creds.renews - start, 0);
      await m.engine.dispose();
    });

    rigTest('the next refresh follows the grant, not the wire timestamp', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(41000);
      expect(m.channel.sentTypes, ['hello', 'auth.refresh']);

      m.channel.pushJson(
        serverMessage('auth.refreshed', {
          'expires_at': rig
              .now()
              .add(const Duration(days: 3650))
              .millisecondsSinceEpoch,
        }),
      );
      await rig.run(45000);

      expect(m.channel.sentTypes, ['hello', 'auth.refresh', 'auth.refresh']);
      await m.engine.dispose();
    }, ttl: const Duration(seconds: 100));

    rigTest('a token that is already late is refreshed immediately once', (
      rig,
    ) async {
      await rig.start(50);

      expect(rig.server.receivedRefreshTokens, ['tok-1']);
      await rig.run(1000);
      expect(rig.server.receivedRefreshTokens.length, 1);
    }, ttl: const Duration(seconds: 30));
  });

  group('an unreadable event', () {
    rigTest('one broken event does not take the chunk down', (rig) async {
      final m = ManualEngine(rig);
      final broken = eventJson(12)..remove('server_ts');
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(
        serverMessage('sync.delta', {
          'events': <Object?>[eventJson(11), broken, eventJson(13)],
        }),
      );
      await rig.run(1);

      expect(m.engine.lastSeq, 11);
      expect(m.issues.whereType<InvalidPayload>(), hasLength(1));
      expect(m.of<EventsSignal>().single.events.single.seq, 11);
      await m.engine.dispose();
    });

    rigTest('a permanently unreadable event is skipped via a snapshot', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      final broken = eventJson(12)..remove('server_ts');
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        UnknownFailure(),
      );
      m.catchUp.boardResults.add(stubBoard(seq: 20));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(
        serverMessage('sync.delta', {
          'events': <Object?>[eventJson(11), broken, eventJson(13)],
        }),
      );
      await rig.run(1);
      expect(m.engine.lastSeq, 11);

      await rig.run(3100);

      expect(m.catchUp.boardRequests, 1);
      expect(m.of<SnapshotSignal>().single.board.seq, 20);
      expect(m.engine.lastSeq, 20);
      await m.engine.dispose();
    });

    rigTest('a server error status counts as transient', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        UnknownFailure(statusCode: 503),
      );
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(8000);

      expect(m.catchUp.boardRequests, 0);
      expect(m.catchUp.eventRequests.length, greaterThan(3));
      await m.engine.dispose();
    });
  });

  group('retry timers are independent', () {
    rigTest('a failing catch-up retry does not cancel the snapshot retry', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );
      m.catchUp.boardResults
        ..add(
          const Failure<ServerBoard, ApiFailure>(
            NetworkFailure(NetworkFailureKind.offline),
          ),
        )
        ..add(stubBoard(seq: 10));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(1);
      m.channel.pushJson(eventJson(12));
      await rig.run(500);
      m.channel.pushJson(nackJson('resync_required', 10));
      await rig.run(4000);

      expect(m.of<ResyncedSignal>(), hasLength(1));
      expect(m.catchUp.boardRequests, 2);
      await m.engine.dispose();
    });
  });

  group('the server rate limiter of the fake', () {
    rigTest('ops above 20 in one burst are nacked as rate_limited', (
      rig,
    ) async {
      await rig.start();
      for (var i = 0; i < 25; i++) {
        rig.engine.send(moveOp('a1', colB, opId: 'b$i'));
      }
      await rig.run(10);

      expect(rig.server.receivedOps, hasLength(20));
      expect(rig.server.rateLimitedOps, 5);
      final limited = rig
          .of<NackSignal>()
          .where((nack) => nack.rejection.reason == NackReason.rateLimited)
          .toList();
      expect(limited, hasLength(5));
      expect(limited.map((nack) => nack.opId), [
        'b20',
        'b21',
        'b22',
        'b23',
        'b24',
      ]);
    });

    rigTest('a refused op is not remembered and passes on a later try', (
      rig,
    ) async {
      await rig.start();
      for (var i = 0; i < 21; i++) {
        rig.engine.send(moveOp('a1', colB, opId: 'b$i'));
      }
      await rig.run(10);
      expect(rig.server.rateLimitedOps, 1);

      await rig.run(200);
      rig.engine.send(moveOp('a1', colB, opId: 'b20'));
      await rig.run(10);

      expect(rig.server.rateLimitedOps, 1);
      expect(rig.server.receivedOps.map((op) => op.opId), contains('b20'));
    });

    rigTest('100 strikes inside 10 s close the socket with 4008', (rig) async {
      await rig.start();
      for (var i = 0; i < 125; i++) {
        rig.engine.send(moveOp('a1', colB, opId: 'b$i'));
      }
      await rig.run(10);

      expect(rig.server.openConnections, 0);
      expect(rig.of<EndedSignal>(), isEmpty);
      final last = rig.of<ConnectionSignal>().last;
      expect(last.status, ConnectionStatus.reconnecting);
      expect(last.reconnectSeconds, greaterThanOrEqualTo(30));
    });
  });

  group('a broken last event', () {
    rigTest('is recovered through a snapshot', (rig) async {
      final m = ManualEngine(rig);
      final broken = eventJson(11)..remove('server_ts');
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        UnknownFailure(),
      );
      m.catchUp.boardResults.add(stubBoard(seq: 11));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(
        serverMessage('sync.delta', {
          'events': <Object?>[broken],
        }),
      );
      await rig.run(1);
      expect(m.engine.lastSeq, 10);

      await rig.run(3100);

      expect(m.of<SnapshotSignal>().single.board.seq, 11);
      expect(m.engine.lastSeq, 11);
      await m.engine.dispose();
    });
  });
}
