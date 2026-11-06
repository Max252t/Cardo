import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/boards_api.dart';
import '../data/dio_boards_api.dart';
import '../domain/board_info.dart';

final boardsApiProvider = Provider<BoardsApi>(
  (ref) => DioBoardsApi(ref.watch(dioProvider)),
);

class BoardsListNotifier
    extends AsyncNotifier<Result<List<BoardInfo>, ApiFailure>> {
  @override
  Future<Result<List<BoardInfo>, ApiFailure>> build() {
    ref.watch(sessionUserProvider.select((user) => user?.id));
    return ref.watch(boardsApiProvider).listBoards();
  }

  Future<void> reload() async {
    final result = await ref.read(boardsApiProvider).listBoards();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData(result);
  }

  Future<void> refreshSilently() async {
    if (state.isLoading) {
      return;
    }
    final result = await ref.read(boardsApiProvider).listBoards();
    if (!ref.mounted) {
      return;
    }
    if (result is Success<List<BoardInfo>, ApiFailure>) {
      state = AsyncData(result);
    }
  }
}

final boardsListProvider =
    AsyncNotifierProvider.autoDispose<
      BoardsListNotifier,
      Result<List<BoardInfo>, ApiFailure>
    >(BoardsListNotifier.new);
