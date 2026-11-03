import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/cardo_theme.dart';
import 'board_providers.dart';
import 'card_sheet_data.dart';
import 'widgets/board_header.dart';
import 'widgets/board_end_listener.dart';
import 'widgets/board_resume_listener.dart';
import 'widgets/protocol_issue_listener.dart';
import 'widgets/rejected_ops_sheet.dart';
import 'widgets/sync_summary_card.dart';
import 'widgets/board_notices_listener.dart';
import 'widgets/board_sidebar.dart';
import 'widgets/card_detail_panel.dart';
import 'widgets/card_sheet.dart';
import 'widgets/compact_board.dart';
import 'widgets/compact_board_parts.dart';
import 'widgets/scrolling_board.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = CardoLayout.of(context);
    final windowClass = layout.windowClassFor(MediaQuery.sizeOf(context).width);
    return BoardEndListener(
      child: BoardResumeListener(
        child: ProtocolIssueListener(
          child: BoardNoticesListener(
            child: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  switch (windowClass) {
                    CardoWindowClass.compact => CompactBoard(
                      onCardTap: (cardId) => _openPreview(context, ref, cardId),
                    ),
                    CardoWindowClass.medium => MediumBoardLayout(
                      onCardTap: (cardId) => _openPreview(context, ref, cardId),
                    ),
                    CardoWindowClass.expanded => const ExpandedBoardLayout(),
                  },
                  SyncSummaryOverlay(
                    onDetails: () =>
                        unawaited(_showRejected(context, ref, windowClass)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRejected(
    BuildContext context,
    WidgetRef ref,
    CardoWindowClass windowClass,
  ) async {
    final cardId = await showRejectedOps(context);
    if (cardId == null || !context.mounted) {
      return;
    }
    if (windowClass == CardoWindowClass.expanded) {
      ref.read(selectedCardIdProvider.notifier).select(cardId);
    } else {
      _openPreview(context, ref, cardId);
    }
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
