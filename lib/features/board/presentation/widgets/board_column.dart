import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../board_drag_controller.dart';
import '../board_view_data.dart';
import 'board_card_item.dart';
import 'board_column_parts.dart';

typedef ColumnDragSlice = ({String draggedId, int? hoverIndex});

ColumnDragSlice? columnDragSlice(BoardDragState? drag, String columnId) {
  if (drag == null) {
    return null;
  }
  return (
    draggedId: drag.cardId,
    hoverIndex: drag.targetColumnId == columnId ? drag.targetIndex : null,
  );
}

class BoardColumnView extends ConsumerWidget {
  const BoardColumnView({
    super.key,
    required this.data,
    required this.columns,
    required this.dense,
    required this.fill,
    required this.canEdit,
    required this.hooks,
    required this.onCardTap,
    this.bottomInset = 0,
  });

  final ColumnViewData data;
  final List<ColumnInfo> columns;
  final bool dense;
  final bool fill;
  final bool canEdit;
  final CardDragHooks hooks;
  final ValueChanged<String> onCardTap;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnId = data.column.id;
    final drag = canEdit
        ? ref.watch(
            boardDragProvider.select(
              (state) => columnDragSlice(state, columnId),
            ),
          )
        : null;
    final controller = ref.read(boardDragProvider.notifier);
    final insets = ColumnInsets.of(context, dense: dense);
    final slots = _cardSlots(
      drag: drag,
      insets: insets,
      controller: controller,
      others: <ColumnInfo>[
        for (final column in columns)
          if (column.id != columnId) column,
      ],
    );
    final header = ColumnDropTarget(
      key: const ValueKey<String>('column-header'),
      enabled: canEdit,
      onEnter: () => controller.hoverStart(columnId: columnId),
      onAccept: controller.drop,
      child: ColumnHeaderSlot(
        column: data.column,
        count: data.count,
        dense: dense,
        insets: insets,
      ),
    );
    final footer = ColumnDropTarget(
      key: const ValueKey<String>('column-footer'),
      enabled: canEdit,
      onEnter: () =>
          controller.hoverEnd(columnId: columnId, length: slots.visibleCount),
      onAccept: controller.drop,
      child: ColumnFooter(
        columnId: columnId,
        dense: dense,
        canEdit: canEdit,
        insets: insets,
        bottomInset: bottomInset,
      ),
    );
    return ColumnFrame(
      title: data.column.title,
      dense: dense,
      fill: fill,
      child: ColumnBody(
        fill: fill,
        header: header,
        items: slots.items,
        footer: footer,
      ),
    );
  }

  ({List<Widget> items, int visibleCount}) _cardSlots({
    required ColumnDragSlice? drag,
    required ColumnInsets insets,
    required BoardDragController controller,
    required List<ColumnInfo> others,
  }) {
    final columnId = data.column.id;
    final hoverIndex = drag?.hoverIndex;
    final placeholder = ColumnDropTarget(
      key: const ValueKey<String>('drop-placeholder'),
      enabled: canEdit,
      onEnter: () {},
      onAccept: controller.drop,
      child: ColumnDropPlaceholder(
        key: ValueKey<String>('placeholder-$columnId-$hoverIndex'),
        dense: dense,
        insets: insets,
      ),
    );
    final items = <Widget>[];
    var visibleIndex = 0;
    for (final card in data.cards) {
      final isDragged = card.card.id == drag?.draggedId;
      if (!isDragged && hoverIndex == visibleIndex) {
        items.add(placeholder);
      }
      final cardIndex = visibleIndex;
      items.add(
        ColumnDropTarget(
          key: ValueKey<String>(card.card.id),
          enabled: canEdit,
          onEnter: isDragged
              ? () {}
              : () => controller.hoverCard(
                  columnId: columnId,
                  cardIndex: cardIndex,
                ),
          onAccept: controller.drop,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: insets.horizontal,
            ),
            child: BoardCardItem(
              key: ValueKey<String>('item-${card.card.id}'),
              data: card,
              columnId: columnId,
              index: cardIndex,
              dense: dense,
              canEdit: canEdit,
              otherColumns: others,
              hooks: hooks,
              onTap: onCardTap,
              bottomGap: insets.gap,
            ),
          ),
        ),
      );
      if (!isDragged) {
        visibleIndex++;
      }
    }
    if (hoverIndex != null && hoverIndex >= visibleIndex) {
      items.add(placeholder);
    }
    return (items: items, visibleCount: visibleIndex);
  }
}
