import 'dart:convert';

import '../../../../core/network/json_fields.dart';
import '../../../../core/realtime/realtime_policy.dart';
import '../../../../core/result/result.dart';
import '../../../boards/data/boards_dto.dart';
import '../../../boards/domain/board_info.dart';
import '../../domain/board_event.dart';
import '../../domain/board_op.dart';
import '../../domain/board_session.dart';
import '../../domain/board_sync_state.dart';
import 'event_codec.dart';
import 'protocol_issue.dart';

sealed class ServerMessage {
  const ServerMessage();
}

final class SyncDeltaMessage extends ServerMessage {
  const SyncDeltaMessage(this.events, {this.skipped = const <ProtocolIssue>[]});

  final List<BoardEvent> events;
  final List<ProtocolIssue> skipped;
}

final class SyncSnapshotMessage extends ServerMessage {
  const SyncSnapshotMessage(this.board);

  final ServerBoard board;
}

final class SyncReadyMessage extends ServerMessage {
  const SyncReadyMessage();
}

final class PresenceListMessage extends ServerMessage {
  const PresenceListMessage(this.users);

  final List<PresenceUser> users;
}

final class PresenceJoinMessage extends ServerMessage {
  const PresenceJoinMessage(this.user);

  final PresenceUser user;
}

final class PresenceLeaveMessage extends ServerMessage {
  const PresenceLeaveMessage(this.userId);

  final String userId;
}

final class AuthRefreshedMessage extends ServerMessage {
  const AuthRefreshedMessage(this.expiresAt);

  final DateTime expiresAt;
}

final class NackMessage extends ServerMessage {
  const NackMessage({
    required this.opId,
    required this.reason,
    required this.atSeq,
    required this.message,
  });

  final String? opId;
  final NackReason reason;
  final int atSeq;
  final String message;
}

final class ErrorMessage extends ServerMessage {
  const ErrorMessage({required this.code, required this.message});

  final String code;
  final String message;
}

final class EventMessage extends ServerMessage {
  const EventMessage(this.event);

  final BoardEvent event;
}

abstract final class MessageTypes {
  static const String hello = 'hello';
  static const String authRefresh = 'auth.refresh';
  static const String authRefreshed = 'auth.refreshed';
  static const String syncDelta = 'sync.delta';
  static const String syncSnapshot = 'sync.snapshot';
  static const String syncReady = 'sync.ready';
  static const String presenceList = 'presence.list';
  static const String presenceJoin = 'presence.join';
  static const String presenceLeave = 'presence.leave';
  static const String nack = 'nack';
  static const String error = 'error';
  static const String opCardCreate = 'op.card.create';
  static const String opCardEdit = 'op.card.edit';
  static const String opCardMove = 'op.card.move';
  static const String opCardArchive = 'op.card.archive';
  static const String opColumnCreate = 'op.column.create';
  static const String opColumnRename = 'op.column.rename';
  static const String opColumnMove = 'op.column.move';
  static const String opColumnArchive = 'op.column.archive';
}

NackReason nackReasonFromWire(String? value) {
  return switch (value) {
    'version_conflict' => NackReason.versionConflict,
    'not_found' => NackReason.notFound,
    'forbidden' => NackReason.forbidden,
    'validation_error' => NackReason.validationError,
    'rate_limited' => NackReason.rateLimited,
    'resync_required' => NackReason.resyncRequired,
    _ => NackReason.internal,
  };
}

String nackReasonToWire(NackReason reason) {
  return switch (reason) {
    NackReason.versionConflict => 'version_conflict',
    NackReason.notFound => 'not_found',
    NackReason.forbidden => 'forbidden',
    NackReason.validationError => 'validation_error',
    NackReason.rateLimited => 'rate_limited',
    NackReason.resyncRequired => 'resync_required',
    NackReason.internal => 'internal',
  };
}

PresenceUser _presenceUser(Map<String, dynamic> json) {
  return PresenceUser(
    userId: readNonEmptyString(json, 'id'),
    name: readString(json, 'name'),
    avatarColor: readString(json, 'avatar_color'),
  );
}

