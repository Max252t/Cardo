import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_sync_state.dart';
import '../board_notices.dart';
import '../board_providers.dart';
import '../card_drafts.dart';
import 'board_snackbar.dart';

class BoardNoticesListener extends ConsumerStatefulWidget {
  const BoardNoticesListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BoardNoticesListener> createState() =>
      _BoardNoticesListenerState();
}

class _BoardNoticesListenerState extends ConsumerState<BoardNoticesListener> {
  final List<LostDraft> _shown = <LostDraft>[];

  @override
  Widget build(BuildContext context) {
    ref.listen<BoardSyncState>(boardNotifierProvider, _onBoard);
    ref.listen<List<LostDraft>>(lostDraftProvider, (previous, next) {
      _showLost(next);
    });
    return widget.child;
  }

  void _onBoard(BoardSyncState? previous, BoardSyncState next) {
    final notices = noticesBetween(previous, next);
    if (notices.isEmpty) {
      return;
    }
    final notice = notices.last;
    showBoardSnackbar(
      context,
      message: nackMessage(
        AppLocalizations.of(context),
        notice.rejection,
        actorName: notice.actorName,
        retrying: notice.retrying,
        column: notice.column,
      ),
      withDismiss: nackHasDismiss(notice.rejection.reason),
      replaceCurrent: _shown.isEmpty,
    );
  }

  void _showLost(List<LostDraft> drafts) {
    final l10n = AppLocalizations.of(context);
    for (final lost in drafts) {
      if (_shown.contains(lost)) {
        continue;
      }
      final controller = showBoardSnackbar(
        context,
        message: switch (lost.reason) {
          LostDraftReason.archived => l10n.cardDraftLostArchived,
          LostDraftReason.createRejected => l10n.cardDraftLostCreateRejected,
        },
        actionLabel: l10n.cardDraftLostCopy,
        onAction: () =>
            unawaited(Clipboard.setData(ClipboardData(text: lost.text))),
        replaceCurrent: false,
        duration: CardoDurations.lostDraftSnackbar,
      );
      if (controller == null) {
        continue;
      }
      _shown.add(lost);
      unawaited(controller.closed.then((_) => _onLostClosed(lost)));
    }
  }

  void _onLostClosed(LostDraft lost) {
    _shown.remove(lost);
    if (!mounted) {
      return;
    }
    ref.read(lostDraftProvider.notifier).remove(lost);
  }
}
