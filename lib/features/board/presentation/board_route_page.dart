import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/providers/app_config_provider.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../boards/presentation/boards_providers.dart';
import '../../boards/presentation/widgets/boards_body.dart';
import '../data/realtime/realtime_credentials.dart';
import '../data/server_board_gateway.dart';
import '../domain/board_session.dart';
import 'board_load_views.dart';
import 'board_providers.dart';
import 'board_scope.dart';
import 'board_screen.dart';
import 'realtime_providers.dart';

CurrentUser currentUserOf(User user) {
  return CurrentUser(
    userId: user.id,
    name: user.displayName,
    email: user.email,
    avatarColor: user.avatarColor,
  );
}

final sessionCurrentUserProvider = Provider<CurrentUser?>((ref) {
  final user = ref.watch(sessionUserProvider);
  return user == null ? null : currentUserOf(user);
});

final serverBoardGatewayProvider = FutureProvider.autoDispose
    .family<Result<ServerBoardGateway, ApiFailure>, String>((
      ref,
      boardId,
    ) async {
      final user = ref.read(sessionUserProvider);
      final wsBase = ref.read(appConfigProvider).wsBaseUri;
      if (user == null) {
        return const Failure<ServerBoardGateway, ApiFailure>(
          UnauthorizedFailure(UnauthorizedKind.missing),
        );
      }
      if (wsBase == null) {
        return const Failure<ServerBoardGateway, ApiFailure>(UnknownFailure());
      }
      final result = await ServerBoardGateway.load(
        api: ref.watch(boardsApiProvider),
        boardId: boardId,
        currentUser: currentUserOf(user),
        realtime: RealtimeSettings(
          transport: ref.read(realtimeTransportProvider),
          credentials: TokenManagerCredentials(ref.read(tokenManagerProvider)),
          wsBaseUri: wsBase,
          scheduler: ref.read(realtimeSchedulerProvider),
          now: ref.read(nowProvider),
          random: ref.read(realtimeRandomProvider),
        ),
      );
      if (result is Success<ServerBoardGateway, ApiFailure>) {
        final gateway = result.value;
        if (ref.mounted) {
          ref.onDispose(() => unawaited(gateway.dispose()));
        } else {
          unawaited(gateway.dispose());
        }
      }
      return result;
    });

class BoardRoutePage extends ConsumerWidget {
  const BoardRoutePage({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    void goToList() => router.go(AppRoutes.boards);
    void retry() => ref.invalidate(serverBoardGatewayProvider(boardId));
    final async = ref.watch(serverBoardGatewayProvider(boardId));
    if (async.isLoading) {
      return BoardLoadingView(onBack: goToList);
    }
    return switch (async) {
      AsyncData(:final value) => switch (value) {
        Success<ServerBoardGateway, ApiFailure>(:final value) => BoardScope(
          key: ObjectKey(value),
          gateway: value,
          liveUser: sessionCurrentUserProvider,
          navigation: BoardNavigation(
            onBack: goToList,
            onOpenBoard: (id) => router.go(AppRoutes.board(id)),
            onNewBoard: () => unawaited(createBoardAndOpen(context)),
            onOpenProfile: () => unawaited(router.push(AppRoutes.profile)),
          ),
          child: const BoardScreen(),
        ),
        Failure<ServerBoardGateway, ApiFailure>(:final failure) =>
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
