import 'dart:convert';
import 'dart:math' as math;

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/fake/fake_board_server.dart';
import 'package:cardo/features/board/data/realtime/event_codec.dart';
import 'package:cardo/features/board/data/realtime/message_codec.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/event_factory.dart';

Map<String, dynamic> parse(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

Map<String, dynamic> payloadOf(String text) =>
    parse(text)['payload'] as Map<String, dynamic>;

bool hasNull(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is Map) {
    return value.values.any(hasNull);
  }
  if (value is List) {
    return value.any(hasNull);
  }
  return false;
}

String wire(
  String type, {
  Object? payload = const <String, Object?>{},
  Object? v = 1,
  String? opId,
  int? seq,
  int? serverTs,
}) {
  return jsonEncode(<String, Object?>{
    'v': ?v,
    'type': type,
    'op_id': ?opId,
    'seq': ?seq,
    'server_ts': ?serverTs,
    'payload': ?payload,
  });
}

ServerMessage decoded(String text) {
  final result = decodeServerMessage(text);
  expect(result, isA<Success<ServerMessage, ProtocolIssue>>(), reason: text);
  return (result as Success<ServerMessage, ProtocolIssue>).value;
}

ProtocolIssue issueOf(String text) {
  final result = decodeServerMessage(text);
  expect(result, isA<Failure<ServerMessage, ProtocolIssue>>(), reason: text);
  return (result as Failure<ServerMessage, ProtocolIssue>).failure;
}

Map<String, Object?> snapshotPayload({int seq = 42}) => <String, Object?>{
  'board': <String, Object?>{
    'id': 'b1',
    'title': 'Launch',
    'owner_id': 'u1',
    'role': 'editor',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-02T00:00:00Z',
  },
  'columns': <Object?>[
    <String, Object?>{'id': 'k1', 'title': 'Todo', 'rank': 'V', 'version': 2},
    <String, Object?>{'id': 'k2', 'title': 'Done', 'rank': 'W', 'version': 1},
  ],
  'cards': <Object?>[
    <String, Object?>{
      'id': 'c1',
      'column_id': 'k1',
      'title': 'First',
      'description': 'Body',
      'rank': 'V',
      'version': 3,
      'description_version': 2,
      'created_by': 'u1',
      'updated_by': 'u2',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-02T00:00:00Z',
    },
  ],
  'members': <Object?>[
    <String, Object?>{
      'user_id': 'u1',
      'display_name': 'One',
      'avatar_color': '#2D68F5',
      'role': 'owner',
      'joined_at': '2026-01-01T00:00:00Z',
    },
  ],
  'seq': seq,
};

