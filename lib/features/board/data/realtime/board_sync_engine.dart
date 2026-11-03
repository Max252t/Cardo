import 'dart:async';
import 'dart:math' as math;

import '../../../../core/network/api_failure.dart';
import '../../../../core/realtime/connection_status.dart';
import '../../../../core/realtime/realtime_policy.dart';
import '../../../../core/realtime/reconnect_backoff.dart';
import '../../../../core/realtime/scheduler.dart';
import '../../../../core/result/result.dart';
import '../../../boards/domain/board_info.dart';
import '../../domain/board_event.dart';
import '../../domain/board_model.dart';
import '../../domain/board_op.dart';
import '../../domain/board_session.dart';
import '../../domain/board_sync_state.dart';
import '../../domain/close_policy.dart';
import '../../domain/seq_ordering.dart';
import '../board_gateway.dart';
import '../sync_signal.dart';
import 'board_catch_up.dart';
import 'message_codec.dart';
import 'protocol_issue.dart';
import 'realtime_credentials.dart';
import 'realtime_transport.dart';
import 'server_snapshot.dart';

class BoardSyncEngine {
  BoardSyncEngine({
    required this.boardId,
    required this.currentUser,
    required this.wsBaseUri,
    required this.transport,
    required this.credentials,
    required this.catchUp,
    required int initialSeq,
    this.scheduler = const SystemScheduler(),
    DateTime Function()? now,
    math.Random? random,
    this.clientName = RealtimePolicy.clientName,
  }) : _now = now ?? DateTime.now,
       _random = random ?? math.Random(),
       _ordering = SeqOrdering(initialSeq);

  final String boardId;
  final CurrentUser currentUser;
  final Uri wsBaseUri;
  final RealtimeTransport transport;
  final RealtimeCredentials credentials;
  final BoardCatchUpSource catchUp;
  final Scheduler scheduler;
  final String clientName;
  final DateTime Function() _now;
  final math.Random _random;
  final SeqOrdering _ordering;

  final StreamController<SyncSignal> _signals =
      StreamController<SyncSignal>.broadcast();
  final StreamController<ProtocolIssue> _issues =
      StreamController<ProtocolIssue>.broadcast();

  RealtimeChannel? _channel;
  StreamSubscription<String>? _subscription;
  Timer? _reconnectTimer;
  Timer? _countdownTimer;
  Timer? _readyTimer;
  Timer? _gapTimer;
  Timer? _refreshTimer;
  Timer? _refreshAckTimer;
  Timer? _catchUpRetryTimer;
  Timer? _snapshotRetryTimer;
  Timer? _idleTimer;
  int _generation = 0;
  int _attempt = 0;
  int _authLoops = 0;
  int _noProgress = 0;
  bool _running = false;
  bool _disposed = false;
  bool _ready = false;
  bool _forceRenew = false;
  bool _awaitingRefreshed = false;
  bool _catchingUp = false;
  bool _reloading = false;
  bool _resyncAfterReload = false;
  int _expectedSeq = 0;
  String? _token;
  DateTime? _grantExpiry;

  Stream<SyncSignal> get signals => _signals.stream;

  Stream<ProtocolIssue> get issues => _issues.stream;

  int get lastSeq => _ordering.lastSeq;

  bool get isRunning => _running;

  bool get isReady => _ready;

  Uri get socketUri {
    final segments = <String>[
      for (final segment in wsBaseUri.pathSegments)
        if (segment.isNotEmpty) segment,
      ...RealtimePolicy.wsPathSegments,
      boardId,
    ];
    return wsBaseUri.replace(pathSegments: segments);
  }

  void start() {
    if (_disposed || _running) {
      return;
    }
    _running = true;
    _attempt = 0;
    _authLoops = 0;
    unawaited(_connect());
  }

  void retryNow() {
    if (_disposed || !_running || _channel != null) {
      return;
    }
    _cancelReconnectTimers();
    unawaited(_connect());
  }

  SendOutcome send(BoardOp op) {
    final channel = _channel;
    if (!_ready || channel == null) {
      return SendOutcome.notConnected;
    }
    final text = encodeOp(op);
    final bytes = utf8Length(text);
    if (bytes > RealtimePolicy.maxMessageBytes) {
      _issue(OutgoingTooLarge(bytes));
      return SendOutcome.tooLarge;
    }
    return _write(channel, text) ? SendOutcome.sent : SendOutcome.notConnected;
  }

