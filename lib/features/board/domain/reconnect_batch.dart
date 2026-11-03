import '../../../core/equality/collection_equality.dart';

class ReconnectBatch {
  ReconnectBatch({
    required Iterable<String> ids,
    Iterable<String> held = const <String>[],
  }) : ids = List<String>.unmodifiable(<String>{...ids}),
       held = Set<String>.unmodifiable(held);

  final List<String> ids;
  final Set<String> held;

  ReconnectBatch merge(Iterable<String> more) {
    return ReconnectBatch(ids: <String>[...ids, ...more], held: held);
  }

  ReconnectBatch withHeld(Iterable<String> more) {
    final next = <String>{...held, ...more};
    return next.length == held.length
        ? this
        : ReconnectBatch(ids: ids, held: next);
  }

  bool contains(String opId) => ids.contains(opId);

  @override
  bool operator ==(Object other) {
    return other is ReconnectBatch &&
        listEquals(other.ids, ids) &&
        other.held.length == held.length &&
        other.held.containsAll(held);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(ids), held.length);

  @override
  String toString() => 'ReconnectBatch(${ids.length})';
}

class SyncSummary {
  SyncSummary({required Iterable<String> failedIds, required this.savedCount})
    : failedIds = List<String>.unmodifiable(<String>{...failedIds});

  final List<String> failedIds;
  final int savedCount;

  int get failedCount => failedIds.length;

  SyncSummary merge(Iterable<String> failed, int saved) {
    return SyncSummary(
      failedIds: <String>[...failedIds, ...failed],
      savedCount: savedCount + saved,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncSummary &&
        other.savedCount == savedCount &&
        listEquals(other.failedIds, failedIds);
  }

  @override
  int get hashCode => Object.hash(savedCount, Object.hashAll(failedIds));

  @override
  String toString() => 'SyncSummary($failedCount failed, $savedCount saved)';
}
