import 'dart:convert';

import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/boards/domain/board_info.dart';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/realtime/message_codec.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/engine_rig.dart';
import '../../helpers/event_factory.dart';

void main() {
  group('idempotency like the real server', () {
    rigTest('a replayed op_id returns the same event and no new seq', (
      rig,
    ) async {
      await rig.start();
      rig.engine.send(moveA1('same'));
      await rig.run(10);
      final first = rig.of<EventsSignal>().single.events.single;
      expect(rig.server.seq, 11);

      rig.server.dropConnections();
      await rig.run(700);
      rig.engine.send(moveA1('same'));
      await rig.run(10);

      expect(rig.server.seq, 11);
      expect(rig.server.log.where((e) => e.opId == 'same'), hasLength(1));
      expect(rig.of<DuplicatesSignal>().expand((s) => s.opIds), ['same']);
      expect(rig.engine.lastSeq, 11);
      expect(first.opId, 'same');
    });

    rigTest('a replayed op_id re-sends the identical event envelope', (
      rig,
    ) async {
      await rig.start();
      final socket = rig.server.sockets.single;
      final received = <Map<String, dynamic>>[];
      final channel = await rig.server.connect(
        Uri.parse('ws://x.test/ws/boards/board'),
        headers: const {'Authorization': 'Bearer t'},
      );
      channel.messages.listen(
        (text) => received.add(jsonDecode(text) as Map<String, dynamic>),
      );
      channel.send(encodeHello(lastSeq: 10, client: 'second'));
      await rig.run(10);

      channel.send(encodeOp(moveA1('dup')));
      await rig.run(10);
      channel.send(encodeOp(moveA1('dup')));
      await rig.run(10);

      final cardEvents = received
          .where((m) => m['type'] == 'card.moved')
          .toList();
      expect(cardEvents, hasLength(2));
      expect(cardEvents[0], cardEvents[1]);
      expect(socket.isClosed, isFalse);
      channel.close();
    });

    rigTest('a replayed rejected op returns the same nack even after the '
        'board moved on', (rig) async {
      await rig.start();
      rig.engine.send(moveA1('stale', baseVersion: 99));
      await rig.run(10);
      final first = rig.of<NackSignal>().single;
      expect(first.rejection.reason, NackReason.versionConflict);
      expect(first.rejection.atSeq, 10);

      rig.server.commitEvent((seq, ts) => renamed(seq));
      rig.server.commitEvent((seq, ts) => renamed(seq));
      await rig.run(10);
      rig.engine.send(moveA1('stale', baseVersion: 99));
      await rig.run(10);

      final nacks = rig.of<NackSignal>();
      expect(nacks, hasLength(2));
      expect(nacks.last.rejection.reason, NackReason.versionConflict);
      expect(nacks.last.rejection.atSeq, 10);
      expect(rig.server.seq, 12);
    });

    rigTest('a replayed op is accepted only once even if the first copy '
        'raced a drop', (rig) async {
      await rig.start();
      rig.server.suppressNextBroadcasts(1);
      rig.engine.send(moveA1('raced'));
      await rig.run(10);
      rig.server.dropConnections();
      await rig.run(700);

      rig.engine.send(moveA1('raced'));
      await rig.run(10);

      expect(rig.server.log.where((e) => e.opId == 'raced'), hasLength(1));
      expect(rig.engine.lastSeq, rig.server.seq);
    });

    rigTest('forgetProcessed makes the server treat the op as new', (
      rig,
    ) async {
      await rig.start();
      rig.engine.send(
        const EditCardTitle(
          opId: 't1',
          cardId: 'a1',
          title: 'One',
          actorId: 'u1',
        ),
      );
      await rig.run(10);
      rig.server.forgetProcessed('t1');

      rig.engine.send(
        const EditCardTitle(
          opId: 't1',
          cardId: 'a1',
          title: 'Two',
          actorId: 'u1',
        ),
      );
      await rig.run(10);

      expect(rig.server.seq, 12);
    });

    rigTest('resyncRequiredFor answers with a resync_required nack', (
      rig,
    ) async {
      await rig.start();
      rig.server.resyncRequiredFor('gone');

      rig.engine.send(moveA1('gone'));
      await rig.run(10);

      expect(
        rig.of<NackSignal>().single.rejection.reason,
        NackReason.resyncRequired,
      );
      expect(rig.server.seq, 10);
    });
  });

  group('protocol strictness', () {
    Future<List<Map<String, dynamic>>> talk(
      EngineRig rig,
      List<String> frames, {
      bool hello = true,
    }) async {
      final received = <Map<String, dynamic>>[];
      final channel = await rig.server.connect(
        Uri.parse('ws://x.test/ws/boards/board'),
        headers: const {'Authorization': 'Bearer t'},
      );
      channel.messages.listen(
        (text) => received.add(jsonDecode(text) as Map<String, dynamic>),
      );
      if (hello) {
        channel.send(encodeHello(lastSeq: 10, client: 'raw'));
        await rig.run(10);
        received.clear();
      }
      for (final frame in frames) {
        channel.send(frame);
      }
      await rig.run(10);
      channel.close();
      return received;
    }

    String errorCode(Map<String, dynamic> message) =>
        (message['payload'] as Map)['code'] as String;

    rigTest('malformed JSON and a wrong version are protocol errors', (
      rig,
    ) async {
      final received = await talk(rig, [
        '{nope',
        '{"v":2,"type":"hello"}',
        '[1]',
      ]);

      expect(received.map(errorCode), [
        'protocol_error',
        'protocol_error',
        'protocol_error',
      ]);
    });

    rigTest('unknown envelope fields are rejected', (rig) async {
      final received = await talk(rig, [
        '{"v":1,"type":"op.card.archive","op_id":"o","seq":3,'
            '"payload":{"card_id":"a1"}}',
      ]);

      expect(received.single['type'], 'error');
    });

    rigTest('an operation without op_id is a protocol error', (rig) async {
      final received = await talk(rig, [
        '{"v":1,"type":"op.card.archive","payload":{"card_id":"a1"}}',
      ]);

      expect(errorCode(received.single), 'protocol_error');
      expect(rig.server.receivedOps, isEmpty);
    });

    rigTest('an operation before the handshake is a protocol error', (
      rig,
    ) async {
      final received = await talk(rig, [
        encodeOp(moveA1('early')),
      ], hello: false);

      expect(errorCode(received.single), 'protocol_error');
      expect(rig.server.receivedOps, isEmpty);
    });

    rigTest('unknown payload fields are rejected like the real server', (
      rig,
    ) async {
      final received = await talk(rig, [
        '{"v":1,"type":"op.card.archive","op_id":"o",'
            '"payload":{"card_id":"a1","extra":1}}',
      ]);

      expect(errorCode(received.single), 'protocol_error');
      expect(rig.server.seq, 10);
    });

    rigTest('an unknown operation type is a protocol error', (rig) async {
      final received = await talk(rig, [
        '{"v":1,"type":"op.card.explode","op_id":"o","payload":{}}',
      ]);

      expect(errorCode(received.single), 'protocol_error');
    });

    rigTest('auth.refresh with a non string token is invalid_token', (
      rig,
    ) async {
      final received = await talk(rig, [
        '{"v":1,"type":"auth.refresh","payload":{"access_token":5}}',
      ]);

      expect(errorCode(received.single), 'invalid_token');
    });
  });

  group('server hooks', () {
    rigTest('rejectWhen forces a nack without storing it', (rig) async {
      await rig.start();
      rig.server.rejectWhen = (op) => op.opId == 'bad'
          ? const OpRejection(reason: NackReason.forbidden)
          : null;

      rig.engine.send(moveA1('bad'));
      rig.engine.send(moveA1('good'));
      await rig.run(10);

      expect(rig.of<NackSignal>().single.opId, 'bad');
      expect(rig.of<NackSignal>().single.rejection.atSeq, 10);
      expect(rig.server.log.single.opId, 'good');
    });

    rigTest('viewers get forbidden for every operation', (rig) async {
      rig.server.changeRole('u1', BoardRole.viewer);
      await rig.start();

      rig.engine.send(moveA1('v1'));
      await rig.run(10);

      expect(
        rig.of<NackSignal>().single.rejection.reason,
        NackReason.forbidden,
      );
      expect(rig.server.currentRole, BoardRole.viewer);
    });

    rigTest('commitRemote returns null for an invalid op and skips seq', (
      rig,
    ) async {
      final event = rig.server.commitRemote(
        moveA1('x', baseVersion: 42),
        actorId: 'u2',
      );

      expect(event, isNull);
      expect(rig.server.seq, 10);
    });

    rigTest('commitRemote with deliver false holds the event until flush', (
      rig,
    ) async {
      await rig.start();
      rig.server.commitRemote(moveA1('held'), actorId: 'u2', deliver: false);
      await rig.run(10);
      expect(rig.engine.lastSeq, 10);
      expect(rig.server.seq, 11);

      rig.server.flushHeld();
      await rig.run(10);

      expect(rig.engine.lastSeq, 11);
    });

    rigTest('announceConflicts flushes held events before a conflict nack', (
      rig,
    ) async {
      await rig.start();
      rig.server.commitRemote(
        const EditCardDescription(
          opId: 'remote',
          cardId: 'a1',
          description: 'theirs',
          baseDescriptionVersion: 1,
          actorId: 'u2',
        ),
        actorId: 'u2',
        deliver: false,
      );

      rig.engine.send(
        const EditCardDescription(
          opId: 'mine',
          cardId: 'a1',
          description: 'mine',
          baseDescriptionVersion: 1,
          actorId: 'u1',
        ),
      );
      await rig.run(10);

      expect(rig.eventSeqs, [11]);
      expect(rig.of<NackSignal>().single.rejection.atSeq, 11);
      expect(
        rig.signals.indexOf(rig.of<EventsSignal>().single),
        lessThan(rig.signals.indexOf(rig.of<NackSignal>().single)),
      );
    });

    rigTest('suppressNextBroadcasts hides an event but keeps it in the log', (
      rig,
    ) async {
      await rig.start();
      rig.server.suppressNextBroadcasts(1);

      rig.server.commitEvent((seq, ts) => renamed(seq));
      await rig.run(10);

      expect(rig.server.log.single.seq, 11);
      expect(rig.engine.lastSeq, 10);
    });

    rigTest('pruneLog drops old events and makes catch-up answer 410', (
      rig,
    ) async {
      rig.server.commitEvent((seq, ts) => renamed(seq));
      rig.server.commitEvent((seq, ts) => renamed(seq));
      rig.server.pruneLog(11);

      final gone = await rig.server.getEvents('board', 10);
      final fine = await rig.server.getEvents('board', 11);

      expect(rig.server.log.map((e) => e.seq), [12]);
      expect(gone, isA<Failure<EventsPage, ApiFailure>>());
      expect(fine, isA<Success<EventsPage, ApiFailure>>());
    });

    rigTest('failNextEventFetches fails the next N catch-up requests', (
      rig,
    ) async {
      rig.server.failNextEventFetches(2);

      final results = [
        await rig.server.getEvents('board', 10),
        await rig.server.getEvents('board', 10),
        await rig.server.getEvents('board', 10),
      ];

      expect(results.map((r) => r is Failure<EventsPage, ApiFailure>), [
        true,
        true,
        false,
      ]);
      expect(rig.server.eventFetches, 3);
    });

    rigTest('refuseConnections rejects every attempt until lifted', (
      rig,
    ) async {
      rig.server.refuseConnections(true);
      rig.engine.start();
      await rig.run(8000);
      expect(rig.readyCount, 0);
      expect(rig.server.connectAttempts, greaterThan(2));

      rig.server.refuseConnections(false);
      await rig.run(40000);

      expect(rig.readyCount, 1);
    });

    rigTest('removeMember of the current user closes with 4003', (rig) async {
      await rig.start();

      rig.server.removeMember('u1');
      await rig.run(10);

      expect(rig.server.board.memberById('u1'), isNull);
      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.removed);
      expect(rig.eventSeqs, [11]);
    });

    rigTest('removeMember of someone else keeps the socket', (rig) async {
      await rig.start();
      rig.server.commitEvent((seq, ts) => memberAdded(seq, 'u7'));

      rig.server.removeMember('u7');
      await rig.run(10);

      expect(rig.of<EndedSignal>(), isEmpty);
      expect(rig.server.board.memberById('u7'), isNull);
    });

    rigTest('deleteBoard closes with 4004 after the board.deleted event', (
      rig,
    ) async {
      await rig.start();

      rig.server.deleteBoard();
      await rig.run(10);

      expect(rig.of<EndedSignal>().single.reason, BoardEndReason.boardDeleted);
      expect(rig.server.log.last, isA<BoardDeletedEvent>());
    });

    rigTest('renameBoard and changeRole publish events', (rig) async {
      await rig.start();

      rig.server.renameBoard('Fresh title');
      rig.server.changeRole('u1', BoardRole.viewer);
      await rig.run(10);

      expect(rig.server.board.title, 'Fresh title');
      expect(rig.server.currentRole, BoardRole.viewer);
      expect(rig.eventSeqs, [11, 12]);
    });

    rigTest('latency delays the processing of an operation', (rig) async {
      final slow = EngineRig(rig.tester, latency: const Duration(seconds: 2));
      await slow.start();

      slow.engine.send(moveA1('slow'));
      await slow.run(1900);
      expect(slow.server.seq, 10);
      await slow.run(200);

      expect(slow.server.seq, 11);
      await slow.dispose();
    });

    rigTest('an operation on a closed socket is dropped silently', (rig) async {
      final slow = EngineRig(rig.tester, latency: const Duration(seconds: 2));
      await slow.start();
      slow.engine.send(moveA1('lost'));
      await slow.run(10);

      slow.server.dropConnections();
      await slow.run(3000);

      expect(slow.server.seq, 10);
      await slow.dispose();
    });

    rigTest('the snapshot excludes archived cards', (rig) async {
      rig.server.commitEvent((seq, ts) => cardArchived(seq, 'a1', colA));

      final board = await rig.server.getBoard('board');

      final snapshot = (board as Success<ServerBoard, ApiFailure>).value;
      expect(snapshot.model.cards.any((c) => c.id == 'a1'), isFalse);
    });
  });
}
