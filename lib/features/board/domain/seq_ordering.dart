import 'board_event.dart';

class SeqIntake {
  SeqIntake({
    required List<BoardEvent> ready,
    required List<String> duplicateOpIds,
    required this.hasGap,
  }) : ready = List<BoardEvent>.unmodifiable(ready),
       duplicateOpIds = List<String>.unmodifiable(duplicateOpIds);

  final List<BoardEvent> ready;
  final List<String> duplicateOpIds;
  final bool hasGap;

  bool get isEmpty => ready.isEmpty && duplicateOpIds.isEmpty;
}

class SeqOrdering {
  SeqOrdering(int lastSeq) : _lastSeq = lastSeq;

  int _lastSeq;
  final Map<int, BoardEvent> _buffer = <int, BoardEvent>{};

  int get lastSeq => _lastSeq;

  bool get hasGap => _buffer.isNotEmpty;

  int get bufferedCount => _buffer.length;

  int? get firstBufferedSeq {
    if (_buffer.isEmpty) {
      return null;
    }
    return _buffer.keys.reduce((a, b) => a < b ? a : b);
  }

  SeqIntake accept(BoardEvent event) {
    final duplicates = <String>[];
    final ready = <BoardEvent>[];
    if (event.seq <= 0) {
      return _result(ready, duplicates);
    }
    if (event.seq <= _lastSeq) {
      _noteDuplicate(event, duplicates);
    } else if (event.seq == _lastSeq + 1) {
      _take(event, ready);
      _drain(ready, duplicates);
    } else {
      _buffer[event.seq] = event;
    }
    return _result(ready, duplicates);
  }

  SeqIntake rebase(int seq) {
    _lastSeq = seq;
    final duplicates = <String>[];
    final ready = <BoardEvent>[];
    _drain(ready, duplicates);
    return _result(ready, duplicates);
  }

  void clearBuffer() => _buffer.clear();

  void _take(BoardEvent event, List<BoardEvent> ready) {
    ready.add(event);
    _lastSeq = event.seq;
  }

  void _drain(List<BoardEvent> ready, List<String> duplicates) {
    for (final seq in _buffer.keys.where((seq) => seq <= _lastSeq).toList()) {
      _noteDuplicate(_buffer.remove(seq)!, duplicates);
    }
    var next = _buffer.remove(_lastSeq + 1);
    while (next != null) {
      _take(next, ready);
      next = _buffer.remove(_lastSeq + 1);
    }
  }

  void _noteDuplicate(BoardEvent event, List<String> duplicates) {
    final opId = event.opId;
    if (opId != null) {
      duplicates.add(opId);
    }
  }

  SeqIntake _result(List<BoardEvent> ready, List<String> duplicates) {
    return SeqIntake(
      ready: ready,
      duplicateOpIds: duplicates,
      hasGap: _buffer.isNotEmpty,
    );
  }
}
