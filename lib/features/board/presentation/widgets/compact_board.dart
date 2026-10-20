import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_drag_controller.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import 'board_card_item.dart';
import 'board_column.dart';
import 'board_header.dart';
import 'column_tabs.dart';
import 'compact_board_parts.dart';
import 'drag_edge.dart';

class CompactBoard extends ConsumerStatefulWidget {
  const CompactBoard({super.key, required this.onCardTap});

  final ValueChanged<String> onCardTap;

  @override
  ConsumerState<CompactBoard> createState() => _CompactBoardState();
}

class _CompactBoardState extends ConsumerState<CompactBoard> {
  PageController? _controller;
  int _page = 0;
  int _flipDirection = 0;
  Timer? _flipTimer;

  late final CardDragHooks _hooks = CardDragHooks(
    onUpdate: _onDragUpdate,
    onEnd: _onDragEnd,
  );

  @override
  void dispose() {
    _flipTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  PageController _controllerFor(double fraction) {
    final current = _controller;
    if (current != null && current.viewportFraction == fraction) {
      return current;
    }
    final next = PageController(initialPage: _page, viewportFraction: fraction);
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    _controller = next;
    return next;
  }

  void _goTo(int page) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final motion = CardoMotion.of(context);
    final duration = resolveMotion(context, motion.reorder);
    if (duration == Duration.zero) {
      controller.jumpToPage(page);
    } else {
      unawaited(
        controller.animateToPage(
          page,
          duration: duration,
          curve: motion.reorderCurve,
        ),
      );
    }
  }

  void _onDragUpdate(Offset global) {
    if (!mounted || ref.read(boardDragProvider) == null) {
      return;
    }
    final direction = edgeDirectionWithin(
      context,
      global,
      CardoLayout.of(context).pageFlipEdge,
    );
    if (direction == null || direction == _flipDirection) {
      return;
    }
    _flipTimer?.cancel();
    _flipTimer = null;
    _flipDirection = direction;
    if (direction != 0) {
      _armFlip();
    }
  }

  void _armFlip() {
    _flipTimer = Timer(CardoMotion.of(context).dragEdgeHold, _flip);
  }

  void _flip() {
    _flipTimer = null;
    if (!mounted || _flipDirection == 0) {
      return;
    }
    final count = ref.read(boardColumnsProvider).length;
    final target = math.max(0, math.min(_page + _flipDirection, count - 1));
    if (target != _page) {
      _goTo(target);
      _armFlip();
    }
  }

  void _onDragEnd() {
    _flipTimer?.cancel();
    _flipTimer = null;
    _flipDirection = 0;
  }

  double _fractionFor(BuildContext context, double width) {
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final columnWidth = math.max(
      0.0,
      math.min(layout.columnWidth, width - spacing.screen * 3),
    );
    final pageWidth = columnWidth + spacing.screen;
    return width <= 0 ? 1.0 : math.min(1.0, pageWidth / width);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BoardDragState?>(boardDragProvider, (previous, next) {
      if (next == null) {
        _onDragEnd();
      }
    });
    final columns = ref.watch(boardColumnsProvider);
    final canEdit = ref.watch(canEditBoardProvider);
    final page = columns.isEmpty ? 0 : _page.clamp(0, columns.length - 1);
    return BoundedHeaderLayout(
      header: CompactBoardHeader(
        bottom: ColumnTabs(
          columns: columns,
          selectedIndex: page,
          onSelected: _goTo,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => CompactColumnPager(
          controller: _controllerFor(
            _fractionFor(context, constraints.maxWidth),
          ),
          columns: columns,
          page: page,
          canEdit: canEdit,
          hooks: _hooks,
          onCardTap: widget.onCardTap,
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ),
    );
  }
}

class CompactColumnPager extends StatelessWidget {
  const CompactColumnPager({
    super.key,
    required this.controller,
    required this.columns,
    required this.page,
    required this.canEdit,
    required this.hooks,
    required this.onCardTap,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<ColumnViewData> columns;
  final int page;
  final bool canEdit;
  final CardDragHooks hooks;
  final ValueChanged<String> onCardTap;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final models = [for (final column in columns) column.column];
    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(top: spacing.lg),
          child: PageView.builder(
            controller: controller,
            padEnds: false,
            itemCount: columns.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) => KeepAlivePage(
              key: ValueKey<String>(columns[index].column.id),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: spacing.screen),
                child: BoardColumnView(
                  data: columns[index],
                  columns: models,
                  dense: false,
                  fill: true,
                  canEdit: canEdit,
                  hooks: hooks,
                  onCardTap: onCardTap,
                  bottomInset: layout.fadeHeight,
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          height: layout.fadeHeight,
          child: const IgnorePointer(child: BottomFade()),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: layout.pageDotBottom,
          child: Center(
            child: PageDots(count: columns.length, index: page),
          ),
        ),
      ],
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }
    final colors = CardoColors.of(context);
    final layout = CardoLayout.of(context);
    final radius = BorderRadius.circular(layout.pageDot / 2);
    return Semantics(
      label: AppLocalizations.of(context).boardPageIndicator(index + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: layout.pageDotGap,
          children: <Widget>[
            for (var i = 0; i < count; i++)
              Container(
                width: i == index ? layout.pageDotActive : layout.pageDot,
                height: layout.pageDot,
                decoration: BoxDecoration(
                  color: i == index ? colors.emphasis : colors.outlineMuted,
                  borderRadius: radius,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
