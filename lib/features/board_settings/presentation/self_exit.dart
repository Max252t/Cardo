import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/time/now_provider.dart';
import '../../../theme/cardo_durations.dart';

class SelfExitNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const <String, DateTime>{};

  void mark(String boardId) {
    state = <String, DateTime>{...state, boardId: ref.read(nowProvider)()};
  }

  void clear(String boardId) {
    if (!state.containsKey(boardId)) {
      return;
    }
    state = <String, DateTime>{...state}..remove(boardId);
  }

  void reset() {
    if (state.isNotEmpty) {
      state = const <String, DateTime>{};
    }
  }

  bool isRecent(String boardId) {
    final markedAt = state[boardId];
    if (markedAt == null) {
      return false;
    }
    final age = ref.read(nowProvider)().difference(markedAt);
    return age < CardoDurations.selfExitWindow;
  }
}

final selfExitProvider =
    NotifierProvider<SelfExitNotifier, Map<String, DateTime>>(
      SelfExitNotifier.new,
    );
