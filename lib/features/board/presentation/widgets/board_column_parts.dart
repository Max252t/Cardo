import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/card_tile.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../board_drag_controller.dart';
import 'board_card_item.dart';
import 'board_column_header.dart';

@immutable
class ColumnInsets {
  const ColumnInsets({
    required this.horizontal,
    required this.vertical,
    required this.gap,
  });

  factory ColumnInsets.of(BuildContext context, {required bool dense}) {
    final layout = CardoLayout.of(context);
    return ColumnInsets(
      horizontal: dense
          ? layout.columnPaddingDense
          : layout.columnPaddingHorizontal,
      vertical: dense
          ? layout.columnPaddingDense
          : layout.columnPaddingVertical,
      gap: CardoSpacing.of(context).cardGapFor(dense: dense),
    );
  }

  final double horizontal;
  final double vertical;
  final double gap;
}

class ColumnDropTarget extends StatelessWidget {
  const ColumnDropTarget({
    super.key,
    required this.enabled,
    required this.onEnter,
    required this.onAccept,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onEnter;
  final VoidCallback onAccept;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (details) {
        onEnter();
        return true;
      },
      onAcceptWithDetails: (details) => onAccept(),
      builder: (context, candidate, rejected) => child,
    );
  }
}

class ColumnDropPlaceholder extends StatelessWidget {
  const ColumnDropPlaceholder({
    super.key,
    required this.dense,
    required this.insets,
  });

  final bool dense;
  final ColumnInsets insets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: insets.horizontal),
      child: GrowIn(
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: insets.gap),
          child: CardDropPlaceholder(dense: dense),
        ),
      ),
    );
  }
}

class ColumnFooter extends StatelessWidget {
  const ColumnFooter({
    super.key,
    required this.columnId,
    required this.dense,
    required this.canEdit,
    required this.insets,
    required this.bottomInset,
  });

  final String columnId;
  final bool dense;
  final bool canEdit;
  final ColumnInsets insets;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: insets.horizontal,
        end: insets.horizontal,
        bottom: insets.vertical + bottomInset,
      ),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: canEdit
            ? AddCardButton(columnId: columnId, dense: dense)
            : SizedBox(height: CardoSizes.of(context).hairline),
      ),
    );
  }
}

class ColumnFrame extends StatelessWidget {
  const ColumnFrame({
    super.key,
    required this.title,
    required this.dense,
    required this.fill,
    required this.child,
  });

  final String title;
  final bool dense;
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radius = Radius.circular(
      CardoRadii.of(context).columnFor(dense: dense),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: AppLocalizations.of(context).boardColumnSemantic(title),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.column,
          border: dense
              ? Border.all(color: colors.columnBorder, width: sizes.hairline)
              : null,
          borderRadius: fill
              ? BorderRadius.vertical(top: radius)
              : BorderRadius.all(radius),
        ),
        child: child,
      ),
    );
  }
}

class ColumnHeaderSlot extends StatelessWidget {
  const ColumnHeaderSlot({
    super.key,
    required this.column,
    required this.count,
    required this.dense,
    required this.insets,
  });

  final ColumnModel column;
  final int count;
  final bool dense;
  final ColumnInsets insets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: insets.horizontal,
        end: insets.horizontal,
        top: insets.vertical,
        bottom: insets.gap,
      ),
      child: BoardColumnHeader(column: column, count: count, dense: dense),
    );
  }
}

class ColumnBody extends StatelessWidget {
  const ColumnBody({
    super.key,
    required this.fill,
    required this.header,
    required this.items,
    required this.footer,
  });

  final bool fill;
  final Widget header;
  final List<Widget> items;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    if (fill) {
      return CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: header),
          SliverList.list(children: items),
          SliverFillRemaining(hasScrollBody: false, child: footer),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[header, ...items, footer],
      ),
    );
  }
}
