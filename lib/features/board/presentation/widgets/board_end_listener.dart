import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boards/presentation/boards_providers.dart';
import '../../../board_settings/presentation/self_exit.dart';
import '../../domain/board_sync_state.dart';
import '../board_providers.dart';
import '../sync_views.dart';
import 'board_ended_dialog.dart';

class BoardEndListener extends ConsumerWidget {
  const BoardEndListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<BoardEndReason?>(
      boardNotifierProvider.select((state) => state.ended),
      (previous, next) {
        if (next != null && previous != next) {
          _leave(context, ref, next);
        }
      },
    );
    return child;
  }

  void _leave(BuildContext context, WidgetRef ref, BoardEndReason reason) {
    if (reason == BoardEndReason.sessionEnded ||
        reason == BoardEndReason.unsupported) {
      return;
    }
    final boardId = ref.read(boardViewProvider).id;
    if (ref.read(selfExitProvider.notifier).isRecent(boardId)) {
      return;
    }
    final onBack = ref.read(boardNavigationProvider).onBack;
    unawaited(
      showBoardEndedDialog(
        context,
        reason: reason,
        boardTitle: ref.read(boardViewProvider).title,
        unsaved: ref.read(unsavedTextsProvider),
        onLeave: () {
          ref.invalidate(boardsListProvider);
          onBack?.call();
        },
      ),
    );
  }
}
