import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/board_sync_state.dart';
import '../board_providers.dart';
import 'board_snackbar.dart';

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
    final l10n = AppLocalizations.of(context);
    final title = ref.read(boardViewProvider).title;
    final message = switch (reason) {
      BoardEndReason.removed => l10n.boardEndedRemoved(title),
      BoardEndReason.boardDeleted => l10n.boardEndedDeleted(title),
      BoardEndReason.accessLost => l10n.boardEndedAccessLost,
      BoardEndReason.sessionEnded || BoardEndReason.unsupported => null,
    };
    if (message == null) {
      return;
    }
    showBoardSnackbar(context, message: message);
    ref.read(boardNavigationProvider).onBack?.call();
  }
}
