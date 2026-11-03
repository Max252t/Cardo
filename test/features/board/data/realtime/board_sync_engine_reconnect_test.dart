import 'dart:async';

import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/engine_rig.dart';
import '../../helpers/event_factory.dart';
import '../../helpers/manual_transport.dart';

List<int> rawCountdown(List<(String, int?)> trail) => [
  for (final (status, seconds) in trail)
    if (status == 'reconnecting' && seconds != null) seconds,
];

List<int> reconnectSeconds(List<(String, int?)> trail) {
  final starts = <int>[];
  int? previous;
  for (final seconds in rawCountdown(trail)) {
    if (previous == null || seconds != previous - 1) {
      starts.add(seconds);
    }
    previous = seconds;
  }
  return starts;
}

void main() {
  group('reconnect after a close', () {
    for (final code in <int?>[1000, 1001, 1009, 1011, 1013, 4009, 1006, null]) {
      rigTest('close $code reconnects after 0.5 s with a 1 s countdown', (
        rig,
      ) async {
        await rig.start();

        if (code == null) {
          rig.server.dropConnections();
        } else {
          rig.server.closeConnections(code);
        }
        await rig.run(1);

        expect(rig.connectionTrail.last, ('reconnecting', 1));
        await rig.run(400);
        expect(rig.server.connectAttempts, 1);
        await rig.run(150);
        expect(rig.server.connectAttempts, 2);
        expect(rig.readyCount, 2);
        expect(rig.engine.isReady, isTrue);
      });
    }

    rigTest('the attempt counter resets after every ready', (rig) async {
      await rig.start();

      for (var i = 0; i < 3; i++) {
        rig.server.dropConnections();
        await rig.run(1);
        await rig.run(600);
      }

      expect(reconnectSeconds(rig.connectionTrail), [1, 1, 1]);
      expect(rig.readyCount, 4);
    });

    rigTest('refused connections back off 0.5, 1, 2, 4 s', (rig) async {
      rig.server.failNextConnections(4);

      rig.engine.start();
      await rig.run(1);
      expect(rig.server.connectAttempts, 1);
      await rig.run(497);
      expect(rig.server.connectAttempts, 1);
      await rig.run(3);
      expect(rig.server.connectAttempts, 2);
      await rig.run(997);
      expect(rig.server.connectAttempts, 2);
      await rig.run(3);
      expect(rig.server.connectAttempts, 3);
      await rig.run(1997);
      expect(rig.server.connectAttempts, 3);
      await rig.run(3);
      expect(rig.server.connectAttempts, 4);
      await rig.run(3997);
      expect(rig.server.connectAttempts, 4);
      await rig.run(3);
      expect(rig.server.connectAttempts, 5);
      expect(rig.readyCount, 1);
      expect(reconnectSeconds(rig.connectionTrail), [1, 1, 2, 4]);
    });

    rigTest('the countdown ticks down once per second', (rig) async {
      rig.server.failNextConnections(4);
      rig.engine.start();

      for (var i = 0; i < 9; i++) {
        await rig.run(1000);
      }

      expect(rawCountdown(rig.connectionTrail), [1, 1, 2, 1, 4, 3, 2, 1]);
      expect(rig.readyCount, 1);
    });

    rigTest('the delay is capped at 30 s', (rig) async {
      rig.server.failNextConnections(12);
      rig.engine.start();

      for (var i = 0; i < 250; i++) {
        await rig.run(1000);
      }

      final seconds = reconnectSeconds(rig.connectionTrail);
      expect(seconds.take(8).toList(), [1, 1, 2, 4, 8, 16, 30, 30]);
      expect(seconds.where((s) => s > 30), isEmpty);
      expect(rig.readyCount, 1);
    });

    rigTest('the lowest jitter shortens delays by 20 percent', (rig) async {
      final low = EngineRig(rig.tester, jitter: 0);
      low.server.failNextConnections(7);
      low.engine.start();

      for (var i = 0; i < 160; i++) {
        await low.run(1000);
      }

      expect(reconnectSeconds(low.connectionTrail).take(7).toList(), [
        1,
        1,
        2,
        4,
        7,
        13,
        24,
      ]);
      await low.dispose();
    });

    rigTest('the highest jitter lengthens delays by 20 percent', (rig) async {
      final high = EngineRig(rig.tester, jitter: 1);
      high.server.failNextConnections(7);
      high.engine.start();

      for (var i = 0; i < 220; i++) {
        await high.run(1000);
      }

      expect(reconnectSeconds(high.connectionTrail).take(7).toList(), [
        1,
        2,
        3,
        5,
        10,
        20,
        36,
      ]);
      await high.dispose();
    });

    rigTest('4008 waits at least 30 s even with the lowest jitter', (
      rig,
    ) async {
      final low = EngineRig(rig.tester, jitter: 0);
      await low.start();

      low.server.closeConnections(4008);
      await low.run(1);
      expect(low.connectionTrail.last, ('reconnecting', 30));
      await low.run(29000);
      expect(low.server.connectAttempts, 1);
      await low.run(1500);
      expect(low.server.connectAttempts, 2);
      expect(low.readyCount, 2);
      await low.dispose();
    });

    rigTest('4400 reports the violation and reconnects with backoff', (
      rig,
    ) async {
      await rig.start();

      rig.server.closeConnections(4400, 'bad frame');
      await rig.run(1);

      expect(rig.issues, [const ClosedForProtocolViolation('bad frame')]);
      await rig.run(600);
      expect(rig.server.connectAttempts, 2);
      expect(rig.readyCount, 2);
    });

    rigTest('a reconnect resumes from the last applied seq via a delta', (
      rig,
    ) async {
      await rig.start();
      rig.server.dropConnections();
      await rig.run(1);
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'while away'));
      await rig.run(700);

      expect(rig.server.receivedHelloSeqs, [10, 10]);
      expect(rig.eventSeqs, [11]);
      expect(rig.engine.lastSeq, 11);
      expect(rig.server.snapshotsSent, 0);
    });

    rigTest('the next hello after progress carries the new last_seq', (
      rig,
    ) async {
      await rig.start();
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'one'));
      await rig.run(10);

      rig.server.dropConnections();
      await rig.run(700);

      expect(rig.server.receivedHelloSeqs, [10, 11]);
    });

    rigTest('retryNow skips the wait while backing off', (rig) async {
      rig.server.failNextConnections(3);
      rig.engine.start();
      await rig.run(1);
      await rig.run(600);
      expect(rig.server.connectAttempts, 2);

      rig.engine.retryNow();
      await rig.run(10);

      expect(rig.server.connectAttempts, 3);
      await rig.run(3000);
      expect(rig.server.connectAttempts, 4);
      expect(rig.readyCount, 1);
    });

    rigTest('retryNow is a no-op while connected and after close', (rig) async {
      await rig.start();

      rig.engine.retryNow();
      await rig.run(10);
      expect(rig.server.connectAttempts, 1);

      await rig.engine.close();
      rig.engine.retryNow();
      await rig.run(10);
      expect(rig.server.connectAttempts, 1);
    });

    rigTest('close cancels a pending reconnect and reports offline', (
      rig,
    ) async {
      await rig.start();
      rig.server.dropConnections();
      await rig.run(1);

      await rig.engine.close();
      await rig.run(60000);

      expect(rig.server.connectAttempts, 1);
      expect(rig.of<ConnectionSignal>().last.status, ConnectionStatus.offline);
      expect(rig.engine.isRunning, isFalse);
    });

    rigTest('close shuts the socket and the server sees no connection', (
      rig,
    ) async {
      await rig.start();

      await rig.engine.close();

      expect(rig.server.openConnections, 0);
    });

    rigTest('the engine can be started again after close', (rig) async {
      await rig.start();
      await rig.engine.close();

      await rig.start();

      expect(rig.server.connectAttempts, 2);
      expect(rig.readyCount, 2);
    });

    rigTest('start twice does not open two sockets', (rig) async {
      rig.engine.start();
      rig.engine.start();
      await rig.run(10);

      expect(rig.server.connectAttempts, 1);
    });

    rigTest('a disposed engine ignores start and closes its streams', (
      rig,
    ) async {
      await rig.start();
      var done = false;
      rig.engine.signals.listen((_) {}, onDone: () => done = true);

      await rig.engine.dispose();
      await rig.engine.dispose();
      rig.engine.start();
      await rig.run(10);

      expect(done, isTrue);
      expect(rig.server.connectAttempts, 1);
    });

    rigTest('close during an unfinished connect drops the late socket', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.transport.gate = Completer<ManualChannel>();
      m.engine.start();
      await rig.run(10);
      await m.engine.close();

      final late = ManualChannel();
      m.transport.gate!.complete(late);
      await rig.run(10);

      expect(late.closedByClient, isTrue);
      expect(late.sent, isEmpty);
      await m.engine.dispose();
    });
  });

  group('terminal closes', () {
    for (final entry in <int, BoardEndReason>{
      4003: BoardEndReason.removed,
      4004: BoardEndReason.boardDeleted,
    }.entries) {
      rigTest('${entry.key} ends the board and never reconnects', (rig) async {
        await rig.start();
        rig.clearSignals();

        rig.server.closeConnections(entry.key);
        await rig.run(60000);

        expect(rig.server.connectAttempts, 1);
        expect(rig.of<EndedSignal>().single.reason, entry.value);
        expect(rig.connectionTrail, [('offline', null)]);
        expect(rig.signals.first, isA<ConnectionSignal>());
        expect(rig.signals.last, isA<EndedSignal>());
        expect(rig.engine.isRunning, isFalse);
      });
    }

    rigTest('after an end the engine does not accept operations', (rig) async {
      await rig.start();
      rig.server.closeConnections(4003);
      await rig.run(10);

      expect(rig.engine.send(moveA1('x')), SendOutcome.notConnected);
    });

    rigTest('the session ending on connect ends the board', (rig) async {
      rig.creds.ended = true;

      rig.engine.start();
      await rig.run(10);

      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.sessionEnded);
      expect(rig.server.connectAttempts, 0);
    });
  });

  group('ready timeout and stream failures', () {
    rigTest('no sync.ready within 30 s recycles the connection', (rig) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(29900);
      expect(m.transport.channels, hasLength(1));
      expect(m.channel.closedByClient, isFalse);

      await rig.run(200);

      expect(m.transport.channels.first.closedByClient, isTrue);
      expect(m.transport.channels.first.clientCloseCode, 1000);
      expect(reconnectSeconds(m.trail), [1]);
      await rig.run(600);
      expect(m.transport.channels, hasLength(2));
      expect(m.channel.sentTypes, ['hello']);
      await m.engine.dispose();
    });

    rigTest('sync.ready cancels the ready timeout', (rig) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      m.channel.pushJson(serverMessage('sync.ready'));
      await rig.run(60000);

      expect(m.transport.channels, hasLength(1));
      expect(m.channel.closedByClient, isFalse);
      await m.engine.dispose();
    });

    rigTest('a binary frame is reported, the socket is closed and the engine '
        'reconnects', (rig) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      final first = m.channel;

      first.pushError(const FormatException('binary frame'));
      await rig.run(10);

      expect(m.issues, [const BinaryFrameReceived()]);
      expect(first.closedByClient, isTrue);
      await rig.run(600);
      expect(m.transport.channels, hasLength(2));
      await m.engine.dispose();
    });

    rigTest('a transport error reconnects without a protocol issue', (
      rig,
    ) async {
      final m = ManualEngine(rig);
      m.engine.start();
      await rig.run(10);
      final first = m.channel;

      first.pushError(Exception('boom'));
      await rig.run(600);

      expect(m.issues, isEmpty);
      expect(first.closedByClient, isTrue);
      expect(m.transport.channels, hasLength(2));
      await m.engine.dispose();
    });
  });
}
