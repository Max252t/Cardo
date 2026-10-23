import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/cardo_theme.dart';
import '../domain/board_sync_state.dart';
import 'board_notices.dart';
import 'board_providers.dart';
import 'card_drafts.dart';
import 'card_sheet_data.dart';
import 'widgets/board_header.dart';
import 'widgets/board_sidebar.dart';
import 'widgets/board_snackbar.dart';
import 'widgets/card_detail_panel.dart';
import 'widgets/card_sheet.dart';
import 'widgets/compact_board.dart';
import 'widgets/compact_board_parts.dart';
import 'widgets/scrolling_board.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<BoardSyncState>(boardNotifierProvider, (previous, next) {
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
        ),
        withDismiss: nackHasDismiss(notice.rejection.reason),
      );
    });
    ref.listen<LostDraft?>(lostDraftProvider, (previous, next) {
      if (next == null) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showBoardSnackbar(
        context,
        message: l10n.cardDraftLostArchived,
        actionLabel: l10n.cardDraftLostCopy,
        onAction: () =>
            unawaited(Clipboard.setData(ClipboardData(text: next.text))),
      );
      ref.read(lostDraftProvider.notifier).clear();
    });
    final layout = CardoLayout.of(context);
    final windowClass = layout.windowClassFor(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: switch (windowClass) {
        CardoWindowClass.compact => CompactBoard(
          onCardTap: (cardId) => _openPreview(context, ref, cardId),
        ),
        CardoWindowClass.medium => MediumBoardLayout(
          onCardTap: (cardId) => _openPreview(context, ref, cardId),
        ),
        CardoWindowClass.expanded => const ExpandedBoardLayout(),
      },
    );
  }

  void _openPreview(BuildContext context, WidgetRef ref, String cardId) {
    if (ref.read(cardSheetProvider(cardId)) == null) {
      return;
    }
    unawaited(showCardSheet(context, cardId));
  }
}

class MediumBoardLayout extends StatelessWidget {
  const MediumBoardLayout({super.key, required this.onCardTap});

  final ValueChanged<String> onCardTap;

  @override
  Widget build(BuildContext context) {
    return BoundedHeaderLayout(
      header: const CompactBoardHeader(),
      body: SafeArea(
        top: false,
        child: ScrollingBoard(dense: false, onCardTap: onCardTap),
      ),
    );
  }
}

class ExpandedBoardLayout extends ConsumerWidget {
  const ExpandedBoardLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCardProvider);
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const BoardSidebar(),
          Expanded(
            child: BoundedHeaderLayout(
              header: const ExpandedBoardHeader(),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ScrollingBoard(
                      dense: true,
                      onCardTap: (cardId) => ref
                          .read(selectedCardIdProvider.notifier)
                          .select(cardId),
                    ),
                  ),
                  if (selected != null)
                    CardDetailPanel(cardId: selected.card.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
