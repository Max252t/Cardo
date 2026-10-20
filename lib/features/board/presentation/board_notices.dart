import 'package:flutter/foundation.dart';

import '../domain/board_sync_state.dart';

@immutable
class BoardNotice {
  const BoardNotice({
    required this.opId,
    required this.rejection,
    required this.retrying,
    this.actorName,
  });

  final String opId;
  final OpRejection rejection;
  final bool retrying;
  final String? actorName;

  @override
  bool operator ==(Object other) {
    return other is BoardNotice &&
        other.opId == opId &&
        other.rejection == rejection &&
        other.retrying == retrying &&
        other.actorName == actorName;
  }

  @override
  int get hashCode => Object.hash(opId, rejection, retrying, actorName);
}

const OpRejection _internal = OpRejection(reason: NackReason.internal);

List<BoardNotice> noticesBetween(
  BoardSyncState? previous,
  BoardSyncState next,
) {
  final before = <String, PendingOp>{
    for (final item in previous?.pending ?? const <PendingOp>[])
      item.opId: item,
  };
  final notices = <BoardNotice>[];
  for (final item in next.pending) {
    final old = before[item.opId];
    final rejection = item.rejection;
    if (item.isRejected && rejection != null && !(old?.isRejected ?? false)) {
      final actorId = rejection.actorId;
      notices.add(
        BoardNotice(
          opId: item.opId,
          rejection: rejection,
          retrying: false,
          actorName: actorId == null
              ? null
              : next.view.memberById(actorId)?.name,
        ),
      );
    } else if (!item.isRejected &&
        item.failedAttempts > (old?.failedAttempts ?? 0)) {
      notices.add(
        BoardNotice(opId: item.opId, rejection: _internal, retrying: true),
      );
    }
  }
  return notices;
}
