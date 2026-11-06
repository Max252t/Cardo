import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/board_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_avatar.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../theme/cardo_theme.dart';
import '../members_controller.dart';
import '../members_view_data.dart';
import 'remove_member_dialog.dart';
import 'role_picker.dart';

class MemberRow extends ConsumerWidget {
  const MemberRow({
    super.key,
    required this.row,
    required this.boardId,
    required this.boardTitle,
    required this.showDivider,
  });

  final MemberRowView row;
  final String boardId;
  final String boardTitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >=
        layout.stackActionsTextScale;
    final busy = ref.watch(
      membersControllerProvider(boardId)
          .select((state) => state.busyMembers.contains(row.userId)),
    );
    final info = Row(
      spacing: spacing.md,
      children: <Widget>[
        CardoAvatar(
          identity: row.identity,
          diameter: sizes.avatarPresenceLarge + spacing.xs,
        ),
        Expanded(child: _MemberInfo(row: row)),
        if (!stacked)
          _MemberTrailing(
            row: row,
            busy: busy,
            onRole: (role) => _changeRole(ref, role),
            onRemove: () => _remove(context, ref),
          ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? BorderDirectional(
                bottom: BorderSide(color: colors.line, width: sizes.hairline),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          vertical: spacing.md - spacing.xxs,
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.sm,
                children: <Widget>[
                  info,
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _MemberTrailing(
                      row: row,
                      busy: busy,
                      onRole: (role) => _changeRole(ref, role),
                      onRemove: () => _remove(context, ref),
                    ),
                  ),
                ],
              )
            : info,
      ),
    );
  }

  void _changeRole(WidgetRef ref, BoardRole role) {
    if (role == row.role) {
      return;
    }
    unawaited(
      ref
          .read(membersControllerProvider(boardId).notifier)
          .changeRole(row.userId, role),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmRemoveMember(
      context,
      memberName: row.identity.name,
      boardTitle: boardTitle,
    );
    if (confirmed && context.mounted) {
      unawaited(
        ref
            .read(membersControllerProvider(boardId).notifier)
            .removeMember(row.userId),
      );
    }
  }
}

class _MemberInfo extends StatelessWidget {
  const _MemberInfo({required this.row});

  final MemberRowView row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final email = row.email;
    final Widget? subtitle;
    if (email != null && email.isNotEmpty) {
      subtitle = Text(
        email,
        style: typography.caption.copyWith(color: colors.textSecondary),
      );
    } else if (row.online && !row.isSelf) {
      subtitle = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing.iconGap,
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: sizes.statusDot,
              height: sizes.statusDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.connected.glyph,
              ),
            ),
          ),
          Flexible(
            child: Text(
              l10n.membersOnBoard,
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      );
    } else {
      subtitle = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xxs,
      children: <Widget>[
        Wrap(
          spacing: spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              row.identity.name,
              style: typography.paragraph.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (row.isSelf)
              Text(
                l10n.membersYou,
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
          ],
        ),
        ?subtitle,
      ],
    );
  }
}

class _MemberTrailing extends StatelessWidget {
  const _MemberTrailing({
    required this.row,
    required this.busy,
    required this.onRole,
    required this.onRemove,
  });

  final MemberRowView row;
  final bool busy;
  final ValueChanged<BoardRole> onRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!row.canManage) {
      return RoleBadge(role: row.role);
    }
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final name = row.identity.name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.xs,
      children: <Widget>[
        Flexible(
          child: RolePickerButton(
            role: row.role,
            busy: busy,
            semanticLabel: l10n.membersRoleChange(
              name,
              RoleBadge.labelFor(l10n, row.role),
            ),
            onSelected: onRole,
          ),
        ),
        IconButton(
          tooltip: l10n.membersRemoveTooltip(name),
          onPressed: busy ? null : onRemove,
          constraints: BoxConstraints(
            minWidth: sizes.tapTarget,
            minHeight: sizes.tapTarget,
          ),
          iconSize: layout.iconDense,
          color: colors.textSecondary,
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}
