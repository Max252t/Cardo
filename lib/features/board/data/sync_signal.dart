import '../../../core/realtime/connection_status.dart';
import '../domain/board_event.dart';
import '../domain/board_model.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';

sealed class SyncSignal {
  const SyncSignal();
}

final class ConnectionSignal extends SyncSignal {
  const ConnectionSignal(this.status, {this.reconnectSeconds});

  final ConnectionStatus status;
  final int? reconnectSeconds;

  @override
  bool operator ==(Object other) {
    return other is ConnectionSignal &&
        other.status == status &&
        other.reconnectSeconds == reconnectSeconds;
  }

  @override
  int get hashCode => Object.hash(status, reconnectSeconds);

  @override
  String toString() => 'ConnectionSignal(${status.name}, $reconnectSeconds)';
}

final class ReadySignal extends SyncSignal {
  const ReadySignal();

  @override
  bool operator ==(Object other) => other is ReadySignal;

  @override
  int get hashCode => (ReadySignal).hashCode;

  @override
  String toString() => 'ReadySignal';
}

final class ResyncedSignal extends SyncSignal {
  const ResyncedSignal();

  @override
  bool operator ==(Object other) => other is ResyncedSignal;

  @override
  int get hashCode => (ResyncedSignal).hashCode;

  @override
  String toString() => 'ResyncedSignal';
}

final class EventsSignal extends SyncSignal {
  EventsSignal(List<BoardEvent> events)
    : events = List<BoardEvent>.unmodifiable(events);

  final List<BoardEvent> events;

  @override
  String toString() => 'EventsSignal(${events.length})';
}

final class DuplicatesSignal extends SyncSignal {
  DuplicatesSignal(List<String> opIds)
    : opIds = List<String>.unmodifiable(opIds);

  final List<String> opIds;

  @override
  String toString() => 'DuplicatesSignal($opIds)';
}

final class SnapshotSignal extends SyncSignal {
  const SnapshotSignal(this.board);

  final BoardModel board;

  @override
  String toString() => 'SnapshotSignal(seq ${board.seq})';
}

final class NackSignal extends SyncSignal {
  const NackSignal({required this.opId, required this.rejection});

  final String opId;
  final OpRejection rejection;

  @override
  String toString() => 'NackSignal($opId, $rejection)';
}

final class PresenceListSignal extends SyncSignal {
  PresenceListSignal(List<PresenceUser> users)
    : users = List<PresenceUser>.unmodifiable(users);

  final List<PresenceUser> users;
}

final class PresenceJoinSignal extends SyncSignal {
  const PresenceJoinSignal(this.user);

  final PresenceUser user;
}

final class PresenceLeaveSignal extends SyncSignal {
  const PresenceLeaveSignal(this.userId);

  final String userId;
}

final class EndedSignal extends SyncSignal {
  const EndedSignal(this.reason);

  final BoardEndReason reason;

  @override
  bool operator ==(Object other) =>
      other is EndedSignal && other.reason == reason;

  @override
  int get hashCode => Object.hash(EndedSignal, reason);

  @override
  String toString() => 'EndedSignal(${reason.name})';
}
