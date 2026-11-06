import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../boards/presentation/boards_providers.dart';
import 'board_settings_providers.dart';
import 'self_exit.dart';

enum SettingsAction { rename, delete, leave }

@immutable
class BoardSettingsState {
  const BoardSettingsState({this.busy, this.failedAction, this.failure});

  final SettingsAction? busy;
  final SettingsAction? failedAction;
  final ApiFailure? failure;

  @override
  bool operator ==(Object other) {
    return other is BoardSettingsState &&
        other.busy == busy &&
        other.failedAction == failedAction &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(busy, failedAction, failure);
}

class BoardSettingsController extends Notifier<BoardSettingsState> {
  @override
  BoardSettingsState build() => const BoardSettingsState();

  void dismissFailure() {
    if (state.busy == null && state.failure != null) {
      state = const BoardSettingsState();
    }
  }

  Future<bool> rename(String boardId, String title) {
    return _run(
      SettingsAction.rename,
      () => ref.read(boardSettingsApiProvider).renameBoard(boardId, title),
    );
  }

  Future<bool> delete(String boardId) {
    return _exit(
      SettingsAction.delete,
      boardId,
      () => ref.read(boardSettingsApiProvider).deleteBoard(boardId),
    );
  }

  Future<bool> leave(String boardId, String userId) {
    return _exit(
      SettingsAction.leave,
      boardId,
      () => ref.read(boardSettingsApiProvider).leaveBoard(boardId, userId),
    );
  }

  Future<bool> _exit(
    SettingsAction action,
    String boardId,
    Future<Result<void, ApiFailure>> Function() request,
  ) async {
    if (state.busy != null) {
      return false;
    }
    final selfExit = ref.read(selfExitProvider.notifier);
    selfExit.mark(boardId);
    final done = await _run(action, request);
    if (!done) {
      selfExit.clear(boardId);
    }
    return done;
  }

  Future<bool> _run(
    SettingsAction action,
    Future<Result<void, ApiFailure>> Function() request,
  ) async {
    if (state.busy != null) {
      return false;
    }
    state = BoardSettingsState(busy: action);
    final link = ref.keepAlive();
    try {
      final result = await request();
      switch (result) {
        case Success<void, ApiFailure>():
          ref.invalidate(boardsListProvider);
          state = const BoardSettingsState();
          return true;
        case Failure<void, ApiFailure>(:final failure):
          state = BoardSettingsState(failedAction: action, failure: failure);
          return false;
      }
    } finally {
      link.close();
    }
  }
}

final boardSettingsControllerProvider =
    NotifierProvider.autoDispose<BoardSettingsController, BoardSettingsState>(
      BoardSettingsController.new,
    );
