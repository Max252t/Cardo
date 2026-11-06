import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../core/invite/invite_link.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../theme/cardo_theme.dart';
import 'invite_controller.dart';
import 'invite_shell.dart';

class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.rawToken});

  final String? rawToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = rawToken;
    final token = raw == null ? null : InviteLink.parse(raw);
    if (token == null) {
      return const InviteProblemView(problem: InviteProblem.notFound);
    }
    final state = ref.watch(inviteControllerProvider);
    final problem = state.problem;
    if (problem != null) {
      return InviteProblemView(problem: problem);
    }
    return InviteReadyView(token: token, state: state);
  }
}

class InviteReadyView extends ConsumerWidget {
  const InviteReadyView({super.key, required this.token, required this.state});

  final String token;
  final InviteState state;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final board = await ref
        .read(inviteControllerProvider.notifier)
        .accept(token);
    if (board == null || !context.mounted) {
      return;
    }
    router.go(AppRoutes.board(board.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final layout = CardoLayout.of(context);
    final failure = state.failure;
    return InviteShell(
      title: l10n.inviteHeadline,
      body: Padding(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.lg,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(radii.card),
                border: Border.all(color: colors.line, width: sizes.hairline),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.all(spacing.cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: spacing.md,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Icon(
                        LucideIcons.users,
                        size: layout.iconDense,
                        color: colors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.inviteNote,
                        style: typography.message.copyWith(
                          color: colors.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (failure != null)
              FormMessage(message: describeApiFailure(l10n, failure)),
            const Spacer(),
            CardoPrimaryButton(
              label: l10n.inviteAccept,
              busy: state.accepting,
              onPressed: () => unawaited(_accept(context, ref)),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteProblemView extends StatelessWidget {
  const InviteProblemView({super.key, required this.problem});

  final InviteProblem problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final unavailable = problem == InviteProblem.unavailable;
    return InviteShell(
      title: unavailable
          ? l10n.inviteUnavailableTitle
          : l10n.inviteNotFoundTitle,
      body: Padding(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.lg,
          children: <Widget>[
            Text(
              unavailable
                  ? l10n.inviteUnavailableBody
                  : l10n.inviteNotFoundBody,
              style: typography.body.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            CardoPrimaryButton(
              label: l10n.inviteToBoards,
              onPressed: () => context.go(AppRoutes.boards),
            ),
          ],
        ),
      ),
    );
  }
}