  Future<void> close() async {
    if (!_running && _channel == null) {
      return;
    }
    _running = false;
    _generation++;
    _cancelAllTimers();
    final channel = _detachChannel();
    _emit(const ConnectionSignal(ConnectionStatus.offline));
    await _closeQuietly(channel, CloseCodes.normal);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await close();
    _disposed = true;
    await _signals.close();
    await _issues.close();
  }

  bool _isCurrent(int generation) =>
      !_disposed && _running && generation == _generation;

  bool get _alive => !_disposed && _running;

  void _emit(SyncSignal signal) {
    if (!_signals.isClosed && _signals.hasListener) {
      _signals.add(signal);
    }
  }

  void _issue(ProtocolIssue issue) {
    if (!_issues.isClosed && _issues.hasListener) {
      _issues.add(issue);
    }
  }

  Future<void> _connect() async {
    if (!_alive) {
      return;
    }
    _cancelReconnectTimers();
    final generation = ++_generation;
    _emit(
      _attempt == 0
          ? const ConnectionSignal(ConnectionStatus.syncing)
          : const ConnectionSignal(ConnectionStatus.reconnecting),
    );
    final grant = await _acquireGrant(generation);
    if (grant == null || !_isCurrent(generation)) {
      return;
    }
    _token = grant.token;
    _grantExpiry = grant.expiresAt;
    final RealtimeChannel channel;
    try {
      channel = await transport.connect(
        socketUri,
        headers: <String, String>{'Authorization': 'Bearer ${grant.token}'},
      );
    } on RealtimeUnsupportedException {
      if (_isCurrent(generation)) {
        _issue(const RealtimeNotSupported());
        _end(BoardEndReason.unsupported);
      }
      return;
    } on RealtimeUpgradeRejected catch (rejected) {
      if (_isCurrent(generation)) {
        _onUpgradeRejected(rejected.status);
      }
      return;
    } on Exception {
      if (_isCurrent(generation)) {
        _scheduleReconnect();
      }
      return;
    }
    if (!_isCurrent(generation)) {
      await _closeQuietly(channel, CloseCodes.normal);
      return;
    }
    _channel = channel;
    _ready = false;
    _ordering.clearBuffer();
    _cancelTimer(_gapTimer);
    _gapTimer = null;
    _subscription = channel.messages.listen(
      (text) => _onText(generation, text),
      onError: (Object error) => _onStreamError(generation, error),
      onDone: () => _onDone(generation),
    );
    _emit(const ConnectionSignal(ConnectionStatus.syncing));
    _write(
      channel,
      encodeHello(lastSeq: _ordering.lastSeq, client: clientName),
    );
    _readyTimer = scheduler.after(RealtimePolicy.readyTimeout, () {
      if (_isCurrent(generation)) {
        _recycle();
      }
    });
    _scheduleTokenRefresh(grant.expiresAt, generation);
  }

  Future<AccessGrant?> _acquireGrant(int generation) async {
    if (_forceRenew) {
      _forceRenew = false;
      final renewal = await credentials.renew(staleAccess: _token);
      if (!_isCurrent(generation)) {
        return null;
      }
      switch (renewal) {
        case CredentialsRenewed(:final grant):
          return grant;
        case CredentialsSessionEnded():
          _end(BoardEndReason.sessionEnded);
          return null;
        case CredentialsUnavailable():
          _scheduleReconnect();
          return null;
      }
    }
    final grant = await credentials.current();
    if (!_isCurrent(generation)) {
      return null;
    }
    if (grant == null) {
      _end(BoardEndReason.sessionEnded);
    }
    return grant;
  }

  void _onText(int generation, String text) {
    if (!_isCurrent(generation)) {
      return;
    }
    switch (decodeServerMessage(text)) {
      case Success<ServerMessage, ProtocolIssue>(:final value):
        _handle(value);
      case Failure<ServerMessage, ProtocolIssue>(:final failure):
        _issue(failure);
        if (failure is InvalidPayload) {
          _expectMissing();
        }
    }
  }

  void _handle(ServerMessage message) {
    switch (message) {
      case SyncDeltaMessage(:final events, :final skipped):
        skipped.forEach(_issue);
        events.forEach(_acceptEvent);
        if (skipped.isNotEmpty) {
          _expectMissing();
        }
      case SyncSnapshotMessage(:final board):
        _applySnapshot(boardModelFor(board, currentUser));
      case SyncReadyMessage():
        _onReady();
      case PresenceListMessage(:final users):
        _emit(PresenceListSignal(users));
      case PresenceJoinMessage(:final user):
        _emit(PresenceJoinSignal(user));
      case PresenceLeaveMessage(:final userId):
        _emit(PresenceLeaveSignal(userId));
      case AuthRefreshedMessage():
        _onRefreshed();
      case NackMessage():
        _onNack(message);
      case ErrorMessage():
        _onServerError(message);
      case EventMessage(:final event):
        _acceptEvent(event);
    }
  }

