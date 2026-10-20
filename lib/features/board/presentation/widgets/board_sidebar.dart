import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_logo.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import 'board_sidebar_items.dart';

class BoardSidebar extends StatelessWidget {
  const BoardSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return Container(
      width: layout.sidebarWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(
          end: BorderSide(color: colors.line, width: sizes.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: layout.sidebarPaddingHorizontal,
                vertical: layout.sidebarPaddingVertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: layout.sidebarGap,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: spacing.sm,
                    ),
                    child: const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CardoLogo(),
                    ),
                  ),
                  const SidebarSearchField(),
                  const SidebarBoardList(),
                ],
              ),
            ),
          ),
          const SidebarProfile(),
        ],
      ),
    );
  }
}

class SidebarBoardList extends ConsumerWidget {
  const SidebarBoardList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final typography = CardoTypography.of(context);
    final boards = ref.watch(boardListProvider);
    final activeId = ref.watch(boardViewProvider.select((board) => board.id));
    final connection = ref.watch(
      boardNotifierProvider.select((state) => state.connection),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CardoLayout.of(context).sidebarItemGap,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.sm,
            end: spacing.sm,
            bottom: spacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              AppLocalizations.of(context).boardSidebarBoards.toUpperCase(),
              style: typography.overline.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        for (final board in boards)
          SidebarBoardItem(
            board: board,
            active: board.id == activeId,
            connection: board.id == activeId ? connection : null,
          ),
        const SidebarNewBoardButton(),
      ],
    );
  }
}
