import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/card_tile.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_sync_state.dart';
import '../board_drag_controller.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import 'board_snackbar.dart';

class CardDragHooks {
  const CardDragHooks({required this.onUpdate, required this.onEnd});

  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
}

CardTileState cardTileStateFor(CardSyncStatus status) {
  return switch (status) {
    CardSyncStatus.confirmed => CardTileState.confirmed,
    CardSyncStatus.pending => CardTileState.pending,
    CardSyncStatus.rejected => CardTileState.rejected,
  };
}

class BoardCardTile extends StatelessWidget {
  const BoardCardTile({
    super.key,
    required this.data,
    required this.dense,
    this.state,
    this.onTap,
  });

  final CardViewData data;
  final bool dense;
  final CardTileState? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rejection = data.rejection;
    return CardTile(
      title: data.card.title,
      state: state ?? cardTileStateFor(data.status),
      hasDescription: data.card.hasDescription,
      updatedBy: data.updatedBy,
      editingBy: data.editingBy,
      rejectReason: rejection == null
          ? null
          : nackMessage(l10n, rejection, actorName: data.rejectionActorName),
      dense: dense,
      onTap: onTap,
    );
  }
}

class BoardCardItem extends ConsumerWidget {
  const BoardCardItem({
    super.key,
    required this.data,
    required this.columnId,
    required this.index,
    required this.dense,
    required this.canEdit,
    required this.otherColumns,
    required this.hooks,
    required this.onTap,
    required this.bottomGap,
  });

  final CardViewData data;
  final String columnId;
  final int index;
  final bool dense;
  final bool canEdit;
  final List<ColumnInfo> otherColumns;
  final CardDragHooks hooks;
  final ValueChanged<String> onTap;
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cardId = data.card.id;
    final draggable = canEdit && data.status != CardSyncStatus.rejected;
    final tile = MergeSemantics(
      child: Semantics(
        hint: draggable ? l10n.cardDragHint : null,
        customSemanticsActions: draggable
            ? <CustomSemanticsAction, VoidCallback>{
                for (final column in otherColumns)
                  CustomSemanticsAction(
                    label: l10n.cardMoveTo(column.title),
                  ): () => ref
                      .read(boardNotifierProvider.notifier)
                      .moveCardToColumnEnd(
                        cardId: cardId,
                        toColumnId: column.id,
                      ),
              }
            : null,
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: bottomGap),
          child: BoardCardTile(
            data: data,
            dense: dense,
            onTap: () => onTap(cardId),
          ),
        ),
      ),
    );
    if (!draggable) {
      return tile;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final drag = ref.read(boardDragProvider.notifier);
        return LongPressDraggable<CardDragData>(
          data: CardDragData(cardId: cardId, fromColumnId: columnId),
          feedback: CardDragFeedback(
            data: data,
            dense: dense,
            width: constraints.maxWidth,
          ),
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () =>
              drag.start(cardId: cardId, columnId: columnId, index: index),
          onDragUpdate: (details) => hooks.onUpdate(details.globalPosition),
          onDragEnd: (details) {
            hooks.onEnd();
            drag.cancel();
          },
          onDragCompleted: hooks.onEnd,
          onDraggableCanceled: (velocity, offset) {
            hooks.onEnd();
            drag.cancel();
          },
          child: tile,
        );
      },
    );
  }
}

class CardDragFeedback extends StatelessWidget {
  const CardDragFeedback({
    super.key,
    required this.data,
    required this.dense,
    required this.width,
  });

  final CardViewData data;
  final bool dense;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: BoardCardTile(
        data: data,
        dense: dense,
        state: CardTileState.dragging,
      ),
    );
  }
}

class GrowIn extends StatelessWidget {
  const GrowIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = CardoMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: resolveMotion(context, motion.reorder),
      curve: motion.reorderCurve,
      child: child,
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: value,
            child: child,
          ),
        );
      },
    );
  }
}
