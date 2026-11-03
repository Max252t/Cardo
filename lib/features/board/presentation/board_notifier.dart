import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/connection_status.dart';
import '../../../core/realtime/realtime_policy.dart';
import '../data/board_gateway.dart';
import '../data/op_sender.dart';
import '../data/sync_signal.dart';
import '../domain/apply_op.dart';
import '../domain/board_event.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_sync_state.dart';
import '../domain/op_limits.dart';
import 'board_providers.dart';
import 'realtime_providers.dart';

class BoardNotifier extends Notifier<BoardSyncState> {
  final Map<String, Timer> _nackTimers = <String, Timer>{};
  final Map<String, int> _rateRetries = <String, int>{};
  late final OpSender _sender;
  bool _resyncing = false;
  bool _hasBeenReady = false;

  @override
  BoardSyncState build() {
    final snapshot = ref.watch(boardSnapshotProvider);
    final gateway = ref.read(boardGatewayProvider);
    _sender = OpSender(
      scheduler: ref.read(realtimeSchedulerProvider),
      now: ref.read(nowProvider),
      dispatch: _dispatch,
      shouldSend: _stillPending,
      onStall: (unsent) =>
          _markQueued(<String>{for (final op in unsent) op.opId}),
    );
    ref.onDispose(_sender.dispose);
    final subscription = gateway.signals.listen(_onSignal);
    ref.onDispose(subscription.cancel);
    ref.onDispose(_cancelTimers);
    ref.onDispose(() => unawaited(gateway.close()));
    gateway.connect();
    return BoardSyncState(
      confirmed: snapshot.board,
      lastSeq: snapshot.board.seq,
      pending: const <PendingOp>[],
      connection: snapshot.connection,
    );
  }

  BoardGateway get _gateway => ref.read(boardGatewayProvider);

  bool get _canEdit {
    final userId = ref.read(currentUserProvider).userId;
    return state.liveView.memberById(userId)?.role.canEdit ?? false;
  }

  String get _actorId => ref.read(currentUserProvider).userId;

  void retryConnection() => _gateway.retryNow();

  void dismissSummary() {
    state = state.dismissedSummary();
  }

  void acknowledgeRejections() {
    state = state.acknowledgedRejections();
  }

  void moveCard({
    required String cardId,
    required String toColumnId,
    String? afterId,
    String? beforeId,
  }) {
    _moveTo(
      cardId,
      toColumnId,
      (target) =>
          resolveInsertIndex(target, afterId: afterId, beforeId: beforeId),
    );
  }

  void moveCardToIndex({
    required String cardId,
    required String toColumnId,
    required int index,
  }) {
    _moveTo(cardId, toColumnId, (target) => index.clamp(0, target.length));
  }

  void moveCardToColumnEnd({
    required String cardId,
    required String toColumnId,
  }) {
    _moveTo(cardId, toColumnId, (target) => target.length);
  }

  void _moveTo(
    String cardId,
    String toColumnId,
    int Function(List<CardModel> target) indexIn,
  ) {
    if (!_canEdit) {
      return;
    }
    final view = state.liveView;
    final card = view.activeCard(cardId);
    if (card == null || view.columnById(toColumnId) == null) {
      return;
    }
    final current = view.cardsIn(toColumnId);
    final target = current.where((other) => other.id != cardId).toList();
    final index = indexIn(target);
    final unchanged =
        card.columnId == toColumnId &&
        current.indexWhere((other) => other.id == cardId) == index;
    if (unchanged) {
      return;
    }
    final anchors = anchorsAt(target, index);
    _enqueue(
      MoveCard(
        opId: _newId(),
        cardId: cardId,
        toColumnId: toColumnId,
        afterId: anchors.afterId,
        beforeId: anchors.beforeId,
        baseVersion: card.version,
      ),
    );
  }

  bool createCard({
    required String columnId,
    required String title,
    String description = '',
  }) {
    final trimmed = title.trim();
    if (!_canEdit ||
        trimmed.isEmpty ||
        trimmed.runes.length > CardLimits.titleMaxLength ||
        description.runes.length > CardLimits.descriptionMaxLength) {
      return false;
    }
    if (state.liveView.columnById(columnId) == null) {
      return false;
    }
    final existing = state.liveView.cardsIn(columnId);
    _enqueue(
      CreateCard(
        opId: _newId(),
        cardId: _newId(),
        columnId: columnId,
        title: trimmed,
        description: description,
        actorId: _actorId,
        afterId: existing.isEmpty ? null : existing.last.id,
        at: _now(),
      ),
    );
    return true;
  }

