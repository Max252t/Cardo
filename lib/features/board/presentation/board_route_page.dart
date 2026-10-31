import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../boards/presentation/boards_providers.dart';
import '../../boards/presentation/widgets/boards_body.dart';
import '../data/rest_board_gateway.dart';
import '../domain/board_session.dart';
import 'board_load_views.dart';
import 'board_providers.dart';
import 'board_scope.dart';
import 'board_screen.dart';

final restBoardGatewayProvider = FutureProvider.autoDispose
    .family<Result<RestBoardGateway, ApiFailure>, String>((ref, boardId) async {
      final user = ref.read(sessionUserProvider);
      if (user == null) {
        return const Failure<RestBoardGateway, ApiFailure>(
          UnauthorizedFailure(UnauthorizedKind.missing),
        );
      }
      return RestBoardGateway.load(
        api: ref.watch(boardsApiProvider),
        boardId: boardId,
        currentUser: CurrentUser(
          userId: user.id,
          name: user.displayName,
          email: user.email,
          avatarColor: user.avatarColor,
        ),
      );
    });

class BoardRoutePage extends ConsumerWidget {
  const BoardRoutePage({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    void goToList() => router.go(AppRoutes.boards);
    void retry() => ref.invalidate(restBoardGatewayProvider(boardId));
    final async = ref.watch(restBoardGatewayProvider(boardId));
    if (async.isLoading) {
      return BoardLoadingView(onBack: goToList);
    }
    return switch (async) {
      AsyncData(:final value) => switch (value) {
        Success<RestBoardGateway, ApiFailure>(:final value) => BoardScope(
          key: ObjectKey(value),
          gateway: value,
          navigation: BoardNavigation(
            onBack: goToList,
            onOpenBoard: (id) => router.go(AppRoutes.board(id)),
            onNewBoard: () => unawaited(createBoardAndOpen(context)),
            onOpenProfile: () => unawaited(router.push(AppRoutes.profile)),
          ),
          child: const BoardScreen(),
        ),
        Failure<RestBoardGateway, ApiFailure>(:final failure) =>
          BoardLoadErrorView(
            failure: failure,
            onRetry: retry,
            onBack: goToList,
          ),
      },
      AsyncError() => BoardLoadErrorView(
        failure: const UnknownFailure(),
        onRetry: retry,
        onBack: goToList,
      ),
      _ => BoardLoadingView(onBack: goToList),
    };
  }
}
