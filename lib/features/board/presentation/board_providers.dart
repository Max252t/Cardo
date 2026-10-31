import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/board_role.dart';
import '../../../shared/time/now_provider.dart';
import '../../../theme/cardo_durations.dart';
import '../data/board_gateway.dart';
import '../domain/board_model.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'board_notifier.dart';
import 'board_view_data.dart';

export '../../../shared/time/now_provider.dart';

typedef IdGenerator = String Function();

@immutable
class BoardSyncConfig {
  const BoardSyncConfig({
    this.nackHold = CardoDurations.nackHold,
    this.retryDelay = CardoDurations.syncRetryDelay,
    this.maxInternalRetries = 2,
  });

  final Duration nackHold;
  final Duration retryDelay;
  final int maxInternalRetries;

  @override
  bool operator ==(Object other) =>
      other is BoardSyncConfig &&
      other.nackHold == nackHold &&
      other.retryDelay == retryDelay &&
      other.maxInternalRetries == maxInternalRetries;

  @override
  int get hashCode => Object.hash(nackHold, retryDelay, maxInternalRetries);
}

final boardGatewayProvider = Provider<BoardGateway>(
  (ref) => throw UnimplementedError(
    'boardGatewayProvider must be overridden in ProviderScope',
  ),
);

final idGeneratorProvider = Provider<IdGenerator>((ref) => const Uuid().v7);

final tickingNowProvider = Provider.autoDispose<DateTime>((ref) {
  final value = ref.watch(nowProvider)();
  final elapsed = Duration(
    seconds: value.second,
    milliseconds: value.millisecond,
    microseconds: value.microsecond,
  );
  final timer = Timer(CardoDurations.nowTick - elapsed, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return value;
});

final boardSyncConfigProvider = Provider<BoardSyncConfig>(
  (ref) => const BoardSyncConfig(),
);

final boardSnapshotProvider = Provider<BoardSnapshot>(
  (ref) => ref.watch(boardGatewayProvider).snapshot(),
  dependencies: [boardGatewayProvider],
);

final boardNotifierProvider = NotifierProvider<BoardNotifier, BoardSyncState>(
  BoardNotifier.new,
  dependencies: [
    boardGatewayProvider,
    boardSnapshotProvider,
    currentUserProvider,
  ],
);

final boardViewProvider = Provider<BoardModel>(
  (ref) => ref.watch(boardNotifierProvider.select((state) => state.view)),
  dependencies: [boardNotifierProvider],
);

final currentUserProvider = Provider<CurrentUser>(
  (ref) => ref.watch(boardSnapshotProvider).currentUser,
  dependencies: [boardSnapshotProvider],
);

final currentRoleProvider = Provider<BoardRole>((ref) {
  final userId = ref.watch(currentUserProvider).userId;
  final member = ref.watch(boardViewProvider).memberById(userId);
  return member?.role ?? BoardRole.viewer;
}, dependencies: [currentUserProvider, boardViewProvider]);

final canEditBoardProvider = Provider<bool>(
  (ref) => ref.watch(currentRoleProvider).canEdit,
  dependencies: [currentRoleProvider],
);

final boardPresenceProvider = Provider<BoardPresence>(
  (ref) => ref.watch(boardSnapshotProvider).presence,
  dependencies: [boardSnapshotProvider],
);

final boardListProvider = Provider<List<BoardListItem>>(
  (ref) => [
    for (final summary in ref.watch(boardSnapshotProvider).boards)
      BoardListItem.of(summary),
  ],
  dependencies: [boardSnapshotProvider],
);

final boardColumnsProvider = Provider<List<ColumnViewData>>(
  (ref) {
    final state = ref.watch(boardNotifierProvider);
    final presence = ref.watch(boardPresenceProvider);
    final userId = ref.watch(currentUserProvider).userId;
    return buildColumnViewData(
      state: state,
      presence: presence,
      currentUserId: userId,
    );
  },
  dependencies: [
    boardNotifierProvider,
    boardPresenceProvider,
    currentUserProvider,
  ],
);

final onlineMembersProvider = Provider<List<BoardMember>>((ref) {
  final presence = ref.watch(boardPresenceProvider);
  final board = ref.watch(boardViewProvider);
  return <BoardMember>[
    for (final userId in presence.onlineUserIds) ?board.memberById(userId),
  ];
}, dependencies: [boardPresenceProvider, boardViewProvider]);

class SelectedCardNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String cardId) => state = cardId;

  void clear() => state = null;
}

final selectedCardIdProvider = NotifierProvider<SelectedCardNotifier, String?>(
  SelectedCardNotifier.new,
  dependencies: [boardGatewayProvider],
);

final selectedCardProvider = Provider<CardViewData?>((ref) {
  final id = ref.watch(selectedCardIdProvider);
  if (id == null) {
    return null;
  }
  for (final column in ref.watch(boardColumnsProvider)) {
    for (final card in column.cards) {
      if (card.card.id == id) {
        return card;
      }
    }
  }
  return null;
}, dependencies: [selectedCardIdProvider, boardColumnsProvider]);

@immutable
class BoardNavigation {
  const BoardNavigation({
    this.onBack,
    this.onOpenBoard,
    this.onNewBoard,
    this.onOpenProfile,
  });

  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenBoard;
  final VoidCallback? onNewBoard;
  final VoidCallback? onOpenProfile;
}

final boardNavigationProvider = Provider<BoardNavigation>(
  (ref) => const BoardNavigation(),
);
