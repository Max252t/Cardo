import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/errors/api_failure_text.dart';
import '../../../../shared/time/now_provider.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/dashed_border.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_info.dart';
import '../boards_providers.dart';
import '../new_board_dialog.dart';
import 'board_tile.dart';
import 'boards_states.dart';

Future<void> createBoardAndOpen(BuildContext context) async {
  final router = GoRouter.of(context);
  final created = await showNewBoardDialog(context);
  if (created != null) {
    router.go(AppRoutes.board(created.id));
  }
}

class BoardsBody extends ConsumerWidget {
  const BoardsBody({super.key, required this.query, required this.grid});

  final String query;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(boardsListProvider);
    Future<void> reload() => ref.refresh(boardsListProvider.future);
    return switch (async) {
      AsyncData(:final value) => switch (value) {
        Success<List<BoardInfo>, ApiFailure>(:final value) => BoardsContent(
          boards: value,
          query: query,
          grid: grid,
          onRefresh: reload,
        ),
        Failure<List<BoardInfo>, ApiFailure>(:final failure) => BoardsFailure(
          message: describeApiFailure(l10n, failure),
          onRetry: () => unawaited(reload()),
        ),
      },
      AsyncError() => BoardsFailure(
        message: l10n.errorUnknown,
        onRetry: () => unawaited(reload()),
      ),
      _ => const BoardsSkeleton(),
    };
  }
}

class BoardsFailure extends StatelessWidget {
  const BoardsFailure({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CardoErrorState(
      title: l10n.boardsLoadError,
      message: message,
      retryLabel: l10n.commonRetry,
      onRetry: onRetry,
    );
  }
}

class BoardsContent extends ConsumerWidget {
  const BoardsContent({
    super.key,
    required this.boards,
    required this.query,
    required this.grid,
    required this.onRefresh,
  });

  final List<BoardInfo> boards;
  final String query;
  final bool grid;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    if (boards.isEmpty) {
      return BoardsEmpty(
        onCreate: () => unawaited(createBoardAndOpen(context)),
      );
    }
    final needle = query.trim().toLowerCase();
    final visible = <BoardInfo>[
      for (final board in boards)
        if (needle.isEmpty || board.title.toLowerCase().contains(needle)) board,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final now = ref.watch(nowProvider)();
    void open(BoardInfo board) => context.go(AppRoutes.board(board.id));
    final Widget scroll;
    if (visible.isEmpty) {
      scroll = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.all(spacing.section),
        children: <Widget>[
          Text(
            l10n.boardsNoResults,
            textAlign: TextAlign.center,
            style: typography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    } else if (grid) {
      final tileHeight = MediaQuery.textScalerOf(context)
          .scale(metrics.gridTileHeight);
      scroll = GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.screenDesktop,
          vertical: spacing.lg,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: metrics.gridTileMaxExtent,
          mainAxisExtent: tileHeight,
          crossAxisSpacing: spacing.xl,
          mainAxisSpacing: spacing.xl,
        ),
        itemCount: visible.length + 1,
        itemBuilder: (context, index) => index == visible.length
            ? NewBoardTile(onTap: () => unawaited(createBoardAndOpen(context)))
            : BoardTile(
                board: visible[index],
                now: now,
                onTap: () => open(visible[index]),
              ),
      );
    } else {
      scroll = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          start: spacing.screen + spacing.xs,
          end: spacing.screen + spacing.xs,
          top: spacing.lg,
          bottom: metrics.fabHeight + spacing.section * 2,
        ),
        itemCount: visible.length,
        separatorBuilder: (context, index) => SizedBox(height: spacing.md),
        itemBuilder: (context, index) => BoardTile(
          board: visible[index],
          now: now,
          onTap: () => open(visible[index]),
        ),
      );
    }
    return RefreshIndicator(onRefresh: onRefresh, child: scroll);
  }
}

class NewBoardTile extends StatelessWidget {
  const NewBoardTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final layout = CardoLayout.of(context);
    final radii = CardoRadii.of(context);
    final radius = BorderRadius.circular(radii.columnDense);
    return Semantics(
      button: true,
      label: l10n.boardsEmptyAction,
      onTap: onTap,
      excludeSemantics: true,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: colors.lineStrong,
          strokeWidth: sizes.emphasisBorder,
          radius: radii.columnDense,
          dashLength: sizes.dashLength,
          gapLength: sizes.dashGap,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.sm,
              children: <Widget>[
                Icon(
                  LucideIcons.plus,
                  size: layout.iconHeader,
                  color: colors.textSoft,
                ),
                Flexible(
                  child: Text(
                    l10n.boardsEmptyAction,
                    textAlign: TextAlign.center,
                    style: typography.button.copyWith(color: colors.textSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BoardsFab extends StatelessWidget {
  const BoardsFab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shadows = Theme.of(context).extension<CardoShadows>();
    final radii = CardoRadii.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radii.button),
        boxShadow: shadows?.fab,
      ),
      child: CardoPrimaryButton(
        label: l10n.boardsNew,
        icon: LucideIcons.plus,
        large: false,
        onPressed: () => unawaited(createBoardAndOpen(context)),
      ),
    );
  }
}