  void editCardTitle({required String cardId, required String title}) {
    if (!ref.mounted) {
      return;
    }
    final trimmed = title.trim();
    final card = state.liveView.activeCard(cardId);
    if (!_canEdit ||
        trimmed.isEmpty ||
        trimmed.runes.length > CardLimits.titleMaxLength ||
        card == null ||
        card.title == trimmed) {
      return;
    }
    _enqueue(
      EditCardTitle(
        opId: _newId(),
        cardId: cardId,
        title: trimmed,
        actorId: _actorId,
        at: _now(),
      ),
    );
  }

  String? editCardDescription({
    required String cardId,
    required String description,
    required int baseDescriptionVersion,
  }) {
    if (!_canEdit ||
        state.liveView.activeCard(cardId) == null ||
        description.runes.length > CardLimits.descriptionMaxLength) {
      return null;
    }
    final opId = _newId();
    _enqueue(
      EditCardDescription(
        opId: opId,
        cardId: cardId,
        description: description,
        baseDescriptionVersion: baseDescriptionVersion,
        actorId: _actorId,
        at: _now(),
      ),
    );
    return opId;
  }

  void archiveCard(String cardId) {
    if (!_canEdit || state.liveView.activeCard(cardId) == null) {
      return;
    }
    _enqueue(ArchiveCard(opId: _newId(), cardId: cardId));
  }

  String? createColumn(String title) {
    final trimmed = title.trim();
    if (!_canEdit || !_validColumnTitle(trimmed)) {
      return null;
    }
    final ordered = state.liveView.orderedColumns;
    final columnId = _newId();
    _enqueue(
      CreateColumn(
        opId: _newId(),
        columnId: columnId,
        title: trimmed,
        afterId: ordered.isEmpty ? null : ordered.last.id,
      ),
    );
    return columnId;
  }

  void renameColumn({required String columnId, required String title}) {
    final trimmed = title.trim();
    final column = state.liveView.columnById(columnId);
    if (!_canEdit ||
        column == null ||
        column.title == trimmed ||
        !_validColumnTitle(trimmed)) {
      return;
    }
    _enqueue(RenameColumn(opId: _newId(), columnId: columnId, title: trimmed));
  }

  void moveColumn({required String columnId, required int direction}) {
    if (!_canEdit || direction == 0) {
      return;
    }
    final view = state.liveView;
    final column = view.columnById(columnId);
    if (column == null) {
      return;
    }
    final ordered = view.orderedColumns;
    final from = ordered.indexWhere((other) => other.id == columnId);
    final to = from + direction.sign;
    if (to < 0 || to >= ordered.length) {
      return;
    }
    final others = ordered.where((other) => other.id != columnId).toList();
    _enqueue(
      MoveColumn(
        opId: _newId(),
        columnId: columnId,
        baseVersion: column.version,
        afterId: to > 0 ? others[to - 1].id : null,
        beforeId: to < others.length ? others[to].id : null,
      ),
    );
  }

  void archiveColumn(String columnId) {
    if (!_canEdit || state.liveView.columnById(columnId) == null) {
      return;
    }
    _enqueue(ArchiveColumn(opId: _newId(), columnId: columnId));
  }

  bool _validColumnTitle(String title) =>
      title.isNotEmpty && title.runes.length <= ColumnLimits.titleMaxLength;

  String _newId() => ref.read(idGeneratorProvider)();

  DateTime _now() => ref.read(nowProvider)().toUtc();

  void _onSignal(SyncSignal signal) {
    if (!ref.mounted) {
      return;
    }
    switch (signal) {
      case ConnectionSignal(:final status, :final reconnectSeconds):
        _onConnection(status, reconnectSeconds);
      case ReadySignal():
        _onReady();
      case ResyncedSignal():
        _resyncing = false;
        _flush();
      case EventsSignal(:final events):
        _onEvents(events);
      case DuplicatesSignal(:final opIds):
        state = state.withoutOps(opIds.toSet());
        _releaseBarriers();
      case SnapshotSignal(:final board):
        state = state.afterSnapshot(board);
        _resolveActors();
        _releaseBarriers();
        if (!_resyncing) {
          _flush();
        }
      case NackSignal(:final opId, :final rejection):
        _onNack(opId, rejection);
      case PresenceListSignal(:final users):
        ref.read(boardPresenceProvider.notifier).replace(users);
      case PresenceJoinSignal(:final user):
        ref.read(boardPresenceProvider.notifier).join(user);
      case PresenceLeaveSignal(:final userId):
        ref.read(boardPresenceProvider.notifier).leave(userId);
      case EndedSignal(:final reason):
        _end(reason);
    }
    _settle();
  }

