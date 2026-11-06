import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/realtime/event_codec.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/engine_rig.dart';
import '../../helpers/event_factory.dart';
import '../../helpers/manual_transport.dart';

Map<String, Object?> eventJson(int seq, {String? opId}) =>
    encodeEventEnvelope(renamed(seq, opId: opId, title: 'e$seq'));

void main() {
  group('token refresh inside the socket', () {
    rigTest('auth.refresh goes out 60 s before expiry with a new token', (
      rig,
    ) async {
      await rig.start();
      await rig.run(39000);
      expect(rig.server.receivedRefreshTokens, isEmpty);

      await rig.run(2000);

      expect(rig.server.receivedRefreshTokens, ['tok-1']);
      expect(rig.creds.staleSeen, ['tok-0']);
      expect(rig.server.connectAttempts, 1);
      expect(rig.engine.isReady, isTrue);
    }, ttl: const Duration(seconds: 100));

    rigTest('auth.refreshed reschedules the next refresh', (rig) async {
      await rig.start();
      await rig.run(41000);
      expect(rig.server.receivedRefreshTokens, ['tok-1']);

      await rig.run(30 * 1000);
      expect(rig.server.receivedRefreshTokens, ['tok-1']);
      await rig.run(15 * 1000);

      expect(rig.server.receivedRefreshTokens, ['tok-1', 'tok-2']);
      expect(rig.server.connectAttempts, 1);
    }, ttl: const Duration(seconds: 100));

    rigTest('the refresh ack cancels the 15 s timeout', (rig) async {
      await rig.start();
      await rig.run(41000);

      await rig.run(120000);

      expect(rig.server.connectAttempts, 1);
      expect(rig.readyCount, 1);
    }, ttl: const Duration(seconds: 100));

    rigTest('a token already inside the leeway is refreshed right away', (
      rig,
    ) async {
      await rig.start(50);

      expect(rig.server.receivedRefreshTokens, ['tok-1']);
      expect(rig.server.connectAttempts, 1);
    }, ttl: const Duration(seconds: 30));

    rigTest('no auth.refreshed in 15 s renews and reconnects', (rig) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(40000);
      expect(m.channel.sentTypes, ['hello', 'auth.refresh']);
      expect(m.channel.sentMessages.last['payload'], {'access_token': 'tok-1'});

      await rig.run(14000);
      expect(m.transport.channels, hasLength(1));
      await rig.run(2000);

      expect(m.transport.channels.first.closedByClient, isTrue);
      expect(m.transport.channels.first.clientCloseCode, 1000);
      expect(m.transport.channels, hasLength(2));
      expect(rig.creds.renews, 2);
      expect(m.transport.headers.last['Authorization'], 'Bearer tok-2');
      expect(m.transport.channels.last.sentTypes, ['hello']);
      await m.engine.dispose();
    }, ttl: const Duration(seconds: 100));

    rigTest('error invalid_token after auth.refresh renews and reconnects', (
      rig,
    ) async {
      rig.server.acceptToken = (token) => token != 'tok-1';
      await rig.start();

      await rig.run(41000);

      expect(rig.server.connectTokens, ['tok-0', 'tok-2']);
      expect(rig.creds.renews, 2);
      expect(rig.readyCount, 2);
      expect(rig.issues, isEmpty);
      expect(rig.server.receivedRefreshTokens, isEmpty);
    }, ttl: const Duration(seconds: 100));

    rigTest('error invalid_token without a pending refresh is only reported', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      m.channel.pushJson(
        serverMessage('error', {'code': 'invalid_token', 'message': 'x'}),
      );
      await rig.run(5000);

      expect(m.issues, [const ServerReportedError('invalid_token', 'x')]);
      expect(m.transport.channels, hasLength(1));
      await m.engine.dispose();
    });

    rigTest('an unavailable renewal is retried after 5 s', (rig) async {
      rig.creds.unavailable = 1;
      await rig.start();

      await rig.run(41000);
      expect(rig.server.receivedRefreshTokens, isEmpty);
      expect(rig.creds.renews, 1);
      await rig.run(3000);
      expect(rig.server.receivedRefreshTokens, isEmpty);
      await rig.run(2000);

      expect(rig.creds.renews, 2);
      expect(rig.server.receivedRefreshTokens, ['tok-1']);
      expect(rig.server.connectAttempts, 1);
    }, ttl: const Duration(seconds: 100));

    rigTest('the session ending during a refresh ends the board', (rig) async {
      await rig.start();
      rig.creds.ended = true;

      await rig.run(41000);

      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.sessionEnded);
      await rig.run(60000);
      expect(rig.server.connectAttempts, 1);
    }, ttl: const Duration(seconds: 100));
  });

  group('close 4001', () {
    rigTest('renews the token and reconnects immediately', (rig) async {
      await rig.start();
      rig.clearSignals();

      rig.server.expireTokens();
      await rig.run(10);

      expect(rig.server.connectTokens, ['tok-0', 'tok-1']);
      expect(rig.creds.renews, 1);
      expect(rig.creds.staleSeen, ['tok-0']);
      expect(rig.readyCount, 1);
      expect(
        rig.of<ConnectionSignal>().where((s) => s.reconnectSeconds != null),
        isEmpty,
      );
    });

    rigTest('repeated 4001 with a ready in between never backs off', (
      rig,
    ) async {
      await rig.start();

      for (var i = 0; i < 6; i++) {
        rig.server.expireTokens();
        await rig.run(10);
      }

      expect(rig.server.connectAttempts, 7);
      expect(rig.server.connectTokens.last, 'tok-6');
    });

    rigTest('three 4001 in a row reconnect at once, the next one backs off', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);

      for (var i = 0; i < 3; i++) {
        m.channel.serverClose(4001);
        await rig.run(10);
        expect(m.transport.channels, hasLength(i + 2));
      }
      m.channel.serverClose(4001);
      await rig.run(10);

      expect(m.transport.channels, hasLength(4));
      expect(m.trail.last, ('reconnecting', 1));
      await rig.run(600);
      expect(m.transport.channels, hasLength(5));
      await m.engine.dispose();
    });

    rigTest('the session ending ends the board without reconnecting', (
      rig,
    ) async {
      await rig.start();
      rig.creds.ended = true;

      rig.server.expireTokens();
      await rig.run(60000);

      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.sessionEnded);
      expect(rig.server.connectAttempts, 1);
      expect(rig.of<ConnectionSignal>().last.status.name, 'offline');
    });

    rigTest('an unavailable renewal falls back to the backoff', (rig) async {
      await rig.start();
      rig.creds.unavailable = 1;

      rig.server.expireTokens();
      await rig.run(1);
      expect(rig.of<ConnectionSignal>().last.reconnectSeconds, 1);
      await rig.run(600);

      expect(rig.server.connectAttempts, 2);
      expect(rig.readyCount, 2);
    });
  });

  group('gap detection', () {
    rigTest('missing events are fetched over REST after 1 s, page by page', (
      rig,
    ) async {
      await rig.start();
      rig.server.suppressNextBroadcasts(3);
      for (var i = 0; i < 5; i++) {
        rig.server.commitEvent((seq, ts) => renamed(seq, title: 'r$seq'));
      }
      await rig.run(900);
      expect(rig.engine.lastSeq, 10);
      expect(rig.server.eventFetches, 0);

      await rig.run(200);

      expect(rig.server.eventFetches, 3);
      expect(rig.eventSeqs, [11, 12, 13, 14, 15]);
      expect(rig.engine.lastSeq, 15);
      expect(rig.server.snapshotLoads, 0);
      expect(rig.of<ResyncedSignal>(), isEmpty);
    }, pageSize: 2);

    rigTest('a gap that closes within a second never touches REST', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(500);
      m.channel.pushJson(eventJson(11));
      await rig.run(2000);

      expect(m.catchUp.eventRequests, isEmpty);
      expect(m.engine.lastSeq, 12);
      await m.engine.dispose();
    });

    rigTest('the gap timer fires exactly after one second', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults.add(stubPage([renamed(11), renamed(12)]));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(989);
      expect(m.catchUp.eventRequests, isEmpty);
      await rig.run(20);

      expect(m.catchUp.eventRequests, [10]);
      expect(m.engine.lastSeq, 12);
      await m.engine.dispose();
    });

    rigTest('a REST error is retried after another second', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults
        ..add(
          const Failure<EventsPage, ApiFailure>(
            NetworkFailure(NetworkFailureKind.offline),
          ),
        )
        ..add(stubPage([renamed(11), renamed(12)]));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(1500);
      expect(m.catchUp.eventRequests, [10]);
      expect(m.engine.lastSeq, 10);

      await rig.run(600);

      expect(m.catchUp.eventRequests, [10, 10]);
      expect(m.engine.lastSeq, 12);
      expect(m.catchUp.boardRequests, 0);
      await m.engine.dispose();
    });

    rigTest('REST errors alone never trigger a snapshot', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.eventFallback = const Failure<EventsPage, ApiFailure>(
        NetworkFailure(NetworkFailureKind.timeout),
      );
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(10500);

      expect(m.catchUp.eventRequests.length, greaterThanOrEqualTo(8));
      expect(m.catchUp.boardRequests, 0);
      await m.engine.dispose();
    });

    rigTest('two rounds without progress fall back to a snapshot', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.boardResults.add(stubBoard(seq: 20));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12, opId: 'late'));
      await rig.run(1010);
      expect(m.catchUp.eventRequests, [10]);
      expect(m.catchUp.boardRequests, 0);

      await rig.run(1000);

      expect(m.catchUp.eventRequests, [10, 10]);
      expect(m.catchUp.boardRequests, 1);
      expect(m.of<SnapshotSignal>().single.board.seq, 20);
      expect(m.engine.lastSeq, 20);
      expect(m.of<DuplicatesSignal>().expand((s) => s.opIds), ['late']);
      await m.engine.dispose();
    });

    rigTest('410 Gone reloads the snapshot without a resync signal', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults.add(
        const Failure<EventsPage, ApiFailure>(GoneFailure()),
      );
      m.catchUp.boardResults.add(stubBoard(seq: 30));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(1100);

      expect(m.catchUp.boardRequests, 1);
      expect(m.of<SnapshotSignal>().single.board.seq, 30);
      expect(m.of<ResyncedSignal>(), isEmpty);
      expect(m.engine.lastSeq, 30);
      await m.engine.dispose();
    });

    rigTest('a pruned server log (410) converges through the snapshot', (
      rig,
    ) async {
      await rig.start();
      rig.server.suppressNextBroadcasts(1);
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'lost'));
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'kept'));
      rig.server.pruneLog(11);
      await rig.run(1100);

      expect(rig.server.snapshotLoads, 1);
      expect(rig.of<SnapshotSignal>().single.board.title, 'kept');
      expect(rig.engine.lastSeq, 12);
    });

    rigTest('a failing snapshot reload is retried after one second', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.eventResults.add(
        const Failure<EventsPage, ApiFailure>(GoneFailure()),
      );
      m.catchUp.boardResults.add(
        const Failure<ServerBoard, ApiFailure>(
          NetworkFailure(NetworkFailureKind.offline),
        ),
      );
      m.catchUp.boardResults.add(stubBoard(seq: 30));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(eventJson(12));
      await rig.run(1100);
      expect(m.catchUp.boardRequests, 1);
      expect(m.of<SnapshotSignal>(), isEmpty);

      await rig.run(1000);

      expect(m.catchUp.boardRequests, 2);
      expect(m.of<SnapshotSignal>().single.board.seq, 30);
      await m.engine.dispose();
    });
  });

  group('resync_required', () {
    Map<String, Object?> resyncNack(String opId) => {
      'v': 1,
      'type': 'nack',
      'op_id': opId,
      'payload': {'reason': 'resync_required', 'at_seq': 11, 'message': ''},
    };

    rigTest('forwards the nack, reloads the snapshot and signals a resync', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.boardResults.add(stubBoard(seq: 25));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      m.channel.pushJson(resyncNack('x1'));
      await rig.run(10);

      final order = m.signals
          .where(
            (s) =>
                s is NackSignal || s is SnapshotSignal || s is ResyncedSignal,
          )
          .map((s) => s.runtimeType)
          .toList();
      expect(order, [NackSignal, SnapshotSignal, ResyncedSignal]);
      expect(m.of<NackSignal>().single.opId, 'x1');
      expect(m.engine.lastSeq, 25);
      await m.engine.dispose();
    });

    rigTest('a failed reload keeps the resync flag until it succeeds', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.catchUp.boardResults
        ..add(
          const Failure<ServerBoard, ApiFailure>(
            NetworkFailure(NetworkFailureKind.offline),
          ),
        )
        ..add(stubBoard(seq: 25));
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(resyncNack('x1'));
      await rig.run(500);
      expect(m.of<ResyncedSignal>(), isEmpty);

      await rig.run(600);

      expect(m.catchUp.boardRequests, 2);
      expect(m.of<ResyncedSignal>(), hasLength(1));
      await m.engine.dispose();
    });

    rigTest('each resync_required nack reloads the snapshot once', (rig) async {
      final m = ManualEngine(rig);
      m.catchUp.boardFallback = stubBoard(seq: 25);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      m.channel.pushJson(resyncNack('x1'));
      m.channel.pushJson(resyncNack('x2'));
      await rig.run(10);

      expect(m.of<NackSignal>(), hasLength(2));
      expect(m.catchUp.boardRequests, 2);
      expect(m.of<ResyncedSignal>(), hasLength(2));
      await m.engine.dispose();
    });
  });
}
