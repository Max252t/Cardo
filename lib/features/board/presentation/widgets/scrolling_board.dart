import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/dashed_border.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_drag_controller.dart';
import '../board_providers.dart';
import 'board_card_item.dart';
import 'board_column.dart';
import 'board_snackbar.dart';
import 'drag_edge.dart';

class ScrollingBoard extends ConsumerStatefulWidget {
  const ScrollingBoard({
    super.key,
    required this.dense,
    required this.onCardTap,
  });

  final bool dense;
  final ValueChanged<String> onCardTap;

  @override
  ConsumerState<ScrollingBoard> createState() => _ScrollingBoardState();
}

class _ScrollingBoardState extends ConsumerState<ScrollingBoard> {
  final ScrollController _controller = ScrollController();
  Timer? _ticker;
  int _direction = 0;

  late final CardDragHooks _hooks = CardDragHooks(
    onUpdate: _onDragUpdate,
    onEnd: _stop,
  );

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(Offset global) {
    if (!mounted || ref.read(boardDragProvider) == null) {
      return;
    }
    final direction = edgeDirectionWithin(
      context,
      global,
      CardoLayout.of(context).autoScrollEdge,
    );
    if (direction == null || direction == _direction) {
      return;
    }
    _direction = direction;
    _ticker?.cancel();
    _ticker = null;
    if (direction != 0) {
      final step = CardoLayout.of(context).autoScrollStep;
      _ticker = Timer.periodic(
        CardoMotion.of(context).autoScrollTick,
        (timer) => _scrollBy(step * _direction),
      );
    }
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      _controller.jumpTo(target);
    }
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _direction = 0;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BoardDragState?>(boardDragProvider, (previous, next) {
      if (next == null) {
        _stop();
      }
    });
    final columns = ref.watch(boardColumnsProvider);
    final canEdit = ref.watch(canEditBoardProvider);
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final dense = widget.dense;
    final models = [for (final column in columns) column.column];
    final horizontal = dense ? spacing.screenDesktop : spacing.screen;
    final vertical = dense ? layout.columnsPaddingVertical : spacing.lg;
    final columnWidth = layout.columnWidthFor(dense: dense);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(0.0, constraints.maxHeight - vertical * 2);
        return Scrollbar(
          controller: _controller,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: dense ? spacing.columnGapDense : spacing.columnGap,
                children: <Widget>[
                  for (final column in columns)
                    SizedBox(
                      width: columnWidth,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: BoardColumnView(
                          key: ValueKey<String>(column.column.id),
                          data: column,
                          columns: models,
                          dense: dense,
                          fill: false,
                          canEdit: canEdit,
                          hooks: _hooks,
                          onCardTap: widget.onCardTap,
                        ),
                      ),
                    ),
                  if (canEdit) const AddColumnButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AddColumnButton extends StatelessWidget {
  const AddColumnButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(layout.addColumnRadius);
    return Semantics(
      button: true,
      label: l10n.boardAddColumnSemantic,
      child: ExcludeSemantics(
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(
            color: colors.outlineMuted,
            strokeWidth: sizes.emphasisBorder,
            radius: layout.addColumnRadius,
            dashLength: sizes.dashLength,
            gapLength: sizes.dashGap,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => showComingSoon(context),
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: layout.addColumnWidth,
                  maxWidth: layout.addColumnWidth,
                  minHeight: layout.addColumnHeight,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: spacing.sm,
                    children: <Widget>[
                      Icon(
                        LucideIcons.plus,
                        size: layout.iconDense,
                        color: colors.textSoft,
                      ),
                      Flexible(
                        child: Text(
                          l10n.boardAddColumn,
                          style: typography.buttonCompact.copyWith(
                            color: colors.textSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