  void _onReady() {
    _ready = true;
    _attempt = 0;
    _authLoops = 0;
    _cancelTimer(_readyTimer);
    _readyTimer = null;
    _cancelTimer(_idleTimer);
    final generation = _generation;
    _idleTimer = scheduler.every(RealtimePolicy.idlePoll, () {
      if (_isCurrent(generation) && _ready) {
        unawaited(_catchUp(poll: true));
      }
    });
    _emit(const ReadySignal());
  }

  void _expectMissing() {
    _expectedSeq = math.max(_expectedSeq, _ordering.lastSeq + 1);
    _updateGapTimer();
  }

  void _onUpgradeRejected(int status) {
    if (status == RealtimePolicy.upgradeUnauthorized) {
      _retryWithFreshToken();
    } else if (status == RealtimePolicy.upgradeForbidden ||
        status == RealtimePolicy.upgradeNotFound) {
      _end(BoardEndReason.accessLost);
    } else {
      _scheduleReconnect();
    }
  }

  void _retryWithFreshToken() {
    _authLoops++;
    _forceRenew = true;
    if (_authLoops > RealtimePolicy.authLoopLimit) {
      _scheduleReconnect();
    } else {
      unawaited(_connect());
    }
  }

  void _onNack(NackMessage message) {
    final opId = message.opId;
    if (opId == null) {
      _issue(const NackWithoutOpId());
      return;
    }
    _emit(
      NackSignal(
        opId: opId,
        rejection: OpRejection(reason: message.reason, atSeq: message.atSeq),
      ),
    );
    if (message.atSeq > _ordering.lastSeq) {
      _expectedSeq = math.max(_expectedSeq, message.atSeq);
      _updateGapTimer();
    }
    if (message.reason == NackReason.resyncRequired) {
      unawaited(_reloadSnapshot(resync: true));
    }
  }

  void _onServerError(ErrorMessage message) {
    if (message.code == 'invalid_token' && _awaitingRefreshed) {
      _recoverToken();
      return;
    }
    _issue(ServerReportedError(message.code, message.message));
  }

  void _acceptEvent(BoardEvent event) {
    if (event is UnknownBoardEvent) {
      _issue(UnknownMessageType(event.unknownType));
    }
    _emitIntake(_ordering.accept(event));
    _updateGapTimer();
  }

  void _applySnapshot(BoardModel board) {
    final intake = _ordering.rebase(board.seq);
    _expectedSeq = math.min(_expectedSeq, board.seq);
    _emit(SnapshotSignal(board));
    _emitIntake(intake);
    _updateGapTimer();
  }

  void _emitIntake(SeqIntake intake) {
    if (intake.duplicateOpIds.isNotEmpty) {
      _emit(DuplicatesSignal(intake.duplicateOpIds));
    }
    if (intake.ready.isNotEmpty) {
      _emit(EventsSignal(intake.ready));
    }
  }

  bool get _behind => _ordering.hasGap || _expectedSeq > _ordering.lastSeq;

  void _updateGapTimer() {
    if (!_behind) {
      _cancelTimer(_gapTimer);
      _gapTimer = null;
      _noProgress = 0;
      return;
    }
    if (_gapTimer != null || _catchingUp || !_alive) {
      return;
    }
    _gapTimer = scheduler.after(RealtimePolicy.gapWait, () {
      _gapTimer = null;
      if (_alive && _behind) {
        unawaited(_catchUp());
      }
    });
  }

  Future<void> _catchUp({bool poll = false}) async {
    if (_catchingUp || _reloading || !_alive) {
      return;
    }
    _catchingUp = true;
    final generation = _generation;
    var gone = false;
    var transient = false;
    try {
      while (_alive) {
        final before = _ordering.lastSeq;
        final result = await catchUp.getEvents(boardId, before);
        if (!_alive) {
          return;
        }
        if (result is Failure<EventsPage, ApiFailure>) {
          gone = result.failure is GoneFailure;
          transient = !gone && _isTransient(result.failure);
          break;
        }
        final page = (result as Success<EventsPage, ApiFailure>).value;
        page.events.forEach(_acceptEvent);
        if (page.seq > _ordering.lastSeq) {
          _expectedSeq = math.max(_expectedSeq, page.seq);
        }
        if (!page.hasMore ||
            page.events.isEmpty ||
            _ordering.lastSeq == before) {
          break;
        }
      }
    } finally {
      _catchingUp = false;
    }
    if (!_isCurrent(generation)) {
      return;
    }
    if (gone) {
      await _reloadSnapshot();
      return;
    }
    if (poll && !_behind) {
      return;
    }
    if (_behind) {
      _noProgress++;
      if (!transient && _noProgress >= RealtimePolicy.catchUpGiveUpAfter) {
        _noProgress = 0;
        await _reloadSnapshot();
        return;
      }
      _scheduleCatchUpRetry();
      return;
    }
    _updateGapTimer();
  }

