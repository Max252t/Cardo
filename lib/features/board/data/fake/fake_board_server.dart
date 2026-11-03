import 'dart:async';
import 'dart:convert';

import '../../../../core/models/board_role.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/realtime/realtime_policy.dart';
import '../../../../core/realtime/scheduler.dart';
import '../../../../core/result/result.dart';
import '../../../boards/domain/board_info.dart';
import '../../domain/apply_event.dart';
import '../../domain/board_event.dart';
import '../../domain/board_model.dart';
import '../../domain/board_op.dart';
import '../../domain/board_session.dart';
import '../../domain/board_sync_state.dart';
import '../realtime/board_catch_up.dart';
import '../realtime/event_codec.dart';
import '../realtime/message_codec.dart';
import '../realtime/realtime_transport.dart';
import 'server_ops.dart';

typedef RejectPolicy = OpRejection? Function(BoardOp op);

class FakeConnectionRefused implements Exception {
  const FakeConnectionRefused();

  @override
  String toString() => 'FakeConnectionRefused';
}

class FakeSocket implements RealtimeChannel {
  FakeSocket(this._server, this.headers);

  final FakeBoardServer _server;
  final Map<String, String> headers;
  final StreamController<String> _incoming = StreamController<String>();
  int? _code;
  String? _reason;
  bool _closed = false;
  bool helloReceived = false;
  bool ready = false;
  bool joining = false;
  final List<BoardEvent> backlog = <BoardEvent>[];
  int tokens = RealtimePolicy.serverOpBurst;
  int strikes = 0;
  Timer? refillTimer;
  final List<Timer> strikeTimers = <Timer>[];

  void _cancelTimers() {
    refillTimer?.cancel();
    refillTimer = null;
    for (final timer in strikeTimers) {
      timer.cancel();
    }
    strikeTimers.clear();
  }

  bool get isClosed => _closed;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  int? get closeCode => _code;

  @override
  String? get closeReason => _reason;

  @override
  void send(String text) {
    if (_closed) {
      throw StateError('socket is closed');
    }
    _server._receive(this, text);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) {
      return;
    }
    _closed = true;
    _code = code;
    _reason = reason;
    _cancelTimers();
    _server._detach(this);
    unawaited(_incoming.close());
  }

  void deliver(String text) {
    if (!_closed) {
      _incoming.add(text);
    }
  }

  void terminate(int? code, String? reason) {
    if (_closed) {
      return;
    }
    _closed = true;
    _code = code;
    _reason = reason;
    _cancelTimers();
    _server._detach(this);
    unawaited(_incoming.close());
  }
}

class FakeBoardServer implements RealtimeTransport, BoardCatchUpSource {
  FakeBoardServer({
    required BoardModel initial,
    required this.currentUserId,
    this.latency = Duration.zero,
    this.scheduler = const SystemScheduler(),
    DateTime Function()? now,
    this.rejectWhen,
    this.announceConflicts = true,
    this.enforceRateLimit = true,
    List<PresenceUser> online = const <PresenceUser>[],
    this.pageSize = 1000,
    this.handshakeDelay = Duration.zero,
  }) : _board = initial,
       _logStart = initial.seq + 1,
       _now = now ?? DateTime.now,
       _online = List<PresenceUser>.of(online);

  final String currentUserId;
  final Duration latency;
  final Scheduler scheduler;
  RejectPolicy? rejectWhen;
  bool announceConflicts;
  bool enforceRateLimit;
  int pageSize;
  Duration handshakeDelay;
  final DateTime Function() _now;

  BoardModel _board;
  int _logStart;
  final List<BoardEvent> _log = <BoardEvent>[];
  final List<BoardEvent> _held = <BoardEvent>[];
  final Map<String, Object> _processed = <String, Object>{};
  final List<FakeSocket> _sockets = <FakeSocket>[];
  final List<PresenceUser> _online;
  int _refusals = 0;
  int? _upgradeStatus;
  int _suppress = 0;
  int _eventFetchFailures = 0;
  bool _refuseAll = false;
  bool Function(String token)? acceptToken;

