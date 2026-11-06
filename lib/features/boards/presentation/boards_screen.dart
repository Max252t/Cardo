import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar_identity.dart';
import '../../../shared/widgets/cardo_avatar.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/cardo_logo.dart';
import '../../../theme/cardo_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../invites/presentation/invite_link_dialog.dart';
import 'boards_providers.dart';
import 'widgets/boards_body.dart';

class BoardsScreen extends ConsumerStatefulWidget {
  const BoardsScreen({super.key});

  @override
  ConsumerState<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends ConsumerState<BoardsScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = CardoLayout.of(context);
    final wide =
        layout.windowClassFor(MediaQuery.sizeOf(context).width) ==
        CardoWindowClass.expanded;
    return Scaffold(
      floatingActionButton: wide ? null : const BoardsFabSlot(),
      body: SafeArea(
        child: wide
            ? BoardsWideLayout(search: _search)
            : BoardsCompactLayout(search: _search),
      ),
    );
  }
}

class BoardsCompactLayout extends StatelessWidget {
  const BoardsCompactLayout({super.key, required this.search});

  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: spacing.xl,
                end: spacing.xl,
                top: spacing.xl,
                bottom: spacing.sm,
              ),
              child: const Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CardoLogo(),
                    ),
                  ),
                  HaveLinkButton(),
                  ProfileButton(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: spacing.xl,
                end: spacing.xl,
                top: spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.md + spacing.xxs,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.boardsTitle,
                      style: typography.display.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  BoardsSearchField(controller: search),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: search,
                builder: (context, value, _) =>
                    BoardsBody(query: value.text, grid: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BoardsWideLayout extends StatelessWidget {
  const BoardsWideLayout({super.key, required this.search});

  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: BorderDirectional(
              bottom: BorderSide(color: colors.line, width: sizes.hairline),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: metrics.gridContentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.screenDesktop,
                  vertical: spacing.md,
                ),
                child: Row(
                  spacing: spacing.xl,
                  children: <Widget>[
                    const CardoLogo(),
                    const Spacer(),
                    SizedBox(
                      width: metrics.gridTileMaxExtent - spacing.xl * 3,
                      child: BoardsSearchField(controller: search),
                    ),
                    const HaveLinkButton(),
                    const ProfileButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: metrics.gridContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const BoardsWideHeadline(),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: search,
                      builder: (context, value, _) =>
                          BoardsBody(query: value.text, grid: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BoardsWideHeadline extends ConsumerWidget {
  const BoardsWideHeadline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final count = ref.watch(boardsListProvider).value?.valueOrNull?.length;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: spacing.screenDesktop,
        end: spacing.screenDesktop,
        top: spacing.section,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.sm,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.boardsTitle,
                    style: typography.display.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (count != null && count > 0)
                  Text(
                    l10n.boardsCount(count),
                    style: typography.body.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          CardoPrimaryButton(
            label: l10n.boardsNew,
            icon: LucideIcons.plus,
            large: false,
            onPressed: () => unawaited(createBoardAndOpen(context)),
          ),
        ],
      ),
    );
  }
}

class BoardsFabSlot extends ConsumerWidget {
  const BoardsFabSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsListProvider).value?.valueOrNull;
    if (boards == null || boards.isEmpty) {
      return const SizedBox.shrink();
    }
    return const BoardsFab();
  }
}

class BoardsSearchField extends StatelessWidget {
  const BoardsSearchField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final layout = CardoLayout.of(context);
    final sizes = CardoSizes.of(context);
    return Semantics(
      label: l10n.boardsSearchHint,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: typography.body.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: l10n.boardsSearchHint,
          prefixIcon: Icon(
            LucideIcons.search,
            size: layout.iconDense,
            color: colors.textSecondary,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: sizes.tapTarget,
            minHeight: sizes.tapTarget,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizes = CardoSizes.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: l10n.boardsProfile,
      excludeSemantics: true,
      onTap: () => unawaited(context.push(AppRoutes.profile)),
      child: InkResponse(
        onTap: () => unawaited(context.push(AppRoutes.profile)),
        child: CardoAvatar(
          identity: AvatarIdentity(
            name: user.displayName,
            colorHex: user.avatarColor,
          ),
          diameter: sizes.tapTarget,
        ),
      ),
    );
  }
}
