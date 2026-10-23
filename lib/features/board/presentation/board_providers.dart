import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/board_role.dart';
import '../../../theme/cardo_durations.dart';
import '../data/board_gateway.dart';
import '../domain/board_model.dart';
import '../domain/board_session.dart';
import '../domain/board_sync_state.dart';
import 'board_notifier.dart';
import 'board_view_data.dart';

typedef IdGenerator = String Function();
typedef NowProvider = DateTime Function();

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

final nowProvider = Provider<NowProvider>((ref) => DateTime.now);

final boardSyncConfigProvider = Provider<BoardSyncConfig>(
  (ref) => const BoardSyncConfig(),
);

final boardSnapshotProvider = Provider<BoardSnapshot>(
  (ref) => ref.watch(boardGatewayProvider).snapshot(),
);

final boardNotifierProvider = NotifierProvider<BoardNotifier, BoardSyncState>(
  BoardNotifier.new,
);

final boardViewProvider = Provider<BoardModel>(
  (ref) => ref.watch(boardNotifierProvider.select((state) => state.view)),
);

final currentUserProvider = Provider<CurrentUser>(
  (ref) => ref.watch(boardSnapshotProvider).currentUser,
);

final currentRoleProvider = Provider<BoardRole>((ref) {
  final userId = ref.watch(currentUserProvider).userId;
  final member = ref.watch(boardViewProvider).memberById(userId);
  return member?.role ?? BoardRole.viewer;
});

final canEditBoardProvider = Provider<bool>(
  (ref) => ref.watch(currentRoleProvider).canEdit,
);

final boardPresenceProvider = Provider<BoardPresence>(
  (ref) => ref.watch(boardSnapshotProvider).presence,
);

final boardListProvider = Provider<List<BoardListItem>>(
  (ref) => [
    for (final summary in ref.watch(boardSnapshotProvider).boards)
      BoardListItem.of(summary),
  ],
);

final boardColumnsProvider = Provider<List<ColumnViewData>>((ref) {
  final state = ref.watch(boardNotifierProvider);
  final presence = ref.watch(boardPresenceProvider);
  final userId = ref.watch(currentUserProvider).userId;
  return buildColumnViewData(
    state: state,
    presence: presence,
    currentUserId: userId,
  );
});

final onlineMembersProvider = Provider<List<BoardMember>>((ref) {
  final presence = ref.watch(boardPresenceProvider);
  final board = ref.watch(boardViewProvider);
  return <BoardMember>[
    for (final userId in presence.onlineUserIds) ?board.memberById(userId),
  ];
});

class SelectedCardNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String cardId) => state = cardId;

  void clear() => state = null;
}

final selectedCardIdProvider = NotifierProvider<SelectedCardNotifier, String?>(
  SelectedCardNotifier.new,
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
});