  final List<String> connectTokens = <String>[];
  final List<String> receivedTypes = <String>[];
  final List<BoardOp> receivedOps = <BoardOp>[];
  final List<String> receivedRefreshTokens = <String>[];
  final List<int?> receivedHelloSeqs = <int?>[];
  int connectAttempts = 0;
  int rateLimitedOps = 0;
  int snapshotLoads = 0;
  int eventFetches = 0;
  int deltasSent = 0;
  int snapshotsSent = 0;
  int backlogDelivered = 0;

  BoardModel get board => _board;

  int get seq => _board.seq;

  List<BoardEvent> get log => List<BoardEvent>.unmodifiable(_log);

  List<FakeSocket> get sockets => List<FakeSocket>.unmodifiable(_sockets);

  int get openConnections => _sockets.length;

  List<PresenceUser> get online => List<PresenceUser>.unmodifiable(_online);

  BoardRole get currentRole =>
      _board.memberById(currentUserId)?.role ?? BoardRole.viewer;

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    connectAttempts++;
    final auth = headers['Authorization'] ?? '';
    connectTokens.add(
      auth.startsWith('Bearer ') ? auth.substring('Bearer '.length) : auth,
    );
    final status = _upgradeStatus;
    if (status != null) {
      throw RealtimeUpgradeRejected(status);
    }
    if (_refuseAll || _refusals > 0) {
      if (_refusals > 0) {
        _refusals--;
      }
      throw const FakeConnectionRefused();
    }
    final socket = FakeSocket(this, headers);
    _sockets.add(socket);
    return socket;
  }

  @override
  Future<Result<EventsPage, ApiFailure>> getEvents(
    String boardId,
    int afterSeq,
  ) async {
    eventFetches++;
    if (_eventFetchFailures > 0) {
      _eventFetchFailures--;
      return const Failure<EventsPage, ApiFailure>(
        NetworkFailure(NetworkFailureKind.offline),
      );
    }
    if (afterSeq + 1 < _logStart) {
      return const Failure<EventsPage, ApiFailure>(GoneFailure());
    }
    final after = _published(afterSeq);
    final page = after.take(pageSize).toList();
    return Success<EventsPage, ApiFailure>(
      EventsPage(
        events: page,
        seq: _board.seq,
        hasMore: after.length > page.length,
      ),
    );
  }

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId) async {
    snapshotLoads++;
    return Success<ServerBoard, ApiFailure>(_serverBoard());
  }

  ServerBoard _serverBoard() {
    final now = _now().toUtc();
    final active = _board.copyWith(
      cards: <CardModel>[
        for (final card in _board.cards)
          if (!card.archived) card,
      ],
    );
    return ServerBoard(
      info: BoardInfo(
        id: _board.id,
        title: _board.title,
        ownerId: _ownerId(),
        role: currentRole,
        createdAt: now,
        updatedAt: now,
        seq: _board.seq,
      ),
      model: active,
    );
  }

  String _ownerId() {
    for (final member in _board.members) {
      if (member.role == BoardRole.owner) {
        return member.userId;
      }
    }
    return currentUserId;
  }

  void failNextConnections(int count) => _refusals = count;

  void rejectUpgrades(int? status) => _upgradeStatus = status;

  void refuseConnections(bool value) => _refuseAll = value;

  void failNextEventFetches(int count) => _eventFetchFailures = count;

  void suppressNextBroadcasts(int count) => _suppress = count;

  void dropConnections() {
    for (final socket in List<FakeSocket>.of(_sockets)) {
      socket.terminate(null, null);
    }
  }

  void closeConnections(int code, [String? reason]) {
    for (final socket in List<FakeSocket>.of(_sockets)) {
      socket.terminate(code, reason);
    }
  }

  void expireTokens() => closeConnections(CloseCodes.tokenExpired);

  void pruneLog(int upToSeq) {
    _log.removeWhere((event) => event.seq <= upToSeq);
    if (upToSeq + 1 > _logStart) {
      _logStart = upToSeq + 1;
    }
  }

  void userJoined(PresenceUser user) {
    _online.removeWhere((other) => other.userId == user.userId);
    _online.add(user);
    _broadcastRaw(
      _json('presence.join', <String, Object?>{'user': _presenceJson(user)}),
    );
  }

  void userLeft(String userId) {
    _online.removeWhere((other) => other.userId == userId);
    _broadcastRaw(
      _json('presence.leave', <String, Object?>{'user_id': userId}),
    );
  }

  BoardEvent? commitRemote(
    BoardOp op, {
    required String actorId,
    bool deliver = true,
  }) {
    final verdict = judgeOp(
      _board,
      op,
      seq: _board.seq + 1,
      actorId: actorId,
      now: _now().toUtc(),
    );
    if (verdict is! OpAccepted) {
      return null;
    }
    final event = verdict.event;
    _commit(event, deliver: deliver);
    return event;
  }

  BoardEvent commitEvent(
    BoardEvent Function(int seq, DateTime ts) build, {
    bool deliver = true,
  }) {
    final event = build(_board.seq + 1, _now().toUtc());
    _commit(event, deliver: deliver);
    return event;
  }

  void renameBoard(String title, {String? actorId}) {
    commitEvent(
      (seq, ts) => BoardRenamedEvent(
        seq: seq,
        serverTs: ts,
        actorId: actorId ?? _ownerId(),
        title: title,
      ),
    );
  }

  void changeRole(String userId, BoardRole role) {
    commitEvent(
      (seq, ts) => MemberRoleChangedEvent(
        seq: seq,
        serverTs: ts,
        actorId: _ownerId(),
        userId: userId,
        role: role,
      ),
    );
  }

  void removeMember(String userId, {bool closeSocket = true}) {
    commitEvent(
      (seq, ts) => MemberRemovedEvent(
        seq: seq,
        serverTs: ts,
        actorId: _ownerId(),
        userId: userId,
      ),
    );
    if (closeSocket && userId == currentUserId) {
      closeConnections(CloseCodes.accessRevoked);
    }
  }

  void deleteBoard({bool closeSocket = true}) {
    commitEvent(
      (seq, ts) =>
          BoardDeletedEvent(seq: seq, serverTs: ts, actorId: _ownerId()),
    );
    if (closeSocket) {
      closeConnections(CloseCodes.boardDeleted);
    }
  }

  List<BoardEvent> _published(int afterSeq) {
    final ceiling = _held.isEmpty
        ? null
        : _held.map((event) => event.seq).reduce((a, b) => a < b ? a : b);
    return _log
        .where(
          (event) =>
              event.seq > afterSeq && (ceiling == null || event.seq < ceiling),
        )
        .toList();
  }

  void flushHeld() {
    final held = List<BoardEvent>.of(_held)
      ..sort((a, b) => a.seq.compareTo(b.seq));
    _held.clear();
    for (final event in held) {
      _broadcast(event);
    }
  }

  void _commit(BoardEvent event, {bool deliver = true}) {
    _board = applyEvent(_board, event);
    _log.add(event);
    if (!deliver) {
      _held.add(event);
      return;
    }
    if (_suppress > 0) {
      _suppress--;
      return;
    }
    _broadcast(event);
  }

  void _broadcast(BoardEvent event) {
    final text = jsonEncode(encodeEventEnvelope(event));
    for (final socket in List<FakeSocket>.of(_sockets)) {
      if (socket.ready) {
        socket.deliver(text);
      } else if (socket.joining) {
        socket.backlog.add(event);
      }
    }
  }

  void _broadcastRaw(String text) {
    for (final socket in List<FakeSocket>.of(_sockets)) {
      if (socket.ready) {
        socket.deliver(text);
      }
    }
  }

  void _detach(FakeSocket socket) => _sockets.remove(socket);

  String _json(String type, Map<String, Object?> payload, {String? opId}) {
    return jsonEncode(<String, Object?>{
      'v': RealtimePolicy.protocolVersion,
      'type': type,
      'op_id': ?opId,
      'payload': payload,
    });
  }

  Map<String, Object?> _presenceJson(PresenceUser user) => <String, Object?>{
    'id': user.userId,
    'name': user.name,
    'avatar_color': user.avatarColor,
  };

  void _error(FakeSocket socket, String code, String message) {
    socket.deliver(
      _json('error', <String, Object?>{'code': code, 'message': message}),
    );
  }

  void _receive(FakeSocket socket, String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _error(socket, 'protocol_error', 'malformed message');
      return;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['v'] != RealtimePolicy.protocolVersion ||
        decoded['type'] is! String) {
      _error(socket, 'protocol_error', 'invalid envelope');
      return;
    }
    final type = decoded['type'] as String;
    final extra = decoded.keys.toSet().difference(const <String>{
      'v',
      'type',
      'op_id',
      'payload',
    });
    if (extra.isNotEmpty) {
      _error(socket, 'protocol_error', 'unknown envelope fields');
      return;
    }
    receivedTypes.add(type);
    final payload = decoded['payload'] is Map<String, dynamic>
        ? decoded['payload'] as Map<String, dynamic>
        : const <String, dynamic>{};
    switch (type) {
      case 'hello':
        _hello(socket, payload);
      case 'auth.refresh':
        _refresh(socket, payload);
      default:
        _operation(socket, type, decoded['op_id'], payload);
    }
  }

  void _hello(FakeSocket socket, Map<String, dynamic> payload) {
    if (socket.helloReceived) {
      _error(socket, 'protocol_error', 'repeated hello');
      return;
    }
    socket.helloReceived = true;
    final lastSeq = payload['last_seq'];
    receivedHelloSeqs.add(lastSeq is int ? lastSeq : null);
    final retained =
        lastSeq is int &&
        lastSeq >= 0 &&
        lastSeq <= _board.seq &&
        lastSeq + 1 >= _logStart &&
        _board.seq - lastSeq <= 5000;
    if (retained) {
      final missing = _published(lastSeq);
      if (missing.isEmpty) {
        deltasSent++;
        socket.deliver(_json('sync.delta', <String, Object?>{'events': []}));
      }
      for (var i = 0; i < missing.length; i += 500) {
        deltasSent++;
        socket.deliver(
          _json('sync.delta', <String, Object?>{
            'events': <Object?>[
              for (final event in missing.skip(i).take(500))
                encodeEventEnvelope(event),
            ],
          }),
        );
      }
    } else {
      snapshotsSent++;
      socket.deliver(_json('sync.snapshot', _snapshotPayload()));
    }
    if (handshakeDelay == Duration.zero) {
      _finishHandshake(socket, 0);
      return;
    }
    final sentSeq = _board.seq;
    socket.joining = true;
    scheduler.after(handshakeDelay, () => _finishHandshake(socket, sentSeq));
  }

  void _finishHandshake(FakeSocket socket, int sentSeq) {
    if (socket.isClosed) {
      return;
    }
    socket.deliver(
      _json('presence.list', <String, Object?>{
        'users': <Object?>[for (final user in _online) _presenceJson(user)],
      }),
    );
    for (final event in socket.backlog) {
      if (event.seq > sentSeq) {
        backlogDelivered++;
        socket.deliver(jsonEncode(encodeEventEnvelope(event)));
      }
    }
    socket.backlog.clear();
    socket.joining = false;
    socket.deliver(_json('sync.ready', const <String, Object?>{}));
    socket.ready = true;
  }

  Map<String, Object?> _snapshotPayload() {
    final server = _serverBoard();
    final model = server.model;
    final now = _now().toUtc().toIso8601String();
    return <String, Object?>{
      'board': <String, Object?>{
        'id': model.id,
        'title': model.title,
        'owner_id': server.info.ownerId,
        'role': server.info.role.wireName,
        'created_at': now,
        'updated_at': now,
      },
      'columns': <Object?>[
        for (final column in model.columns)
          <String, Object?>{
            'id': column.id,
            'title': column.title,
            'rank': column.rank,
            'version': column.version,
          },
      ],
      'cards': <Object?>[
        for (final card in model.cards)
          encodeEventPayload(
            CardCreatedEvent(
              seq: 0,
              serverTs: card.createdAt,
              actorId: card.createdBy,
              card: card,
            ),
          )..remove('actor_id'),
      ],
      'members': <Object?>[
        for (final member in model.members)
          <String, Object?>{
            'user_id': member.userId,
            'display_name': member.name,
            'avatar_color': member.avatarColor,
            'role': member.role.wireName,
            'joined_at': now,
          },
      ],
      'seq': model.seq,
    };
  }

  void _refresh(FakeSocket socket, Map<String, dynamic> payload) {
    final token = payload['access_token'];
    if (token is! String || !(acceptToken?.call(token) ?? true)) {
      _error(socket, 'invalid_token', 'invalid access token');
      return;
    }
    receivedRefreshTokens.add(token);
    socket.deliver(
      _json('auth.refreshed', <String, Object?>{
        'expires_at': _now()
            .add(const Duration(minutes: 15))
            .millisecondsSinceEpoch,
      }),
    );
  }

  void _operation(
    FakeSocket socket,
    String type,
    Object? opId,
    Map<String, dynamic> payload,
  ) {
    if (opId is! String || opId.isEmpty) {
      _error(socket, 'protocol_error', 'missing op_id');
      return;
    }
    if (!socket.ready) {
      _error(socket, 'protocol_error', 'operation before sync.ready');
      return;
    }
    final op = decodeClientOp(type, opId, payload, actorId: currentUserId);
    if (op == null) {
      _error(socket, 'protocol_error', 'invalid operation');
      return;
    }
    if (!_admit(socket)) {
      rateLimitedOps++;
      _nack(
        socket,
        op.opId,
        OpRejection(reason: NackReason.rateLimited, atSeq: _board.seq),
      );
      return;
    }
    receivedOps.add(op);
    scheduler.after(latency, () => _process(socket, op));
  }

  bool _admit(FakeSocket socket) {
    if (!enforceRateLimit) {
      return true;
    }
    if (socket.tokens > 0) {
      socket.tokens--;
      _scheduleRefill(socket);
      return true;
    }
    socket.strikes++;
    socket.strikeTimers.add(
      scheduler.after(RealtimePolicy.serverStrikeWindow, () {
        if (socket.strikes > 0) {
          socket.strikes--;
        }
      }),
    );
    if (socket.strikes >= RealtimePolicy.serverStrikeLimit) {
      socket.terminate(CloseCodes.rateAbuse, 'rate limit abuse');
    }
    return false;
  }

  void _scheduleRefill(FakeSocket socket) {
    if (socket.refillTimer != null ||
        socket.tokens >= RealtimePolicy.serverOpBurst) {
      return;
    }
    socket.refillTimer = scheduler.after(RealtimePolicy.serverRefill, () {
      socket.refillTimer = null;
      if (socket.tokens < RealtimePolicy.serverOpBurst) {
        socket.tokens++;
      }
      _scheduleRefill(socket);
    });
  }

  void _process(FakeSocket socket, BoardOp op) {
    if (socket.isClosed) {
      return;
    }
    final forced = rejectWhen?.call(op);
    if (forced != null) {
      _nack(socket, op.opId, forced.withSeq(_board.seq));
      return;
    }
    final stored = _processed[op.opId];
    if (stored is BoardEvent) {
      socket.deliver(jsonEncode(encodeEventEnvelope(stored)));
      return;
    }
    if (stored is OpRejection) {
      _nack(socket, op.opId, stored);
      return;
    }
    final verdict = judgeOp(
      _board,
      op,
      seq: _board.seq + 1,
      actorId: currentUserId,
      now: _now().toUtc(),
      role: currentRole,
    );
    switch (verdict) {
      case OpRefused(:final reason, :final limit):
        if (announceConflicts && reason == NackReason.versionConflict) {
          flushHeld();
        }
        final rejection = OpRejection(
          reason: reason,
          atSeq: _board.seq,
          limit: limit,
        );
        _processed[op.opId] = rejection;
        _nack(socket, op.opId, rejection);
      case OpAccepted(:final event):
        _processed[op.opId] = event;
        _commit(event);
    }
  }

  void _nack(FakeSocket socket, String opId, OpRejection rejection) {
    socket.deliver(
      _json('nack', <String, Object?>{
        'reason': nackReasonToWire(rejection.reason),
        'at_seq': rejection.atSeq ?? _board.seq,
        'message': rejection.reason.name,
      }, opId: opId),
    );
  }

  void forgetProcessed(String opId) {
    _processed.remove(opId);
  }

  void resyncRequiredFor(String opId) {
    _processed[opId] = const OpRejection(reason: NackReason.resyncRequired);
  }
}