  void _settle() {
    final next = state.settleBatch();
    if (!identical(next, state)) {
      state = next;
    }
  }

  void _onConnection(ConnectionStatus status, int? seconds) {
    if (state.ended != null) {
      return;
    }
    if (status != ConnectionStatus.connected) {
      _sender.clear();
      _resyncing = false;
    }
    state = state.copyWith(
      connection: status,
      reconnectSeconds: seconds,
      clearReconnectSeconds: seconds == null,
    );
    if (status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.offline) {
      ref.read(boardPresenceProvider.notifier).clear();
    }
  }

  void _onReady() {
    if (state.ended != null) {
      return;
    }
    final reconnect = _hasBeenReady;
    _hasBeenReady = true;
    state = state
        .afterReady(_now(), RealtimePolicy.pendingMaxAge, reconnect: reconnect)
        .copyWith(
          connection: ConnectionStatus.connected,
          clearReconnectSeconds: true,
        );
    _flush();
  }

  void _flush() {
    if (state.connection != ConnectionStatus.connected) {
      return;
    }
    final toSend = <PendingOp>[
      for (final item in state.pending)
        if (!item.isRejected) item,
    ];
    if (toSend.isEmpty) {
      return;
    }
    final ids = toSend.map((item) => item.opId).toSet();
    state = state.copyWith(
      pending: <PendingOp>[
        for (final item in state.pending)
          ids.contains(item.opId)
              ? item.copyWith(status: PendingOpStatus.sent)
              : item,
      ],
    );
    _sender.clear();
    for (final item in toSend) {
      _sender.enqueue(item.op);
    }
  }

  bool _stillPending(BoardOp op) {
    final item = state.pendingById(op.opId);
    if (item == null || item.isRejected) {
      return false;
    }
    final cardId = op.cardId;
    return (cardId == null || !state.hasRejectedCreate(cardId)) &&
        !state.dependsOnRejectedColumnCreate(op);
  }

  void _releaseBarriers() {
    _sender.releaseResolved((opId) {
      final item = state.pendingById(opId);
      return item == null || item.isRejected;
    });
  }

  SendOutcome _dispatch(BoardOp op) {
    final outcome = _gateway.send(op);
    switch (outcome) {
      case SendOutcome.sent:
      case SendOutcome.notConnected:
        return outcome;
      case SendOutcome.tooLarge:
        _reject(
          op.opId,
          OpRejection(
            reason: NackReason.validationError,
            atSeq: state.lastSeq,
            limit: textLimitOf(op),
          ),
        );
        _settle();
        return SendOutcome.sent;
    }
  }

  void _markQueued(Set<String> opIds) {
    state = state.copyWith(
      pending: <PendingOp>[
        for (final other in state.pending)
          opIds.contains(other.opId) && !other.isRejected
              ? other.copyWith(status: PendingOpStatus.queued)
              : other,
      ],
    );
  }

  void _onEvents(List<BoardEvent> events) {
    state = state.applyServerEvents(events);
    _resolveActors();
    _releaseBarriers();
    final userId = ref.read(currentUserProvider).userId;
    for (final event in events) {
      if (event is MemberRemovedEvent && event.userId == userId) {
        _end(BoardEndReason.removed);
        return;
      }
      if (event is BoardDeletedEvent) {
        _end(BoardEndReason.boardDeleted);
        return;
      }
    }
  }

  void _end(BoardEndReason reason) {
    if (state.ended != null) {
      return;
    }
    state = state.copyWith(
      ended: reason,
      connection: ConnectionStatus.offline,
      clearReconnectSeconds: true,
    );
    unawaited(_gateway.close());
  }

  void _onNack(String opId, OpRejection rejection) {
    final item = state.pendingById(opId);
    if (item == null) {
      return;
    }
    if (rejection.reason == NackReason.resyncRequired) {
      _resyncing = true;
      state = state.withoutOps(<String>{opId});
      _releaseBarriers();
      return;
    }
    if (rejection.reason == NackReason.rateLimited && !item.isRejected) {
      final attempts = (_rateRetries[opId] ?? 0) + 1;
      if (attempts <= RealtimePolicy.rateLimitRetries) {
        _rateRetries[opId] = attempts;
        _sender.pause(RealtimePolicy.rateLimitPause);
        _sender.enqueue(item.op);
        return;
      }
    }
    _reject(opId, _enrich(item.op, rejection));
    _releaseBarriers();
  }