  bool _isTransient(ApiFailure failure) {
    return switch (failure) {
      NetworkFailure() || BusyFailure() || RateLimitedFailure() => true,
      UnknownFailure(:final statusCode) =>
        statusCode != null && statusCode >= 500,
      _ => false,
    };
  }

  Future<void> _reloadSnapshot({bool resync = false}) async {
    if (_reloading) {
      _resyncAfterReload = _resyncAfterReload || resync;
      return;
    }
    _reloading = true;
    final generation = _generation;
    try {
      final result = await catchUp.getBoard(boardId);
      if (!_alive) {
        return;
      }
      switch (result) {
        case Success<ServerBoard, ApiFailure>(:final value):
          final board = boardModelFor(value, currentUser);
          if (board.seq < _ordering.lastSeq) {
            _resyncAfterReload = _resyncAfterReload || resync;
            if (_isCurrent(generation)) {
              _scheduleSnapshotRetry();
            }
            return;
          }
          _applySnapshot(board);
          if (resync || _resyncAfterReload) {
            _emit(const ResyncedSignal());
          }
          _resyncAfterReload = false;
        case Failure<ServerBoard, ApiFailure>():
          _resyncAfterReload = _resyncAfterReload || resync;
          if (_isCurrent(generation)) {
            _scheduleSnapshotRetry();
          }
      }
    } finally {
      _reloading = false;
    }
  }

  void _scheduleCatchUpRetry() {
    _cancelTimer(_catchUpRetryTimer);
    _catchUpRetryTimer = scheduler.after(RealtimePolicy.catchUpRetry, () {
      _catchUpRetryTimer = null;
      if (_alive) {
        unawaited(_catchUp());
      }
    });
  }

  void _scheduleSnapshotRetry() {
    _cancelTimer(_snapshotRetryTimer);
    _snapshotRetryTimer = scheduler.after(RealtimePolicy.catchUpRetry, () {
      _snapshotRetryTimer = null;
      if (_alive) {
        unawaited(_reloadSnapshot());
      }
    });
  }

  void _scheduleTokenRefresh(
    DateTime expiresAt,
    int generation, {
    Duration floor = Duration.zero,
  }) {
    _cancelTimer(_refreshTimer);
    var delay =
        expiresAt.difference(_now()) - RealtimePolicy.tokenRefreshLeeway;
    if (delay < floor) {
      delay = floor;
    }
    _refreshTimer = scheduler.after(delay, () {
      _refreshTimer = null;
      unawaited(_refreshToken(generation));
    });
  }

  Future<void> _refreshToken(int generation) async {
    if (!_isCurrent(generation)) {
      return;
    }
    final renewal = await credentials.renew(staleAccess: _token);
    final channel = _channel;
    if (!_isCurrent(generation) || channel == null) {
      return;
    }
    switch (renewal) {
      case CredentialsRenewed(:final grant):
        _token = grant.token;
        _grantExpiry = grant.expiresAt;
        _awaitingRefreshed = true;
        _write(channel, encodeAuthRefresh(grant.token));
        _cancelTimer(_refreshAckTimer);
        _refreshAckTimer = scheduler.after(
          RealtimePolicy.refreshAckTimeout,
          () {
            if (_isCurrent(generation) && _awaitingRefreshed) {
              _recoverToken();
            }
          },
        );
      case CredentialsSessionEnded():
        _end(BoardEndReason.sessionEnded);
      case CredentialsUnavailable():
        _refreshTimer = scheduler.after(RealtimePolicy.refreshRetry, () {
          _refreshTimer = null;
          unawaited(_refreshToken(generation));
        });
    }
  }

  void _onRefreshed() {
    _awaitingRefreshed = false;
    _authLoops = 0;
    _cancelTimer(_refreshAckTimer);
    _refreshAckTimer = null;
    final expiry = _grantExpiry;
    if (expiry != null) {
      _scheduleTokenRefresh(
        expiry,
        _generation,
        floor: RealtimePolicy.minRefreshDelay,
      );
    }
  }

