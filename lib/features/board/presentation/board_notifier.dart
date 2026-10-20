import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/connection_status.dart';
import '../domain/apply_op.dart';
import '../domain/board_model.dart';
import '../domain/board_op.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'board_providers.dart';

class BoardNotifier extends Notifier<BoardSyncState> {
  final Map<String, Timer> _nackTimers = <String, Timer>{};

  @override
  BoardSyncState build() {
    final snapshot = ref.watch(boardSnapshotProvider);
    ref.onDispose(_cancelTimers);
    return BoardSyncState(
      confirmed: snapshot.board,
      lastSeq: snapshot.board.seq,
      pending: const <PendingOp>[],
      connection: snapshot.connection,
    );
  }

  bool get _canEdit {
    final userId = ref.read(currentUserProvider).userId;
    return state.liveView.memberById(userId)?.role.canEdit ?? false;
  }

  String get _actorId => ref.read(currentUserProvider).userId;

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
    final card = view.cardById(cardId);
    if (card == null || card.archived || view.columnById(toColumnId) == null) {
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

  void createCard({required String columnId, required String title}) {
    final trimmed = title.trim();
    if (!_canEdit || trimmed.isEmpty) {
      return;
    }
    if (state.liveView.columnById(columnId) == null) {
      return;
    }
    final existing = state.liveView.cardsIn(columnId);
    _enqueue(
      CreateCard(
        opId: _newId(),
        cardId: _newId(),
        columnId: columnId,
        title: trimmed,
        actorId: _actorId,
        afterId: existing.isEmpty ? null : existing.last.id,
      ),
    );
  }

  void editCardTitle({required String cardId, required String title}) {
    final trimmed = title.trim();
    final card = state.liveView.cardById(cardId);
    if (!_canEdit || trimmed.isEmpty || card == null || card.title == trimmed) {
      return;
    }
    _enqueue(
      EditCardTitle(
        opId: _newId(),
        cardId: cardId,
        title: trimmed,
        actorId: _actorId,
      ),
    );
  }

  void archiveCard(String cardId) {
    final card = state.liveView.cardById(cardId);
    if (!_canEdit || card == null || card.archived) {
      return;
    }
    _enqueue(ArchiveCard(opId: _newId(), cardId: cardId));
  }

  String _newId() => ref.read(idGeneratorProvider)();

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
      _send(op);
    }
  }

  void _send(BoardOp op) {
    unawaited(
      ref
          .read(boardGatewayProvider)
          .submit(op)
          .then(
            (outcome) => _onOutcome(op.opId, outcome),
            onError: (Object error, StackTrace stackTrace) => _onOutcome(
              op.opId,
              const OpRejected(OpRejection(reason: NackReason.internal)),
            ),
          ),
    );
  }

  void _onOutcome(String opId, OpOutcome outcome) {
    if (!ref.mounted) {
      return;
    }
    switch (outcome) {
      case OpConfirmed(:final seq):
        _confirm(opId, seq);
      case OpRejected(:final rejection):
        _reject(opId, rejection);
    }
  }

  PendingOp? _pendingById(String opId) {
    for (final item in state.pending) {
      if (item.opId == opId) {
        return item;
      }
    }
    return null;
  }

  void _confirm(String opId, int seq) {
    final item = _pendingById(opId);
    if (item == null) {
      return;
    }
    final remaining = state.pending
        .where((other) => other.opId != opId)
        .toList();
    if (seq <= state.lastSeq) {
      state = state.copyWith(pending: remaining);
      return;
    }
    state = state.copyWith(
      confirmed: applyOp(state.confirmed, item.op).copyWith(seq: seq),
      lastSeq: seq,
      pending: remaining,
    );
  }

  void _reject(String opId, OpRejection rejection) {
    final item = _pendingById(opId);
    if (item == null) {
      return;
    }
    final config = ref.read(boardSyncConfigProvider);
    if (rejection.reason == NackReason.internal &&
        item.failedAttempts < config.maxInternalRetries) {
      _scheduleRetry(item, config.retryDelay);
      return;
    }
    state = state.copyWith(
      pending: <PendingOp>[
        for (final other in state.pending)
          other.opId == opId
              ? other.copyWith(
                  status: PendingOpStatus.rejected,
                  rejection: rejection,
                )
              : other,
      ],
    );
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
      if (ref.mounted && _pendingById(item.opId) != null) {
        _send(item.op);
      }
    });
  }

  void _dropRejected(String opId) {
    _nackTimers.remove(opId);
    if (!ref.mounted) {
      return;
    }
    final item = _pendingById(opId);
    if (item == null) {
      return;
    }
    final op = item.op;
    final dropsDependents = op is CreateCard;
    state = state.copyWith(
      pending: state.pending.where((other) {
        if (other.opId == opId) {
          return false;
        }
        return !(dropsDependents && other.op.cardId == op.cardId);
      }).toList(),
    );
  }

  void _cancelTimers() {
    for (final timer in _nackTimers.values) {
      timer.cancel();
    }
    _nackTimers.clear();
  }
}
