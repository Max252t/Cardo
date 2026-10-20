import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/realtime/connection_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/avatar_identity.dart';
import '../../../../shared/widgets/avatar_stack.dart';
import '../../../../shared/widgets/connection_pill.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import 'board_header_actions.dart';
import 'board_snackbar.dart';

class BoardTitle extends ConsumerWidget {
  const BoardTitle({super.key, required this.large});

  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final title = ref.watch(boardViewProvider.select((board) => board.title));
    return Semantics(
      header: true,
      child: Text(
        title,
        style: (large ? typography.titleLarge : typography.title).copyWith(
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class CompactBoardHeader extends ConsumerWidget {
  const CompactBoardHeader({super.key, this.bottom});

  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final canEdit = ref.watch(canEditBoardProvider);
    final banner = bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(
          bottom: BorderSide(color: colors.line, width: sizes.hairline),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.md,
            end: spacing.md,
            top: layout.headerPaddingTop,
            bottom: spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.md,
            children: <Widget>[
              const CompactHeaderBar(),
              if (!canEdit) const ViewerBanner(),
              ?banner,
            ],
          ),
        ),
      ),
    );
  }
}

class CompactHeaderBar extends ConsumerWidget {
  const CompactHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final connection = ref.watch(
      boardNotifierProvider.select((state) => state.connection),
    );
    final canEdit = ref.watch(canEditBoardProvider);
    final userId = ref.watch(currentUserProvider).userId;
    final others = <AvatarIdentity>[
      for (final member in ref.watch(onlineMembersProvider))
        if (member.userId != userId) identityOf(member),
    ];
    return Row(
      spacing: spacing.xs,
      children: <Widget>[
        IconButton(
          tooltip: l10n.boardBack,
          onPressed: () => showComingSoon(context),
          iconSize: layout.iconHeader,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BoardTitle(large: false),
              SizedBox(height: spacing.xxs),
              ConnectionPill(
                status: connection,
                variant: ConnectionPillVariant.compact,
              ),
            ],
          ),
        ),
        AvatarStack(
          people: others,
          diameter: sizes.avatarPresence,
          overlap: sizes.avatarOverlap,
          ringWidth: sizes.avatarRing,
          ringColor: colors.surface,
        ),
        if (canEdit)
          IconButton(
            tooltip: l10n.boardMenu,
            onPressed: () => showComingSoon(context),
            iconSize: layout.iconHeader,
            icon: const Icon(LucideIcons.ellipsis),
          )
        else
          SizedBox(width: spacing.sm),
      ],
    );
  }
}

class ExpandedBoardHeader extends ConsumerWidget {
  const ExpandedBoardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final canEdit = ref.watch(canEditBoardProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          bottom: BorderSide(color: colors.line, width: sizes.hairline),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.screenDesktop,
          vertical: layout.boardHeaderPaddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.md,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: ExpandedHeaderTitle()),
                SizedBox(width: spacing.lg),
                Flexible(child: ExpandedHeaderActions(canEdit: canEdit)),
              ],
            ),
            if (!canEdit) const ViewerBanner(),
          ],
        ),
      ),
    );
  }
}

class ExpandedHeaderTitle extends ConsumerWidget {
  const ExpandedHeaderTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final connection = ref.watch(
      boardNotifierProvider.select((state) => state.connection),
    );
    final lastSeq = ref.watch(
      boardNotifierProvider.select((state) => state.lastSeq),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.xs,
      children: <Widget>[
        const BoardTitle(large: true),
        Wrap(
          spacing: layout.columnPaddingHorizontal,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ConnectionPill(
              status: connection,
              variant: connection == ConnectionStatus.connected
                  ? ConnectionPillVariant.compact
                  : ConnectionPillVariant.pill,
            ),
            Text(
              l10n.boardSeq(lastSeq),
              style: typography.mono.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class ExpandedHeaderActions extends ConsumerWidget {
  const ExpandedHeaderActions({super.key, required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final online = ref.watch(onlineMembersProvider);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.lg,
      runSpacing: spacing.sm,
      children: <Widget>[
        AvatarStack(
          people: <AvatarIdentity>[
            for (final member in online) identityOf(member),
          ],
          diameter: layout.boardAvatar,
          overlap: sizes.avatarOverlap,
          ringWidth: sizes.avatarRing,
        ),
        const MembersButton(),
        if (canEdit) const InviteButton(),
      ],
    );
  }
}