BoardOp? decodeClientOp(
  String type,
  String opId,
  Map<String, dynamic> payload, {
  required String actorId,
}) {
  bool only(Set<String> allowed, Set<String> required) {
    final keys = payload.keys.toSet();
    return keys.difference(allowed).isEmpty &&
        required.difference(keys).isEmpty;
  }

  String? text(String key) {
    final value = payload[key];
    return value is String ? value : null;
  }

  int? number(String key) {
    final value = payload[key];
    return value is int ? value : null;
  }

  switch (type) {
    case 'op.card.create':
      if (!only(
        const <String>{
          'card_id',
          'column_id',
          'title',
          'description',
          'after_id',
          'before_id',
        },
        const <String>{'card_id', 'column_id', 'title'},
      )) {
        return null;
      }
      return CreateCard(
        opId: opId,
        cardId: text('card_id') ?? '',
        columnId: text('column_id') ?? '',
        title: text('title') ?? '',
        description: text('description') ?? '',
        afterId: text('after_id'),
        beforeId: text('before_id'),
        actorId: actorId,
      );
    case 'op.card.edit':
      if (!only(
        const <String>{
          'card_id',
          'title',
          'description',
          'base_description_version',
        },
        const <String>{'card_id'},
      )) {
        return null;
      }
      final cardId = text('card_id') ?? '';
      if (payload.containsKey('description')) {
        final base = number('base_description_version');
        if (base == null) {
          return null;
        }
        return EditCardDescription(
          opId: opId,
          cardId: cardId,
          description: text('description') ?? '',
          baseDescriptionVersion: base,
          actorId: actorId,
        );
      }
      if (!payload.containsKey('title')) {
        return null;
      }
      return EditCardTitle(
        opId: opId,
        cardId: cardId,
        title: text('title') ?? '',
        actorId: actorId,
      );
    case 'op.card.move':
      if (!only(
        const <String>{
          'card_id',
          'to_column_id',
          'after_id',
          'before_id',
          'base_version',
        },
        const <String>{'card_id', 'to_column_id', 'base_version'},
      )) {
        return null;
      }
      return MoveCard(
        opId: opId,
        cardId: text('card_id') ?? '',
        toColumnId: text('to_column_id') ?? '',
        afterId: text('after_id'),
        beforeId: text('before_id'),
        baseVersion: number('base_version') ?? 0,
      );
    case 'op.card.archive':
      if (!only(const <String>{'card_id'}, const <String>{'card_id'})) {
        return null;
      }
      return ArchiveCard(opId: opId, cardId: text('card_id') ?? '');
    case 'op.column.create':
      if (!only(
        const <String>{'column_id', 'title', 'after_id', 'before_id'},
        const <String>{'column_id', 'title'},
      )) {
        return null;
      }
      return CreateColumn(
        opId: opId,
        columnId: text('column_id') ?? '',
        title: text('title') ?? '',
        afterId: text('after_id'),
        beforeId: text('before_id'),
      );
    case 'op.column.rename':
      if (!only(
        const <String>{'column_id', 'title'},
        const <String>{'column_id', 'title'},
      )) {
        return null;
      }
      return RenameColumn(
        opId: opId,
        columnId: text('column_id') ?? '',
        title: text('title') ?? '',
      );
    case 'op.column.move':
      if (!only(
        const <String>{'column_id', 'after_id', 'before_id', 'base_version'},
        const <String>{'column_id', 'base_version'},
      )) {
        return null;
      }
      return MoveColumn(
        opId: opId,
        columnId: text('column_id') ?? '',
        afterId: text('after_id'),
        beforeId: text('before_id'),
        baseVersion: number('base_version') ?? 0,
      );
    case 'op.column.archive':
      if (!only(const <String>{'column_id'}, const <String>{'column_id'})) {
        return null;
      }
      return ArchiveColumn(opId: opId, columnId: text('column_id') ?? '');
  }
  return null;
}