  void _resolveActors() {
    if (_rateRetries.isNotEmpty) {
      _rateRetries.removeWhere((id, _) => state.pendingById(id) == null);
    }
    final me = _actorId;
    var changed = false;
    var log = state.rejections;
    final next = <PendingOp>[];
    for (final item in state.pending) {
      final rejection = item.rejection;
      final cardId = item.op.cardId;
      final atSeq = rejection?.atSeq;
      if (rejection != null &&
          item.isRejected &&
          rejection.reason == NackReason.versionConflict &&
          rejection.actorId == null &&
          cardId != null &&
          (atSeq == null || state.lastSeq >= atSeq)) {
        final author = state.confirmed.cardById(cardId)?.updatedBy;
        if (author != null && author != me) {
          changed = true;
          log = log.withActor(item.opId, author);
          next.add(item.copyWith(rejection: rejection.withActor(author)));
          continue;
        }
      }
      next.add(item);
    }
    if (changed) {
      state = state.copyWith(pending: next, rejections: log);
    }
  }

  OpRejection _enrich(BoardOp op, OpRejection rejection) {
    var enriched = rejection;
    if (rejection.reason == NackReason.validationError &&
        rejection.limit == null) {
      enriched = OpRejection(
        reason: rejection.reason,
        atSeq: rejection.atSeq,
        actorId: rejection.actorId,
        limit: textLimitOf(op),
      );
    }
    final atSeq = rejection.atSeq;
    if (rejection.reason == NackReason.versionConflict &&
        rejection.actorId == null &&
        (atSeq == null || state.lastSeq >= atSeq)) {
      final cardId = op.cardId;
      final author = cardId == null
          ? null
          : state.confirmed.cardById(cardId)?.updatedBy;
      if (author != null && author != _actorId) {
        enriched = enriched.withActor(author);
      }
    }
    return enriched;
  }

  void _enqueue(BoardOp op) {
    final sending = state.connection == ConnectionStatus.connected;
    state = state.copyWith(
      pending: <PendingOp>[
        ...state.pending,
        PendingOp(
          op: op,
          status: sending ? PendingOpStatus.sent : PendingOpStatus.queued,
          createdAt: ref.read(nowProvider)(),
        ),
      ],
    );
    if (sending) {
      _sender.enqueue(op);
    }
  }

  void _reject(String opId, OpRejection rejection) {
    final item = state.pendingById(opId);
    if (item == null) {
      return;
    }
    final config = ref.read(boardSyncConfigProvider);
    if (rejection.reason == NackReason.internal &&
        item.failedAttempts < config.maxInternalRetries) {
      _scheduleRetry(item, config.retryDelay);
      return;
    }
    state = state
        .copyWith(
          pending: <PendingOp>[
            for (final other in state.pending)
              other.opId == opId
                  ? other.copyWith(
                      status: PendingOpStatus.rejected,
                      rejection: rejection,
                    )
                  : other,
          ],
        )
        .withRejectionLogged(opId);
    _nackTimers[opId]?.cancel();
    _nackTimers[opId] = Timer(config.nackHold, () => _dropRejected(opId));
  }

  void _scheduleRetry(PendingOp item, Duration delay) {
    state = state.copyWith(
      pending: <PendingOp>[
        for (final other in state.pending)
          other.opId == item.opId
              ? other.copyWith(failedAttempts: other.failedAttempts + 1)
              : other,
      ],
    );
    _nackTimers[item.opId]?.cancel();
    _nackTimers[item.opId] = Timer(delay, () {
      _nackTimers.remove(item.opId);
      if (!ref.mounted) {
        return;
      }
      if (state.pendingById(item.opId) != null &&
          state.connection == ConnectionStatus.connected) {
        _sender.enqueue(item.op);
      } else {
        _sender.kick();
      }
    });
  }

  void _dropRejected(String opId) {
    _nackTimers.remove(opId);
    if (!ref.mounted) {
      return;
    }
    final item = state.pendingById(opId);
    if (item == null) {
      return;
    }
    final dependents = state.dependentOpIds(item.op);
    state = state.copyWith(
      pending: state.pending
          .where(
            (other) => other.opId != opId && !dependents.contains(other.opId),
          )
          .toList(),
    );
  }

  void _cancelTimers() {
    for (final timer in _nackTimers.values) {
      timer.cancel();
    }
    _nackTimers.clear();
  }
}
