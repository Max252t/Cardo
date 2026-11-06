import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../theme/cardo_theme.dart';
import '../../board/presentation/board_providers.dart';
import 'members_controller.dart';
import 'members_texts.dart';
import 'members_view_data.dart';
import 'widgets/add_member_form.dart';
import 'widgets/invites_section.dart';
import 'widgets/member_row.dart';

Future<void> showMembers(BuildContext context, {bool focusInvites = false}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final expanded =
      CardoLayout.of(context)
          .windowClassFor(MediaQuery.sizeOf(context).width) ==
      CardoWindowClass.expanded;
  if (expanded) {
    return showDialog<void>(
      context: context,
      builder: (context) => UncontrolledProviderScope(
        container: container,
        child: MembersDialog(focusInvites: focusInvites),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: BoxConstraints(
      maxWidth: CardoSizes.of(context).previewMaxWidth,
    ),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: MembersSheet(focusInvites: focusInvites),
    ),
  );
}

class MembersSheet extends StatelessWidget {
  const MembersSheet({super.key, required this.focusInvites});

  final bool focusInvites;

  @override
  Widget build(BuildContext context) {
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final colors = CardoColors.of(context);
    final height = MediaQuery.sizeOf(context).height - layout.sheetTopInset;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: spacing.xl,
          end: spacing.xl,
          top: layout.sheetPaddingTop,
          bottom:
              layout.sheetPaddingBottom +
              MediaQuery.viewPaddingOf(context).bottom +
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: layout.panelGap,
          children: <Widget>[
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: sizes.sheetHandleWidth,
                  height: sizes.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: BorderRadius.circular(
                      CardoRadii.of(context).pill,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: MembersPanel(fill: true, focusInvites: focusInvites),
            ),
          ],
        ),
      ),
    );
  }
}

class MembersDialog extends StatelessWidget {
  const MembersDialog({super.key, required this.focusInvites});

  final bool focusInvites;

  @override
  Widget build(BuildContext context) {
    final form = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(form.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: form.dialogMaxWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.section - spacing.xs),
          child: MembersPanel(fill: false, focusInvites: focusInvites),
        ),
      ),
    );
  }
}

class MembersPanel extends ConsumerStatefulWidget {
  const MembersPanel({
    super.key,
    required this.fill,
    required this.focusInvites,
  });

  final bool fill;
  final bool focusInvites;

  @override
  ConsumerState<MembersPanel> createState() => _MembersPanelState();
}

class _MembersPanelState extends ConsumerState<MembersPanel> {
  final GlobalKey _invitesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusInvites) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _invitesKey.currentContext;
        if (mounted && target != null) {
          unawaited(Scrollable.ensureVisible(target, duration: Duration.zero));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      boardNotifierProvider.select((state) => state.ended != null),
      (previous, ended) {
        final route = ModalRoute.of(context);
        if (ended && mounted && route != null) {
          Navigator.of(context).removeRoute(route);
        }
      },
    );
    final l10n = AppLocalizations.of(context);
    final spacing = CardoSpacing.of(context);
    final view = ref.watch(membersViewProvider);
    final expanded =
        CardoLayout.of(context)
            .windowClassFor(MediaQuery.sizeOf(context).width) ==
        CardoWindowClass.expanded;
    final failure = ref.watch(
      membersControllerProvider(view.boardId).select((s) => s.actionFailure),
    );
    final body = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.lg,
        children: <Widget>[
          if (failure != null)
            FormMessage(message: actionFailureText(l10n, failure)),
          if (view.isOwner && !expanded)
            KeyedSubtree(
              key: _invitesKey,
              child: InvitesSection(boardId: view.boardId),
            ),
          if (view.isOwner) AddMemberForm(boardId: view.boardId),
          if (view.isOwner && expanded)
            KeyedSubtree(
              key: _invitesKey,
              child: InvitesSection(boardId: view.boardId),
            ),
          _MembersList(view: view),
        ],
      ),
    );
    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.membersSheetSemantic(view.boardTitle),
      child: Column(
        mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.lg,
        children: <Widget>[
          _PanelHeader(title: view.boardTitle),
          if (widget.fill) Expanded(child: body) else Flexible(child: body),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final layout = CardoLayout.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.md,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.xs,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.membersTitle,
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                title,
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.commonClose,
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
          constraints: BoxConstraints(
            minWidth: sizes.tapTarget,
            minHeight: sizes.tapTarget,
          ),
          iconSize: layout.iconHeader,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({required this.view});

  final MembersView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
          child: Semantics(
            header: true,
            child: Text(
              l10n.membersSummary(
                l10n.membersCount(view.total),
                l10n.membersOnlineCount(view.onlineCount),
              ),
              style: typography.overline.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
        for (var i = 0; i < view.rows.length; i++)
          MemberRow(
            key: ValueKey<String>('member-${view.rows[i].userId}'),
            row: view.rows[i],
            boardId: view.boardId,
            boardTitle: view.boardTitle,
            showDivider: i < view.rows.length - 1,
          ),
      ],
    );
  }
}