void main() {
  group('encodeHello', () {
    test('sends last_seq as null on a fresh start', () {
      final message = parse(encodeHello(lastSeq: null, client: 'flutter/1'));

      expect(message, <String, Object?>{
        'v': 1,
        'type': 'hello',
        'payload': <String, Object?>{'last_seq': null, 'client': 'flutter/1'},
      });
    });

    test('sends last_seq as a number when known', () {
      final message = parse(encodeHello(lastSeq: 1284, client: 'flutter/1'));

      expect((message['payload'] as Map)['last_seq'], 1284);
      expect(message.containsKey('op_id'), isFalse);
    });

    test('zero is a number, not null', () {
      final message = parse(encodeHello(lastSeq: 0, client: 'c'));

      expect((message['payload'] as Map)['last_seq'], 0);
    });

    test('the payload has exactly last_seq and client', () {
      final payload = payloadOf(encodeHello(lastSeq: 1, client: 'c'));

      expect(payload.keys.toSet(), {'last_seq', 'client'});
    });
  });

  group('encodeAuthRefresh', () {
    test('carries only the access token', () {
      final message = parse(encodeAuthRefresh('tok-123'));

      expect(message, <String, Object?>{
        'v': 1,
        'type': 'auth.refresh',
        'payload': <String, Object?>{'access_token': 'tok-123'},
      });
    });
  });

  group('encodeOp follows the README payload table exactly', () {
    void expectOp(
      BoardOp op,
      String type,
      Map<String, Object?> payload, {
      String? opId,
    }) {
      final text = encodeOp(op);
      final message = parse(text);
      expect(message['v'], 1);
      expect(message['type'], type);
      expect(message['op_id'], opId ?? op.opId);
      expect(message.keys.toSet(), {'v', 'type', 'op_id', 'payload'});
      expect(message['payload'], payload);
      expect(hasNull(message), isFalse, reason: text);
    }

    test('op.card.create without optional fields', () {
      expectOp(
        const CreateCard(
          opId: 'op-1',
          cardId: 'c1',
          columnId: 'k1',
          title: 'Hello',
          actorId: 'u1',
        ),
        'op.card.create',
        {'card_id': 'c1', 'column_id': 'k1', 'title': 'Hello'},
      );
    });

    test('op.card.create with description and both anchors', () {
      expectOp(
        const CreateCard(
          opId: 'op-1',
          cardId: 'c1',
          columnId: 'k1',
          title: 'Hello',
          description: 'Body',
          actorId: 'u1',
          afterId: 'c0',
          beforeId: 'c2',
        ),
        'op.card.create',
        {
          'card_id': 'c1',
          'column_id': 'k1',
          'title': 'Hello',
          'description': 'Body',
          'after_id': 'c0',
          'before_id': 'c2',
        },
      );
    });

    test('op.card.create never leaks the local actor or timestamp', () {
      final text = encodeOp(
        CreateCard(
          opId: 'op-1',
          cardId: 'c1',
          columnId: 'k1',
          title: 'Hello',
          actorId: 'u1',
          at: DateTime.utc(2026),
        ),
      );

      expect(payloadOf(text).containsKey('actor_id'), isFalse);
      expect(payloadOf(text).containsKey('at'), isFalse);
    });

    test('op.card.create with only after_id', () {
      expectOp(
        const CreateCard(
          opId: 'op-1',
          cardId: 'c1',
          columnId: 'k1',
          title: 'T',
          actorId: 'u1',
          afterId: 'c0',
        ),
        'op.card.create',
        {'card_id': 'c1', 'column_id': 'k1', 'title': 'T', 'after_id': 'c0'},
      );
    });

    test('op.card.edit with a title carries only card_id and title', () {
      expectOp(
        const EditCardTitle(
          opId: 'op-2',
          cardId: 'c1',
          title: 'New',
          actorId: 'u1',
        ),
        'op.card.edit',
        {'card_id': 'c1', 'title': 'New'},
      );
    });

    test('op.card.edit with a description carries the base version', () {
      expectOp(
        const EditCardDescription(
          opId: 'op-3',
          cardId: 'c1',
          description: 'Text',
          baseDescriptionVersion: 4,
          actorId: 'u1',
        ),
        'op.card.edit',
        {'card_id': 'c1', 'description': 'Text', 'base_description_version': 4},
      );
    });

    test('op.card.edit keeps an empty description', () {
      expectOp(
        const EditCardDescription(
          opId: 'op-3',
          cardId: 'c1',
          description: '',
          baseDescriptionVersion: 1,
          actorId: 'u1',
        ),
        'op.card.edit',
        {'card_id': 'c1', 'description': '', 'base_description_version': 1},
      );
    });

    test('op.card.move without anchors', () {
      expectOp(
        const MoveCard(
          opId: 'op-4',
          cardId: 'c1',
          toColumnId: 'k2',
          baseVersion: 7,
        ),
        'op.card.move',
        {'card_id': 'c1', 'to_column_id': 'k2', 'base_version': 7},
      );
    });

    test('op.card.move with both anchors', () {
      expectOp(
        const MoveCard(
          opId: 'op-4',
          cardId: 'c1',
          toColumnId: 'k2',
          baseVersion: 7,
          afterId: 'a',
          beforeId: 'b',
        ),
        'op.card.move',
        {
          'card_id': 'c1',
          'to_column_id': 'k2',
          'after_id': 'a',
          'before_id': 'b',
          'base_version': 7,
        },
      );
    });

    test('op.card.archive', () {
      expectOp(
        const ArchiveCard(opId: 'op-5', cardId: 'c1'),
        'op.card.archive',
        {'card_id': 'c1'},
      );
    });

    test('op.column.create without anchors and with them', () {
      expectOp(
        const CreateColumn(opId: 'op-6', columnId: 'k9', title: 'QA'),
        'op.column.create',
        {'column_id': 'k9', 'title': 'QA'},
      );
      expectOp(
        const CreateColumn(
          opId: 'op-6',
          columnId: 'k9',
          title: 'QA',
          afterId: 'k1',
          beforeId: 'k2',
        ),
        'op.column.create',
        {'column_id': 'k9', 'title': 'QA', 'after_id': 'k1', 'before_id': 'k2'},
      );
    });

    test('op.column.rename', () {
      expectOp(
        const RenameColumn(opId: 'op-7', columnId: 'k1', title: 'Doing'),
        'op.column.rename',
        {'column_id': 'k1', 'title': 'Doing'},
      );
    });

    test('op.column.move without and with anchors', () {
      expectOp(
        const MoveColumn(opId: 'op-8', columnId: 'k1', baseVersion: 2),
        'op.column.move',
        {'column_id': 'k1', 'base_version': 2},
      );
      expectOp(
        const MoveColumn(
          opId: 'op-8',
          columnId: 'k1',
          baseVersion: 2,
          afterId: 'k2',
        ),
        'op.column.move',
        {'column_id': 'k1', 'after_id': 'k2', 'base_version': 2},
      );
    });

    test('op.column.archive', () {
      expectOp(
        const ArchiveColumn(opId: 'op-9', columnId: 'k1'),
        'op.column.archive',
        {'column_id': 'k1'},
      );
    });

    test('the op_id is the original one for every operation type', () {
      const ops = <BoardOp>[
        CreateCard(
          opId: 'x1',
          cardId: 'c',
          columnId: 'k',
          title: 't',
          actorId: 'u',
        ),
        EditCardTitle(opId: 'x2', cardId: 'c', title: 't', actorId: 'u'),
        EditCardDescription(
          opId: 'x3',
          cardId: 'c',
          description: 'd',
          baseDescriptionVersion: 1,
          actorId: 'u',
        ),
        MoveCard(opId: 'x4', cardId: 'c', toColumnId: 'k', baseVersion: 1),
        ArchiveCard(opId: 'x5', cardId: 'c'),
        CreateColumn(opId: 'x6', columnId: 'k', title: 't'),
        RenameColumn(opId: 'x7', columnId: 'k', title: 't'),
        MoveColumn(opId: 'x8', columnId: 'k', baseVersion: 1),
        ArchiveColumn(opId: 'x9', columnId: 'k'),
      ];

      expect(ops.map((op) => parse(encodeOp(op))['op_id']).toList(), [
        'x1',
        'x2',
        'x3',
        'x4',
        'x5',
        'x6',
        'x7',
        'x8',
        'x9',
      ]);
    });

    test('the strict fake server decodes every encoded operation back', () {
      const ops = <BoardOp>[
        CreateCard(
          opId: 'x1',
          cardId: 'c',
          columnId: 'k',
          title: 't',
          description: 'd',
          actorId: 'u',
          afterId: 'a',
          beforeId: 'b',
        ),
        EditCardTitle(opId: 'x2', cardId: 'c', title: 't', actorId: 'u'),
        EditCardDescription(
          opId: 'x3',
          cardId: 'c',
          description: 'd',
          baseDescriptionVersion: 3,
          actorId: 'u',
        ),
        MoveCard(
          opId: 'x4',
          cardId: 'c',
          toColumnId: 'k',
          baseVersion: 5,
          afterId: 'a',
        ),
        ArchiveCard(opId: 'x5', cardId: 'c'),
        CreateColumn(opId: 'x6', columnId: 'k', title: 't', beforeId: 'b'),
        RenameColumn(opId: 'x7', columnId: 'k', title: 't'),
        MoveColumn(opId: 'x8', columnId: 'k', baseVersion: 4, afterId: 'a'),
        ArchiveColumn(opId: 'x9', columnId: 'k'),
      ];

      for (final op in ops) {
        final message = parse(encodeOp(op));
        final back = decodeClientOp(
          message['type'] as String,
          message['op_id'] as String,
          message['payload'] as Map<String, dynamic>,
          actorId: 'u',
        );
        expect(back, op, reason: op.toString());
      }
    });
  });

  group('utf8Length', () {
    test('counts bytes, not code units', () {
      expect(utf8Length('abc'), 3);
      expect(utf8Length('привет'), 12);
      expect(utf8Length('€'), 3);
      expect(utf8Length('😀'), 4);
      expect(utf8Length(''), 0);
    });
  });

  group('decode of server messages', () {
    test('sync.ready decodes with an empty or missing payload', () {
      expect(decoded(wire('sync.ready')), isA<SyncReadyMessage>());
      expect(
        decoded(wire('sync.ready', payload: null)),
        isA<SyncReadyMessage>(),
      );
    });

    test('sync.delta decodes the events in order', () {
      final first = renamed(5, opId: 'a');
      final second = cardMoved(6, 'c1', 'k1', 'k2', 'Q');
      final message = decoded(
        wire(
          'sync.delta',
          payload: <String, Object?>{
            'events': <Object?>[
              encodeEventEnvelope(first),
              encodeEventEnvelope(second),
            ],
          },
        ),
      );

      expect(message, isA<SyncDeltaMessage>());
      expect((message as SyncDeltaMessage).events, <BoardEvent>[first, second]);
    });

    test('sync.delta with no events is a valid empty delta', () {
      final message = decoded(
        wire('sync.delta', payload: <String, Object?>{'events': <Object?>[]}),
      );

      expect((message as SyncDeltaMessage).events, isEmpty);
    });

    test('sync.delta without the events array is an invalid payload', () {
      final issue = issueOf(wire('sync.delta'));

      expect(issue, isA<InvalidPayload>());
      expect((issue as InvalidPayload).type, 'sync.delta');
    });

    test('sync.delta skips one broken event and keeps the others', () {
      final broken = encodeEventEnvelope(renamed(5))..remove('server_ts');
      final message = decoded(
        wire(
          'sync.delta',
          payload: <String, Object?>{
            'events': <Object?>[
              encodeEventEnvelope(renamed(4)),
              broken,
              encodeEventEnvelope(renamed(6)),
            ],
          },
        ),
      );

      final delta = message as SyncDeltaMessage;
      expect(delta.events.map((event) => event.seq), [4, 6]);
      expect(delta.skipped.single, isA<InvalidPayload>());
    });

    test('sync.snapshot decodes the board, columns, cards and members', () {
      final message = decoded(
        wire('sync.snapshot', payload: snapshotPayload(seq: 77)),
      );

      final board = (message as SyncSnapshotMessage).board;
      expect(board.model.seq, 77);
      expect(board.model.id, 'b1');
      expect(board.model.title, 'Launch');
      expect(board.model.columns.map((c) => c.id), ['k1', 'k2']);
      expect(board.model.cards.single.descriptionVersion, 2);
      expect(board.model.cards.single.version, 3);
      expect(board.model.members.single.role, BoardRole.owner);
      expect(board.info.role, BoardRole.editor);
    });

    test('sync.snapshot missing seq is an invalid payload', () {
      final payload = snapshotPayload()..remove('seq');

      expect(
        issueOf(wire('sync.snapshot', payload: payload)),
        isA<InvalidPayload>(),
      );
    });

    test('presence.list decodes users', () {
      final message = decoded(
        wire(
          'presence.list',
          payload: <String, Object?>{
            'users': <Object?>[
              <String, Object?>{
                'id': 'u1',
                'name': 'One',
                'avatar_color': '#111111',
              },
              <String, Object?>{
                'id': 'u2',
                'name': 'Two',
                'avatar_color': '#222222',
              },
            ],
          },
        ),
      );

      expect((message as PresenceListMessage).users, const <PresenceUser>[
        PresenceUser(userId: 'u1', name: 'One', avatarColor: '#111111'),
        PresenceUser(userId: 'u2', name: 'Two', avatarColor: '#222222'),
      ]);
    });

    test('presence.list may be empty', () {
      final message = decoded(
        wire('presence.list', payload: <String, Object?>{'users': <Object?>[]}),
      );

      expect((message as PresenceListMessage).users, isEmpty);
    });

    test('presence.join decodes the nested user', () {
      final message = decoded(
        wire(
          'presence.join',
          payload: <String, Object?>{
            'user': <String, Object?>{
              'id': 'u3',
              'name': 'Three',
              'avatar_color': '#333333',
            },
          },
        ),
      );

      expect(
        (message as PresenceJoinMessage).user,
        const PresenceUser(userId: 'u3', name: 'Three', avatarColor: '#333333'),
      );
    });

    test('presence.join without a user is an invalid payload', () {
      expect(issueOf(wire('presence.join')), isA<InvalidPayload>());
    });

    test('presence.leave decodes the user id', () {
      final message = decoded(
        wire('presence.leave', payload: <String, Object?>{'user_id': 'u3'}),
      );

      expect((message as PresenceLeaveMessage).userId, 'u3');
    });

    test('presence.leave with an empty id is an invalid payload', () {
      expect(
        issueOf(wire('presence.leave', payload: {'user_id': ''})),
        isA<InvalidPayload>(),
      );
    });

    test('auth.refreshed decodes expires_at as UTC milliseconds', () {
      final message = decoded(
        wire(
          'auth.refreshed',
          payload: <String, Object?>{'expires_at': 1767225600000},
        ),
      );

      expect(
        (message as AuthRefreshedMessage).expiresAt,
        DateTime.utc(2026, 1, 1),
      );
    });

    test('auth.refreshed without expires_at is an invalid payload', () {
      expect(issueOf(wire('auth.refreshed')), isA<InvalidPayload>());
    });

    test('error decodes code and message', () {
      final message = decoded(
        wire(
          'error',
          payload: <String, Object?>{'code': 'invalid_token', 'message': 'bad'},
        ),
      );

      expect((message as ErrorMessage).code, 'invalid_token');
      expect(message.message, 'bad');
    });

    test('error tolerates missing fields', () {
      final message = decoded(wire('error'));

      expect((message as ErrorMessage).code, '');
      expect(message.message, '');
    });
  });

  group('nack', () {
    const reasons = <String, NackReason>{
      'version_conflict': NackReason.versionConflict,
      'not_found': NackReason.notFound,
      'forbidden': NackReason.forbidden,
      'validation_error': NackReason.validationError,
      'rate_limited': NackReason.rateLimited,
      'resync_required': NackReason.resyncRequired,
      'internal': NackReason.internal,
    };

    reasons.forEach((wireName, reason) {
      test('$wireName maps to ${reason.name}', () {
        final message = decoded(
          wire(
            'nack',
            opId: 'op-1',
            payload: <String, Object?>{
              'reason': wireName,
              'at_seq': 12,
              'message': 'text',
            },
          ),
        );

        final nack = message as NackMessage;
        expect(nack.opId, 'op-1');
        expect(nack.reason, reason);
        expect(nack.atSeq, 12);
        expect(nack.message, 'text');
        expect(nackReasonToWire(reason), wireName);
        expect(nackReasonFromWire(wireName), reason);
      });
    });

    test('an unknown reason degrades to internal', () {
      final nack = decoded(
        wire(
          'nack',
          opId: 'op-1',
          payload: <String, Object?>{'reason': 'brand_new'},
        ),
      ) as NackMessage;

      expect(nack.reason, NackReason.internal);
      expect(nackReasonFromWire(null), NackReason.internal);
    });

    test('a missing at_seq becomes zero and a missing message is empty', () {
      final nack = decoded(
        wire(
          'nack',
          opId: 'op-1',
          payload: <String, Object?>{'reason': 'forbidden'},
        ),
      ) as NackMessage;

      expect(nack.atSeq, 0);
      expect(nack.message, '');
    });

    test('a nack without op_id still decodes with a null op id', () {
      final nack = decoded(
        wire('nack', payload: <String, Object?>{'reason': 'forbidden'}),
      ) as NackMessage;

      expect(nack.opId, isNull);
    });
  });

  group('event envelopes', () {
    test('every one of the 15 event types survives encode and decode', () {
      final events = oneOfEachEvent();

      for (final event in events) {
        final text = jsonEncode(encodeEventEnvelope(event));
        final message = decoded(text);
        expect(message, isA<EventMessage>(), reason: event.type);
        expect((message as EventMessage).event, event, reason: event.type);
      }
      expect(events.map((e) => e.type).toSet(), knownEventTypes);
    });

    test('the event keeps seq, op_id and server_ts of the envelope', () {
      final event = decoded(
        wire(
          'board.renamed',
          seq: 9,
          opId: 'op-x',
          serverTs: 1767225600000,
          payload: <String, Object?>{'title': 'T', 'actor_id': 'u1'},
        ),
      ) as EventMessage;

      expect(event.event.seq, 9);
      expect(event.event.opId, 'op-x');
      expect(event.event.serverTs, DateTime.utc(2026, 1, 1));
      expect(event.event.actorId, 'u1');
    });

    test('an event without op_id has a null opId', () {
      final event = decoded(
        wire(
          'board.renamed',
          seq: 9,
          serverTs: 1,
          payload: <String, Object?>{'title': 'T', 'actor_id': 'u1'},
        ),
      ) as EventMessage;

      expect(event.event.opId, isNull);
    });

    test('card.edited with title only leaves description null', () {
      final event = decoded(
        wire(
          'card.edited',
          seq: 3,
          serverTs: 1,
          payload: <String, Object?>{
            'card_id': 'c1',
            'title': 'T',
            'version': 2,
            'description_version': 1,
            'actor_id': 'u1',
          },
        ),
      ) as EventMessage;

      final edited = event.event as CardEditedEvent;
      expect(edited.title, 'T');
      expect(edited.description, isNull);
    });

    test('an event with a missing actor_id is an invalid payload', () {
      final issue = issueOf(
        wire(
          'board.renamed',
          seq: 3,
          serverTs: 1,
          payload: <String, Object?>{'title': 'T'},
        ),
      );

      expect(issue, isA<InvalidPayload>());
    });

    test('an event with an unknown role is an invalid payload', () {
      final issue = issueOf(
        wire(
          'member.added',
          seq: 3,
          serverTs: 1,
          payload: <String, Object?>{
            'user_id': 'u3',
            'display_name': 'N',
            'avatar_color': '#111111',
            'role': 'emperor',
            'actor_id': 'u1',
          },
        ),
      );

      expect(issue, isA<InvalidPayload>());
    });

    test('an event with a missing server_ts is an invalid payload', () {
      final issue = issueOf(
        wire(
          'board.renamed',
          seq: 3,
          payload: <String, Object?>{'title': 'T', 'actor_id': 'u1'},
        ),
      );

      expect(issue, isA<InvalidPayload>());
    });

    test('a card.moved without a rank is an invalid payload', () {
      final issue = issueOf(
        wire(
          'card.moved',
          seq: 3,
          serverTs: 1,
          payload: <String, Object?>{
            'card_id': 'c1',
            'from_column_id': 'a',
            'to_column_id': 'b',
            'version': 2,
            'actor_id': 'u1',
          },
        ),
      );

      expect(issue, isA<InvalidPayload>());
      expect((issue as InvalidPayload).type, 'card.moved');
    });

    test('a future event type with a seq decodes as UnknownBoardEvent', () {
      final message = decoded(
        wire('card.teleported', seq: 8, serverTs: 1, opId: 'o'),
      );

      final event = (message as EventMessage).event;
      expect(event, isA<UnknownBoardEvent>());
      expect(event.seq, 8);
      expect(event.opId, 'o');
      expect((event as UnknownBoardEvent).unknownType, 'card.teleported');
    });
  });

  group('protocol issues instead of exceptions', () {
    test('an unknown message type without seq is UnknownMessageType', () {
      expect(issueOf(wire('mystery')), const UnknownMessageType('mystery'));
    });

    test('an unknown type with a zero seq is still unknown', () {
      expect(
        issueOf(wire('mystery', seq: 0, serverTs: 1)),
        const UnknownMessageType('mystery'),
      );
    });

    test('v of 2 is UnsupportedVersion', () {
      expect(issueOf(wire('sync.ready', v: 2)), const UnsupportedVersion(2));
    });

    test('v of 0 and a negative v are UnsupportedVersion', () {
      expect(issueOf(wire('sync.ready', v: 0)), const UnsupportedVersion(0));
      expect(issueOf(wire('sync.ready', v: -1)), const UnsupportedVersion(-1));
    });

    test('a string v is UnsupportedVersion', () {
      expect(
        issueOf(wire('sync.ready', v: '1')),
        const UnsupportedVersion('1'),
      );
    });

    test('a missing v is UnsupportedVersion with null', () {
      expect(
        issueOf(wire('sync.ready', v: null)),
        const UnsupportedVersion(null),
      );
    });

    test('broken JSON is MalformedMessage', () {
      expect(issueOf('{"v":1,"type":'), isA<MalformedMessage>());
      expect(issueOf('not json'), isA<MalformedMessage>());
      expect(issueOf(''), isA<MalformedMessage>());
    });

    test('a JSON array, string, number or null is MalformedMessage', () {
      for (final text in ['[1,2]', '"x"', '42', 'null', 'true']) {
        expect(issueOf(text), isA<MalformedMessage>(), reason: text);
      }
    });

    test('a missing or empty type is MalformedMessage', () {
      expect(issueOf('{"v":1}'), const MalformedMessage('missing type'));
      expect(
        issueOf('{"v":1,"type":""}'),
        const MalformedMessage('missing type'),
      );
      expect(
        issueOf('{"v":1,"type":5}'),
        const MalformedMessage('missing type'),
      );
    });

    test('a non-object payload is treated as empty', () {
      expect(
        decoded('{"v":1,"type":"sync.ready","payload":[1]}'),
        isA<SyncReadyMessage>(),
      );
      expect(
        issueOf('{"v":1,"type":"sync.delta","payload":"x"}'),
        isA<InvalidPayload>(),
      );
    });

    test('truncating a valid message at every length never throws', () {
      final full = wire('sync.snapshot', payload: snapshotPayload());

      for (var length = 0; length < full.length; length += 7) {
        final result = decodeServerMessage(full.substring(0, length));
        expect(result, isA<Failure<ServerMessage, ProtocolIssue>>());
      }
    });

    test('random garbage and mutated messages never throw', () {
      final random = math.Random(2026);
      final samples = <String>[
        wire('sync.snapshot', payload: snapshotPayload()),
        wire(
          'sync.delta',
          payload: <String, Object?>{
            'events': <Object?>[encodeEventEnvelope(renamed(1))],
          },
        ),
        wire('nack', opId: 'o', payload: {'reason': 'forbidden'}),
        wire('auth.refreshed', payload: {'expires_at': 1}),
      ];
      for (var i = 0; i < 400; i++) {
        final base = samples[random.nextInt(samples.length)];
        final codes = base.codeUnits.toList();
        for (var j = 0; j < 1 + random.nextInt(4); j++) {
          codes[random.nextInt(codes.length)] = 32 + random.nextInt(95);
        }
        expect(
          () => decodeServerMessage(String.fromCharCodes(codes)),
          returnsNormally,
        );
      }
      for (var i = 0; i < 200; i++) {
        final junk = String.fromCharCodes(
          List<int>.generate(random.nextInt(60), (_) => random.nextInt(0x2FF)),
        );
        expect(() => decodeServerMessage(junk), returnsNormally);
      }
    });

    test('type mismatches inside a payload are InvalidPayload', () {
      expect(
        issueOf(wire('auth.refreshed', payload: {'expires_at': 'soon'})),
        isA<InvalidPayload>(),
      );
      expect(
        issueOf(wire('presence.list', payload: {'users': 'many'})),
        isA<InvalidPayload>(),
      );
      expect(
        issueOf(
          wire(
            'presence.list',
            payload: {
              'users': [1],
            },
          ),
        ),
        isA<InvalidPayload>(),
      );
    });
  });
}
