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

final boardsListProvider =
    FutureProvider.autoDispose<Result<List<BoardInfo>, ApiFailure>>((ref) {
      ref.watch(sessionUserProvider.select((user) => user?.id));
      return ref.watch(boardsApiProvider).listBoards();
    });
