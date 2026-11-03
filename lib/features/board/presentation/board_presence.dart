import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_session.dart';
import 'board_providers.dart';

class BoardPresenceNotifier extends Notifier<BoardPresence> {
  @override
  BoardPresence build() => ref.watch(boardSnapshotProvider).presence;

  void replace(List<PresenceUser> users) {
    final ids = <String>[];
    for (final user in users) {
      if (!ids.contains(user.userId)) {
        ids.add(user.userId);
      }
    }
    _set(ids);
  }

  void join(PresenceUser user) {
    if (state.onlineUserIds.contains(user.userId)) {
      return;
    }
    _set(<String>[...state.onlineUserIds, user.userId]);
  }

  void leave(String userId) {
    if (!state.onlineUserIds.contains(userId)) {
      return;
    }
    _set(<String>[
      for (final id in state.onlineUserIds)
        if (id != userId) id,
    ]);
  }

  void clear() => _set(const <String>[]);

  void _set(List<String> ids) {
    final next = state.withOnline(ids);
    if (next != state) {
      state = next;
    }
  }
}
