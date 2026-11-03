import 'dart:async';

import '../../../core/realtime/realtime_policy.dart';
import '../../../core/realtime/scheduler.dart';
import '../domain/board_op.dart';
import 'board_gateway.dart';

typedef OpDispatch = SendOutcome Function(BoardOp op);

typedef OpFilter = bool Function(BoardOp op);

typedef OpStall = void Function(List<BoardOp> unsent);

class OpSender {
  OpSender({
    required this.scheduler,
    required this.now,
    required this.dispatch,
    required this.shouldSend,
    required this.onStall,
    this.burst = RealtimePolicy.opBurst,
    this.refill = RealtimePolicy.opRefillInterval,
  }) : _tokens = burst,
       _lastRefill = now();

  final Scheduler scheduler;
  final DateTime Function() now;
  final OpDispatch dispatch;
  final OpFilter shouldSend;
  final OpStall onStall;
  final int burst;
  final Duration refill;

  final List<BoardOp> _queue = <BoardOp>[];
  final Map<String, String> _barriers = <String, String>{};
  final Map<String, String> _columnBarriers = <String, String>{};
  final Map<String, int> _order = <String, int>{};
  int _counter = 0;
  int _tokens;
  DateTime _lastRefill;
  bool _paused = false;
  bool _disposed = false;
  Timer? _refillTimer;
  Timer? _pauseTimer;

  int get queued => _queue.length;

  void enqueue(BoardOp op) {
    if (_disposed) {
      return;
    }
    final known = _order[op.opId];
    final number = known ?? _counter++;
    _order[op.opId] = number;
    final at = known == null
        ? _queue.length
        : _queue.indexWhere((other) => (_order[other.opId] ?? 0) > number);
    _queue.insert(at < 0 ? _queue.length : at, op);
    _drain();
  }

  void releaseResolved(bool Function(String opId) resolved) {
    final before = _barriers.length + _columnBarriers.length;
    _barriers.removeWhere((cardId, opId) => resolved(opId));
    _columnBarriers.removeWhere((columnId, opId) => resolved(opId));
    if (_barriers.length + _columnBarriers.length != before) {
      _drain();
    }
  }

  void kick() => _drain();

  void pause(Duration duration) {
    if (_disposed) {
      return;
    }
    _paused = true;
    _tokens = 0;
    _lastRefill = now();
    _pauseTimer?.cancel();
    _pauseTimer = scheduler.after(duration, () {
      _pauseTimer = null;
      _paused = false;
      _drain();
    });
  }

  void clear() {
    _queue.clear();
    _tokens = burst;
    _lastRefill = now();
    _barriers.clear();
    _columnBarriers.clear();
    _order.clear();
    _refillTimer?.cancel();
    _refillTimer = null;
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _paused = false;
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  bool _isBlocked(BoardOp op) {
    for (final entry in _columnBarriers.entries) {
      if (entry.value != op.opId && op.referencesColumn(entry.key)) {
        return true;
      }
    }
    final cardId = op.cardId;
    if (cardId == null) {
      return false;
    }
    final holder = _barriers[cardId];
    return holder != null && holder != op.opId;
  }

  int _nextSendable() {
    final heldCards = <String>{};
    final heldColumns = <String>{};
    var anyHeld = false;
    for (var i = 0; i < _queue.length; i++) {
      final op = _queue[i];
      final cardId = op.cardId;
      final held =
          _isBlocked(op) ||
          (cardId != null && heldCards.contains(cardId)) ||
          heldColumns.any(op.referencesColumn) ||
          (anyHeld && op is ArchiveColumn);
      if (!held) {
        return i;
      }
      anyHeld = true;
      if (cardId != null) {
        heldCards.add(cardId);
      }
      if (op is CreateColumn) {
        heldColumns.add(op.columnId);
      } else if (op is MoveColumn) {
        heldColumns.add(op.columnId);
      }
    }
    return -1;
  }

  void _refillByClock() {
    final elapsed = now().difference(_lastRefill);
    final earned = elapsed.inMicroseconds ~/ refill.inMicroseconds;
    if (earned > 0) {
      _tokens = _tokens + earned > burst ? burst : _tokens + earned;
      _lastRefill = _lastRefill.add(refill * earned);
    }
  }

  void _drain() {
    _refillByClock();
    while (!_disposed && !_paused && _tokens > 0) {
      final index = _nextSendable();
      if (index < 0) {
        break;
      }
      final op = _queue.removeAt(index);
      if (!shouldSend(op)) {
        continue;
      }
      _tokens--;
      final outcome = dispatch(op);
      if (outcome == SendOutcome.sent && op is CreateCard) {
        _barriers[op.cardId] = op.opId;
      }
      if (outcome == SendOutcome.sent && op is CreateColumn) {
        _columnBarriers[op.columnId] = op.opId;
      }
      if (outcome == SendOutcome.notConnected) {
        final unsent = <BoardOp>[op, ..._queue];
        _queue.clear();
        onStall(unsent);
        break;
      }
    }
    _scheduleRefill();
  }

  void _scheduleRefill() {
    if (_disposed ||
        _paused ||
        _refillTimer != null ||
        _tokens > 0 ||
        _nextSendable() < 0) {
      return;
    }
    _refillTimer = scheduler.after(refill, () {
      _refillTimer = null;
      if (_tokens < burst) {
        _tokens++;
      }
      _lastRefill = now();
      _drain();
    });
  }
}
