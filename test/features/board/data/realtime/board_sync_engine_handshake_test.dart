import 'dart:async';
import 'dart:convert';

import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/fake/fake_board_server.dart';
import 'package:cardo/features/board/data/realtime/event_codec.dart';
import 'package:cardo/features/board/data/realtime/message_codec.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/engine_rig.dart';
import '../../helpers/event_factory.dart';
import '../../helpers/manual_transport.dart';

Future<List<Map<String, dynamic>>> rawHandshake(
  EngineRig rig,
  FakeBoardServer server,
  Object? lastSeq,
) async {
  final channel = await server.connect(
    Uri.parse('ws://x.test/ws/boards/board'),
    headers: const {'Authorization': 'Bearer t'},
  );
  final received = <Map<String, dynamic>>[];
  channel.messages.listen(
    (text) => received.add(jsonDecode(text) as Map<String, dynamic>),
  );
  channel.send(
    jsonEncode({
      'v': 1,
      'type': 'hello',
      'payload': {'last_seq': lastSeq, 'client': 'test'},
    }),
  );
  await rig.run(10);
  unawaited(channel.close());
  return received;
}

List<String> typesOf(List<Map<String, dynamic>> messages) => [
  for (final message in messages) message['type'] as String,
];

void main() {
  group('handshake', () {
    rigTest('connects with a bearer header and a hello with last_seq', (
      rig,
    ) async {
      await rig.start();

      expect(rig.server.connectTokens, ['tok-0']);
      expect(rig.server.receivedHelloSeqs, [10]);
      expect(rig.server.receivedTypes, ['hello']);
      expect(rig.server.sockets.single.headers, {
        'Authorization': 'Bearer tok-0',
      });
      expect(rig.readyCount, 1);
      expect(rig.engine.isReady, isTrue);
      expect(rig.engine.isRunning, isTrue);
    });

    rigTest('the first signal is syncing and the status never claims online', (
      rig,
    ) async {
      await rig.start();

      expect(rig.of<ConnectionSignal>().first.status, ConnectionStatus.syncing);
      expect(
        rig.of<ConnectionSignal>().map((s) => s.status),
        everyElement(ConnectionStatus.syncing),
      );
      expect(rig.signals.last, isA<ReadySignal>());
    });

    rigTest('the socket path is ws/boards/id under the base path and has no '
        'token', (rig) async {
      expect(
        rig.engine.socketUri.toString(),
        'ws://x.test/pre/ws/boards/board',
      );
      expect(rig.engine.socketUri.query, isEmpty);
      expect(rig.engine.socketUri.toString(), isNot(contains('tok')));
    });

    rigTest('the hello payload is exactly last_seq and the client name', (
      rig,
    ) async {
      final transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      engine.signals.listen((_) {});
      engine.start();
      await rig.run(10);

      final hello = transport.last.sentMessages.single;
      expect(hello['type'], 'hello');
      expect(hello['v'], 1);
      expect(hello['payload'], {'last_seq': 10, 'client': 'flutter/0.1.0'});
      expect(transport.headers.single, {'Authorization': 'Bearer tok-0'});
      await engine.dispose();
    });

    rigTest('an up-to-date client gets an empty delta, not a snapshot', (
      rig,
    ) async {
      await rig.start();

      expect(rig.server.deltasSent, 1);
      expect(rig.server.snapshotsSent, 0);
      expect(rig.of<SnapshotSignal>(), isEmpty);
      expect(rig.of<EventsSignal>(), isEmpty);
    });

    rigTest('a small gap is a delta with the missing events in order', (
      rig,
    ) async {
      for (var i = 0; i < 3; i++) {
        rig.server.commitRemote(
          moveA1('r$i', to: i.isEven ? colB : colA, baseVersion: i + 1),
          actorId: 'u2',
        );
      }

      await rig.start();

      expect(rig.server.deltasSent, 1);
      expect(rig.server.snapshotsSent, 0);
      expect(rig.eventSeqs, [11, 12, 13]);
      expect(rig.engine.lastSeq, 13);
    });

    rigTest('a gap of exactly 5000 events is still a delta in chunks of 500', (
      rig,
    ) async {
      for (var i = 0; i < 5000; i++) {
        rig.server.commitEvent((seq, ts) => renamed(seq, title: 't$seq'));
      }

      await rig.start(100);

      expect(rig.server.snapshotsSent, 0);
      expect(rig.server.deltasSent, 10);
      expect(rig.engine.lastSeq, 5010);
      expect(rig.eventSeqs.length, 5000);
      expect(rig.eventSeqs.first, 11);
      expect(rig.eventSeqs.last, 5010);
    });

    rigTest('a gap of 5001 events falls back to a snapshot', (rig) async {
      for (var i = 0; i < 5001; i++) {
        rig.server.commitEvent((seq, ts) => renamed(seq, title: 't$seq'));
      }

      await rig.start(100);

      expect(rig.server.snapshotsSent, 1);
      expect(rig.server.deltasSent, 0);
      final snapshot = rig.of<SnapshotSignal>().single;
      expect(snapshot.board.seq, 5011);
      expect(snapshot.board.title, 't5011');
      expect(rig.engine.lastSeq, 5011);
      expect(rig.of<EventsSignal>(), isEmpty);
    });

    rigTest('a pruned log (410) falls back to a snapshot', (rig) async {
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'one'));
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'two'));
      rig.server.pruneLog(11);

      await rig.start();

      expect(rig.server.snapshotsSent, 1);
      expect(rig.server.deltasSent, 0);
      expect(rig.of<SnapshotSignal>().single.board.title, 'two');
      expect(rig.engine.lastSeq, 12);
    });

    rigTest('a last_seq above the board seq falls back to a snapshot', (
      rig,
    ) async {
      final high = EngineRig(rig.tester, initialSeq: 500);
      await high.start();

      expect(high.server.snapshotsSent, 1);
      expect(high.of<SnapshotSignal>().single.board.seq, 10);
      expect(high.engine.lastSeq, 10);
      await high.dispose();
    });

    rigTest('the snapshot signal comes before presence and ready', (rig) async {
      rig.server.commitEvent((seq, ts) => renamed(seq));
      rig.server.pruneLog(11);

      await rig.start();

      final order = rig.signals
          .where(
            (s) =>
                s is SnapshotSignal ||
                s is PresenceListSignal ||
                s is ReadySignal,
          )
          .map((s) => s.runtimeType)
          .toList();
      expect(order, [SnapshotSignal, PresenceListSignal, ReadySignal]);
    });

    rigTest('the server answers a null last_seq with a snapshot', (rig) async {
      final messages = await rawHandshake(rig, rig.server, null);

      expect(typesOf(messages), [
        'sync.snapshot',
        'presence.list',
        'sync.ready',
      ]);
      expect(rig.server.receivedHelloSeqs, [null]);
    });

    rigTest('the server answers a numeric last_seq with a delta', (rig) async {
      rig.server.commitEvent((seq, ts) => renamed(seq));

      final messages = await rawHandshake(rig, rig.server, 10);

      expect(typesOf(messages), ['sync.delta', 'presence.list', 'sync.ready']);
      final events = (messages.first['payload'] as Map)['events'] as List;
      expect(events, hasLength(1));
    });

    rigTest('a repeated hello on one socket is a protocol error', (rig) async {
      await rig.start();
      final socket = rig.server.sockets.single;

      socket.send(encodeHello(lastSeq: 10, client: 'again'));
      await rig.run(10);

      expect(
        rig.issues.whereType<ServerReportedError>().single.code,
        'protocol_error',
      );
    });

    rigTest('an unsupported platform ends the board with unsupported', (
      rig,
    ) async {
      final transport = ManualTransport()
        ..failures = 1
        ..failWith = const RealtimeUnsupportedException();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      final issues = <ProtocolIssue>[];
      engine.signals.listen(signals.add);
      engine.issues.listen(issues.add);

      engine.start();
      await rig.run(10);

      expect(issues.single, const RealtimeNotSupported());
      expect(
        signals.whereType<EndedSignal>().single.reason.name,
        'unsupported',
      );
      expect(engine.isRunning, isFalse);
      await rig.run(60000);
      expect(transport.uris, hasLength(1));
      await engine.dispose();
    });
  });

  group('operations wait for sync.ready', () {
    rigTest('send before the connection exists is notConnected', (rig) async {
      expect(rig.engine.send(moveA1('x')), SendOutcome.notConnected);
      rig.engine.start();
      expect(rig.engine.send(moveA1('x')), SendOutcome.notConnected);
      await rig.run(10);
      expect(rig.server.receivedOps, isEmpty);
    });

    rigTest('nothing but hello is written until sync.ready arrives', (
      rig,
    ) async {
      final transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      engine.signals.listen((_) {});
      engine.start();
      await rig.run(10);
      final channel = transport.last;
      channel.pushJson(serverMessage('sync.delta', {'events': <Object?>[]}));
      await rig.run(10);

      expect(engine.send(moveA1('early')), SendOutcome.notConnected);
      expect(channel.sentTypes, ['hello']);

      channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      expect(engine.send(moveA1('late')), SendOutcome.sent);
      expect(channel.sentTypes, ['hello', 'op.card.move']);
      expect(channel.sentMessages.last['op_id'], 'late');
      await engine.dispose();
    });

    rigTest('after ready operations reach the server in order with their '
        'op_ids', (rig) async {
      await rig.start();

      for (var i = 0; i < 4; i++) {
        expect(
          rig.engine.send(
            EditCardTitle(
              opId: 'op-$i',
              cardId: 'a1',
              title: 'T$i',
              actorId: 'u1',
            ),
          ),
          SendOutcome.sent,
        );
      }
      await rig.run(10);

      expect(rig.server.receivedOps.map((op) => op.opId), [
        'op-0',
        'op-1',
        'op-2',
        'op-3',
      ]);
      expect(rig.eventSeqs, [11, 12, 13, 14]);
      expect(
        rig.of<EventsSignal>().expand((s) => s.events).map((e) => e.opId),
        ['op-0', 'op-1', 'op-2', 'op-3'],
      );
    });

    rigTest('an oversized operation is not sent and reports tooLarge', (
      rig,
    ) async {
      await rig.start();
      final big = EditCardDescription(
        opId: 'big',
        cardId: 'a1',
        description: 'x' * 70000,
        baseDescriptionVersion: 1,
        actorId: 'u1',
      );

      expect(rig.engine.send(big), SendOutcome.tooLarge);
      await rig.run(10);

      expect(rig.server.receivedOps, isEmpty);
      final issue = rig.issues.whereType<OutgoingTooLarge>().single;
      expect(issue.bytes, greaterThan(65536));
    });

    rigTest('a multi-byte message is measured in bytes', (rig) async {
      await rig.start();
      final text = 'я' * 33000;
      final op = EditCardDescription(
        opId: 'ru',
        cardId: 'a1',
        description: text,
        baseDescriptionVersion: 1,
        actorId: 'u1',
      );

      expect(text.length, lessThan(65536));
      expect(rig.engine.send(op), SendOutcome.tooLarge);
    });

    rigTest('the limit is inclusive: exactly 64 KB goes out, one more byte '
        'does not', (rig) async {
      await rig.start();
      EditCardDescription withLength(int length) => EditCardDescription(
        opId: 'edge',
        cardId: 'a1',
        description: 'x' * length,
        baseDescriptionVersion: 1,
        actorId: 'u1',
      );
      final overhead = utf8Length(encodeOp(withLength(0)));
      final exact = 65536 - overhead;

      expect(utf8Length(encodeOp(withLength(exact))), 65536);
      expect(utf8Length(encodeOp(withLength(exact + 1))), 65537);
      expect(rig.engine.send(withLength(exact)), SendOutcome.sent);
      expect(rig.engine.send(withLength(exact + 1)), SendOutcome.tooLarge);
      await rig.run(10);
    });

    rigTest('a write failure on a closed socket reports notConnected', (
      rig,
    ) async {
      final transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      engine.signals.listen((_) {});
      engine.start();
      await rig.run(10);
      transport.last.pushJson(serverMessage('sync.ready'));
      await rig.run(10);
      transport.last.throwOnSend = true;

      expect(engine.send(moveA1('x')), SendOutcome.notConnected);
      await engine.dispose();
    });

    rigTest('after close the engine no longer sends', (rig) async {
      await rig.start();
      await rig.engine.close();

      expect(rig.engine.send(moveA1('x')), SendOutcome.notConnected);
      expect(rig.engine.isReady, isFalse);
      expect(rig.engine.isRunning, isFalse);
    });
  });

  group('live events during the handshake', () {
    late ManualTransport transport;

    BoardEvent event(int seq, {String? opId}) =>
        renamed(seq, opId: opId, title: 'e$seq');

    Map<String, Object?> eventMessage(BoardEvent event) =>
        encodeEventEnvelope(event);

    rigTest('a live event between the delta and ready is deduplicated by seq', (
      rig,
    ) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);
      final channel = transport.last;

      channel.pushJson(
        serverMessage('sync.delta', {
          'events': [
            eventMessage(event(11, opId: 'a')),
            eventMessage(event(12, opId: 'b')),
          ],
        }),
      );
      channel.pushJson(eventMessage(event(12, opId: 'b')));
      channel.pushJson(eventMessage(event(13)));
      channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      final seqs = [
        for (final s in signals.whereType<EventsSignal>())
          for (final e in s.events) e.seq,
      ];
      expect(seqs, [11, 12, 13]);
      expect(signals.whereType<DuplicatesSignal>().expand((s) => s.opIds), [
        'b',
      ]);
      expect(engine.lastSeq, 13);
      await engine.dispose();
    });

    rigTest('a live event that overtakes the delta waits in the buffer', (
      rig,
    ) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);
      final channel = transport.last;

      channel.pushJson(eventMessage(event(13)));
      channel.pushJson(eventMessage(event(14)));
      await rig.run(10);
      expect(signals.whereType<EventsSignal>(), isEmpty);
      expect(engine.lastSeq, 10);

      channel.pushJson(
        serverMessage('sync.delta', {
          'events': [eventMessage(event(11)), eventMessage(event(12))],
        }),
      );
      channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      final seqs = [
        for (final s in signals.whereType<EventsSignal>())
          for (final e in s.events) e.seq,
      ];
      expect(seqs, [11, 12, 13, 14]);
      expect(engine.lastSeq, 14);
      await engine.dispose();
    });

    rigTest('live events older than a snapshot are dropped, newer ones '
        'applied', (rig) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);
      final channel = transport.last;
      channel.pushJson(eventMessage(event(19, opId: 'old')));
      channel.pushJson(eventMessage(event(21)));
      channel.pushJson(
        serverMessage('sync.snapshot', snapshotMapFor(rig, seq: 20)),
      );
      channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      expect(signals.whereType<SnapshotSignal>().single.board.seq, 20);
      final seqs = [
        for (final s in signals.whereType<EventsSignal>())
          for (final e in s.events) e.seq,
      ];
      expect(seqs, [21]);
      expect(signals.whereType<DuplicatesSignal>().expand((s) => s.opIds), [
        'old',
      ]);
      expect(engine.lastSeq, 21);
      await engine.dispose();
    });

    rigTest('a mid-session event with an unknown type is reported and '
        'skipped', (rig) async {
      await rig.start();

      rig.server.commitEvent(
        (seq, ts) => UnknownBoardEvent(
          seq: seq,
          serverTs: ts,
          unknownType: 'card.teleported',
        ),
      );
      rig.server.commitEvent((seq, ts) => renamed(seq, title: 'after'));
      await rig.run(10);

      expect(rig.issues.whereType<UnknownMessageType>(), isNotEmpty);
      expect(rig.engine.lastSeq, 12);
    });

    rigTest('garbage frames become protocol issues and do not stop the '
        'engine', (rig) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final issues = <ProtocolIssue>[];
      final signals = <SyncSignal>[];
      engine.issues.listen(issues.add);
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);
      final channel = transport.last;

      channel.push('{broken');
      channel.push('{"v":2,"type":"sync.ready"}');
      channel.push('{"v":1,"type":"mystery"}');
      channel.pushJson(serverMessage('sync.ready'));
      await rig.run(10);

      expect(issues, [
        isA<MalformedMessage>(),
        isA<UnsupportedVersion>(),
        isA<UnknownMessageType>(),
      ]);
      expect(signals.whereType<ReadySignal>(), hasLength(1));
      await engine.dispose();
    });

    rigTest('an error message is surfaced as a server reported error', (
      rig,
    ) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final issues = <ProtocolIssue>[];
      engine.issues.listen(issues.add);
      engine.signals.listen((_) {});
      engine.start();
      await rig.run(10);

      transport.last.pushJson(
        serverMessage('error', {'code': 'protocol_error', 'message': 'bad'}),
      );
      await rig.run(10);

      expect(issues.single, const ServerReportedError('protocol_error', 'bad'));
      expect(transport.channels, hasLength(1));
      await engine.dispose();
    });

    rigTest('a nack without an op_id is reported and not forwarded', (
      rig,
    ) async {
      transport = ManualTransport();
      final engine = buildEngine(
        transport: transport,
        credentials: rig.creds,
        catchUp: StubCatchUp(),
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final issues = <ProtocolIssue>[];
      final signals = <SyncSignal>[];
      engine.issues.listen(issues.add);
      engine.signals.listen(signals.add);
      engine.start();
      await rig.run(10);

      transport.last.pushJson(
        serverMessage('nack', {'reason': 'forbidden', 'at_seq': 3}),
      );
      await rig.run(10);

      expect(issues.single, const NackWithoutOpId());
      expect(signals.whereType<NackSignal>(), isEmpty);
      await engine.dispose();
    });
  });

  group('nacks and presence', () {
    rigTest('a nack carries its reason, at_seq and op_id', (rig) async {
      await rig.start();
      rig.server.rejectWhen = (op) =>
          const OpRejection(reason: NackReason.forbidden, atSeq: 7);

      rig.engine.send(moveA1('nope'));
      await rig.run(10);

      final nack = rig.of<NackSignal>().single;
      expect(nack.opId, 'nope');
      expect(nack.rejection.reason, NackReason.forbidden);
      expect(nack.rejection.atSeq, 7);
    });

    for (final reason in NackReason.values) {
      rigTest('the engine forwards a ${reason.name} nack unchanged', (
        rig,
      ) async {
        await rig.start();
        rig.server.rejectWhen = (op) => OpRejection(reason: reason, atSeq: 9);

        rig.engine.send(moveA1('x'));
        await rig.run(10);

        expect(rig.of<NackSignal>().single.rejection.reason, reason);
        expect(rig.of<NackSignal>().single.rejection.atSeq, 9);
      });
    }

    rigTest('presence list, join and leave are forwarded in order', (
      rig,
    ) async {
      const joined = PresenceUser(
        userId: 'u9',
        name: 'Nine',
        avatarColor: '#999999',
      );
      await rig.start();

      rig.server.userJoined(joined);
      rig.server.userLeft('u9');
      await rig.run(10);

      final presence = rig.signals
          .where((s) => s.runtimeType.toString().startsWith('Presence'))
          .map((s) => s.runtimeType.toString())
          .toList();
      expect(presence, [
        'PresenceListSignal',
        'PresenceJoinSignal',
        'PresenceLeaveSignal',
      ]);
      expect(rig.of<PresenceJoinSignal>().single.user, joined);
      expect(rig.of<PresenceLeaveSignal>().single.userId, 'u9');
    });

    rigTest('the presence list at handshake contains the online users', (
      rig,
    ) async {
      final withPresence = FakeBoardServer(
        initial: makeBoard(),
        currentUserId: 'u1',
        scheduler: rig.scheduler,
        online: const [
          PresenceUser(userId: 'u1', name: 'One', avatarColor: '#111111'),
          PresenceUser(userId: 'u2', name: 'Two', avatarColor: '#222222'),
        ],
      );
      final engine = buildEngine(
        transport: withPresence,
        credentials: rig.creds,
        catchUp: withPresence,
        initialSeq: 10,
        scheduler: rig.scheduler,
        now: rig.now,
        random: rig.random,
      );
      final signals = <SyncSignal>[];
      engine.signals.listen(signals.add);

      engine.start();
      await rig.run(10);

      expect(
        signals.whereType<PresenceListSignal>().single.users.map(
          (u) => u.userId,
        ),
        ['u1', 'u2'],
      );
      await engine.dispose();
    });
  });
}

Map<String, Object?> snapshotMapFor(EngineRig rig, {required int seq}) {
  return {
    'board': {
      'id': 'board',
      'title': 'Snap',
      'owner_id': 'u1',
      'role': 'editor',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    },
    'columns': [
      {'id': colA, 'title': 'A', 'rank': 'V', 'version': 1},
    ],
    'cards': <Object?>[],
    'members': [
      {
        'user_id': 'u1',
        'display_name': 'One',
        'avatar_color': '#2D68F5',
        'role': 'editor',
        'joined_at': '2026-01-01T00:00:00Z',
      },
    ],
    'seq': seq,
  };
}