  void _recoverToken() {
    _forceRenew = true;
    _authLoops++;
    _recycle(delay: _authLoops > RealtimePolicy.authLoopLimit);
  }

  void _recycle({bool delay = true}) {
    _generation++;
    _cancelConnectionTimers();
    final channel = _detachChannel();
    unawaited(_closeQuietly(channel, CloseCodes.normal));
    if (delay) {
      _scheduleReconnect();
    } else {
      unawaited(_connect());
    }
  }

  void _onStreamError(int generation, Object error) {
    if (!_isCurrent(generation)) {
      return;
    }
    if (error is FormatException) {
      _issue(const BinaryFrameReceived());
    }
    final channel = _channel;
    _lose(null, null);
    unawaited(_closeQuietly(channel, CloseCodes.normal));
  }

  void _onDone(int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    final channel = _channel;
    _lose(channel?.closeCode, channel?.closeReason);
  }

  void _lose(int? code, String? reason) {
    _generation++;
    _cancelConnectionTimers();
    _detachChannel();
    switch (classifyClose(code)) {
      case CloseAction.boardRemoved:
        _end(BoardEndReason.removed);
      case CloseAction.boardDeleted:
        _end(BoardEndReason.boardDeleted);
      case CloseAction.refreshAndReconnect:
        _retryWithFreshToken();
      case CloseAction.reconnectSlow:
        _scheduleReconnect(minimum: RealtimePolicy.abuseBackoff);
      case CloseAction.reconnectAfterViolation:
        _issue(ClosedForProtocolViolation(reason));
        _scheduleReconnect();
      case CloseAction.reconnect:
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect({Duration minimum = Duration.zero}) {
    if (!_alive) {
      return;
    }
    _cancelReconnectTimers();
    _generation++;
    final delay = reconnectDelay(_attempt, _random, minimum: minimum);
    _attempt++;
    var seconds = countdownSeconds(delay);
    _emit(
      ConnectionSignal(
        ConnectionStatus.reconnecting,
        reconnectSeconds: seconds,
      ),
    );
    _countdownTimer = scheduler.every(RealtimePolicy.countdownTick, () {
      if (seconds > 1) {
        seconds--;
        _emit(
          ConnectionSignal(
            ConnectionStatus.reconnecting,
            reconnectSeconds: seconds,
          ),
        );
      }
    });
    _reconnectTimer = scheduler.after(delay, () {
      _reconnectTimer = null;
      _cancelTimer(_countdownTimer);
      _countdownTimer = null;
      unawaited(_connect());
    });
  }

  void _end(BoardEndReason reason) {
    _running = false;
    _generation++;
    _cancelAllTimers();
    final channel = _detachChannel();
    unawaited(_closeQuietly(channel, CloseCodes.normal));
    _emit(const ConnectionSignal(ConnectionStatus.offline));
    _emit(EndedSignal(reason));
  }

  RealtimeChannel? _detachChannel() {
    final channel = _channel;
    _channel = null;
    _ready = false;
    _awaitingRefreshed = false;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    return channel;
  }

  Future<void> _closeQuietly(RealtimeChannel? channel, int code) async {
    if (channel == null) {
      return;
    }
    try {
      await channel.close(code);
    } on Exception {
      return;
    }
  }

  bool _write(RealtimeChannel channel, String text) {
    try {
      channel.send(text);
      return true;
    } on StateError {
      return false;
    } on Exception {
      return false;
    }
  }

  void _cancelTimer(Timer? timer) => timer?.cancel();

  void _cancelReconnectTimers() {
    _cancelTimer(_reconnectTimer);
    _cancelTimer(_countdownTimer);
    _reconnectTimer = null;
    _countdownTimer = null;
  }

  void _cancelConnectionTimers() {
    for (final timer in <Timer?>[
      _readyTimer,
      _gapTimer,
      _refreshTimer,
      _refreshAckTimer,
      _catchUpRetryTimer,
      _snapshotRetryTimer,
      _idleTimer,
    ]) {
      _cancelTimer(timer);
    }
    _readyTimer = null;
    _gapTimer = null;
    _refreshTimer = null;
    _refreshAckTimer = null;
    _catchUpRetryTimer = null;
    _snapshotRetryTimer = null;
    _idleTimer = null;
  }

  void _cancelAllTimers() {
    _cancelReconnectTimers();
    _cancelConnectionTimers();
  }
}