Map<String, dynamic>? _decodeJsonObject(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

Result<ServerMessage, ProtocolIssue> decodeServerMessage(String text) {
  final envelope = _decodeJsonObject(text);
  if (envelope == null) {
    return const Failure<ServerMessage, ProtocolIssue>(
      MalformedMessage('not a JSON object'),
    );
  }
  if (envelope['v'] != RealtimePolicy.protocolVersion) {
    return Failure<ServerMessage, ProtocolIssue>(
      UnsupportedVersion(envelope['v']),
    );
  }
  final type = envelope['type'];
  if (type is! String || type.isEmpty) {
    return const Failure<ServerMessage, ProtocolIssue>(
      MalformedMessage('missing type'),
    );
  }
  final rawPayload = envelope['payload'];
  final payload = rawPayload is Map<String, dynamic>
      ? rawPayload
      : const <String, dynamic>{};
  try {
    final message = _decodeTyped(type, envelope, payload);
    if (message == null) {
      return Failure<ServerMessage, ProtocolIssue>(UnknownMessageType(type));
    }
    return Success<ServerMessage, ProtocolIssue>(message);
  } on FormatException catch (error) {
    return Failure<ServerMessage, ProtocolIssue>(
      InvalidPayload(type, error.message),
    );
  }
}

ServerMessage? _decodeTyped(
  String type,
  Map<String, dynamic> envelope,
  Map<String, dynamic> payload,
) {
  switch (type) {
    case MessageTypes.syncDelta:
      final events = <BoardEvent>[];
      final skipped = <ProtocolIssue>[];
      for (final item in readObjectList(payload, 'events')) {
        try {
          events.add(decodeEvent(item));
        } on FormatException catch (error) {
          final kind = item['type'];
          skipped.add(
            InvalidPayload(kind is String ? kind : 'event', error.message),
          );
        }
      }
      return SyncDeltaMessage(events, skipped: skipped);
    case MessageTypes.syncSnapshot:
      return SyncSnapshotMessage(serverBoardFromJson(payload));
    case MessageTypes.syncReady:
      return const SyncReadyMessage();
    case MessageTypes.presenceList:
      return PresenceListMessage(<PresenceUser>[
        for (final item in readObjectList(payload, 'users'))
          _presenceUser(item),
      ]);
    case MessageTypes.presenceJoin:
      return PresenceJoinMessage(
        _presenceUser(asJsonMap(payload['user'], 'user')),
      );
    case MessageTypes.presenceLeave:
      return PresenceLeaveMessage(readNonEmptyString(payload, 'user_id'));
    case MessageTypes.authRefreshed:
      return AuthRefreshedMessage(
        DateTime.fromMillisecondsSinceEpoch(
          readInt(payload, 'expires_at'),
          isUtc: true,
        ),
      );
    case MessageTypes.nack:
      return NackMessage(
        opId: readOptionalString(envelope, 'op_id'),
        reason: nackReasonFromWire(readOptionalString(payload, 'reason')),
        atSeq: readOptionalInt(payload, 'at_seq') ?? 0,
        message: readOptionalString(payload, 'message') ?? '',
      );
    case MessageTypes.error:
      return ErrorMessage(
        code: readOptionalString(payload, 'code') ?? '',
        message: readOptionalString(payload, 'message') ?? '',
      );
  }
  if (envelope['seq'] is int && (envelope['seq'] as int) > 0) {
    return EventMessage(decodeEvent(envelope));
  }
  return null;
}

String _envelope(String type, {String? opId, Map<String, Object?>? payload}) {
  return jsonEncode(<String, Object?>{
    'v': RealtimePolicy.protocolVersion,
    'type': type,
    'op_id': ?opId,
    'payload': ?payload,
  });
}

String encodeHello({required int? lastSeq, required String client}) {
  return _envelope(
    MessageTypes.hello,
    payload: <String, Object?>{'last_seq': lastSeq, 'client': client},
  );
}

String encodeAuthRefresh(String accessToken) {
  return _envelope(
    MessageTypes.authRefresh,
    payload: <String, Object?>{'access_token': accessToken},
  );
}

String encodeOp(BoardOp op) {
  final (type, payload) = switch (op) {
    CreateCard() => (
      MessageTypes.opCardCreate,
      <String, Object?>{
        'card_id': op.cardId,
        'column_id': op.columnId,
        'title': op.title,
        if (op.description.isNotEmpty) 'description': op.description,
        'after_id': ?op.afterId,
        'before_id': ?op.beforeId,
      },
    ),
    EditCardTitle() => (
      MessageTypes.opCardEdit,
      <String, Object?>{'card_id': op.cardId, 'title': op.title},
    ),
    EditCardDescription() => (
      MessageTypes.opCardEdit,
      <String, Object?>{
        'card_id': op.cardId,
        'description': op.description,
        'base_description_version': op.baseDescriptionVersion,
      },
    ),
    MoveCard() => (
      MessageTypes.opCardMove,
      <String, Object?>{
        'card_id': op.cardId,
        'to_column_id': op.toColumnId,
        'after_id': ?op.afterId,
        'before_id': ?op.beforeId,
        'base_version': op.baseVersion,
      },
    ),
    ArchiveCard() => (
      MessageTypes.opCardArchive,
      <String, Object?>{'card_id': op.cardId},
    ),
    CreateColumn() => (
      MessageTypes.opColumnCreate,
      <String, Object?>{
        'column_id': op.columnId,
        'title': op.title,
        'after_id': ?op.afterId,
        'before_id': ?op.beforeId,
      },
    ),
    RenameColumn() => (
      MessageTypes.opColumnRename,
      <String, Object?>{'column_id': op.columnId, 'title': op.title},
    ),
    MoveColumn() => (
      MessageTypes.opColumnMove,
      <String, Object?>{
        'column_id': op.columnId,
        'after_id': ?op.afterId,
        'before_id': ?op.beforeId,
        'base_version': op.baseVersion,
      },
    ),
    ArchiveColumn() => (
      MessageTypes.opColumnArchive,
      <String, Object?>{'column_id': op.columnId},
    ),
  };
  return _envelope(type, opId: op.opId, payload: payload);
}

int utf8Length(String text) => utf8.encode(text).length;
