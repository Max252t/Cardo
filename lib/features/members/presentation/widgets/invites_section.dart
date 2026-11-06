import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/models/board_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/form_message.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../theme/cardo_theme.dart';
import '../../../board/presentation/board_providers.dart';
import '../../domain/board_invite.dart';
import '../../domain/invite_policy.dart';
import '../members_controller.dart';
import '../members_texts.dart';
import 'role_picker.dart';

class InvitesSection extends ConsumerStatefulWidget {
  const InvitesSection({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<InvitesSection> createState() => _InvitesSectionState();
}

class _InvitesSectionState extends ConsumerState<InvitesSection> {
  BoardRole _role = InvitePolicy.defaultRole;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          return ref
              .read(membersControllerProvider(widget.boardId).notifier)
              .loadInvites();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final state = ref.watch(membersControllerProvider(widget.boardId));
    final controller = ref.read(
      membersControllerProvider(widget.boardId).notifier,
    );
    final invites = state.invites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.md,
      children: <Widget>[
        Row(
          spacing: spacing.sm,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                LucideIcons.link,
                size: sizes.iconButton,
                color: colors.accent,
              ),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.invitesTitle,
                  style: typography.paragraph.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            RolePickerButton(
              role: _role,
              semanticLabel: l10n.invitesRoleForNew(
                RoleBadge.labelFor(l10n, _role),
              ),
              onSelected: state.creating
                  ? null
                  : (role) => setState(() => _role = role),
            ),
            CardoPrimaryButton(
              label: l10n.invitesCreate,
              busy: state.creating,
              large: false,
              icon: LucideIcons.plus,
              onPressed: () => unawaited(controller.createInvite(_role)),
            ),
          ],
        ),
        if (state.invitesFailure != null)
          _InvitesLoadError(
            onRetry: () => unawaited(controller.loadInvites()),
            busy: state.invitesLoading,
          )
        else if (invites == null)
          Center(
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.md),
              child: const BusyIndicator(),
            ),
          )
        else if (invites.isEmpty)
          Text(
            l10n.invitesEmpty,
            style: typography.message.copyWith(color: colors.textSecondary),
          )
        else ...<Widget>[
          for (final invite in invites)
            InviteCard(
              key: ValueKey<String>('invite-${invite.id}'),
              invite: invite,
              link: state.links[invite.id],
              revoking: state.revoking.contains(invite.id),
              onRevoke: () => unawaited(controller.revokeInvite(invite.id)),
            ),
          if (invites.any((invite) => !state.links.containsKey(invite.id)))
            Text(
              l10n.invitesTokenHint,
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
        ],
      ],
    );
  }
}

class _InvitesLoadError extends StatelessWidget {
  const _InvitesLoadError({required this.onRetry, required this.busy});

  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = CardoSpacing.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: <Widget>[
        FormMessage(message: l10n.invitesLoadError),
        CardoSecondaryButton(
          label: l10n.commonRetry,
          large: false,
          onPressed: busy ? null : onRetry,
        ),
      ],
    );
  }
}

class InviteCard extends ConsumerWidget {
  const InviteCard({
    super.key,
    required this.invite,
    required this.link,
    required this.revoking,
    required this.onRevoke,
  });

  final BoardInvite invite;
  final String? link;
  final bool revoking;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final sizes = CardoSizes.of(context);
    final tokens = CardoColumnTokens.of(context);
    final now = ref.watch(tickingNowProvider);
    final meta = inviteMetaText(l10n, invite, now);
    final shown = link;
    return Container(
      padding: EdgeInsetsDirectional.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.snackbarBackground,
        borderRadius: BorderRadius.circular(tokens.dangerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: <Widget>[
          if (shown != null)
            Semantics(
              label: l10n.invitesLinkSemantic(shown),
              child: ExcludeSemantics(
                child: Container(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.snackbarAction,
                    borderRadius: BorderRadius.circular(radii.buttonSmall),
                  ),
                  child: Text(
                    shown,
                    style: typography.mono.copyWith(
                      color: colors.snackbarActionText,
                    ),
                  ),
                ),
              ),
            ),
          Text(
            meta,
            style: typography.caption.copyWith(color: colors.snackbarText),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Semantics(
                label: l10n.invitesRevokeSemantic(meta),
                button: true,
                excludeSemantics: true,
                child: TextButton(
                  onPressed: revoking ? null : onRevoke,
                  style: TextButton.styleFrom(
                    minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
                    foregroundColor: colors.snackbarText,
                    disabledForegroundColor: colors.snackbarText,
                    textStyle: typography.buttonSmall,
                  ),
                  child: revoking
                      ? BusyIndicator(color: colors.snackbarText)
                      : Text(l10n.invitesRevoke),
                ),
              ),
              if (shown != null) InviteCopyButton(link: shown),
            ],
          ),
        ],
      ),
    );
  }
}

class InviteCopyButton extends StatefulWidget {
  const InviteCopyButton({super.key, required this.link});

  final String link;

  @override
  State<InviteCopyButton> createState() => _InviteCopyButtonState();
}

class _InviteCopyButtonState extends State<InviteCopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (mounted) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    return Semantics(
      liveRegion: true,
      child: FilledButton.icon(
        onPressed: () => unawaited(_copy()),
        icon: Icon(
          _copied ? LucideIcons.check : LucideIcons.copy,
          size: sizes.iconCompact + spacing.xxs,
        ),
        label: Text(_copied ? l10n.invitesCopied : l10n.invitesCopy),
        style: FilledButton.styleFrom(
          minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          textStyle: typography.buttonSmall,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.buttonSmall),
          ),
        ),
      ),
    );
  }
}
