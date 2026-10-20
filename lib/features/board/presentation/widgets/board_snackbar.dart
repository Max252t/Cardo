import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../../domain/board_sync_state.dart';

String nackMessage(
  AppLocalizations l10n,
  OpRejection rejection, {
  required String? actorName,
  bool retrying = false,
}) {
  return switch (rejection.reason) {
    NackReason.forbidden => l10n.nackForbidden,
    NackReason.validationError => l10n.nackValidation(
      rejection.limit ?? CardLimits.titleMaxLength,
    ),
    NackReason.versionConflict when actorName != null =>
      l10n.nackVersionConflict(actorName),
    NackReason.versionConflict => l10n.nackVersionConflictUnknown,
    NackReason.notFound => l10n.nackNotFound,
    NackReason.rateLimited => l10n.nackRateLimited,
    NackReason.internal when retrying => l10n.nackInternal,
    NackReason.internal => l10n.nackInternalFinal,
  };
}

bool nackHasDismiss(NackReason reason) => reason == NackReason.versionConflict;

void showBoardSnackbar(
  BuildContext context, {
  required String message,
  IconData icon = LucideIcons.circleAlert,
  bool withDismiss = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final l10n = AppLocalizations.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: CardoDurations.snackbar,
        content: BoardSnackbarContent(message: message, icon: icon),
        action: withDismiss
            ? SnackBarAction(
                label: l10n.snackbarDismiss,
                onPressed: messenger.hideCurrentSnackBar,
              )
            : null,
      ),
    );
}

void showComingSoon(BuildContext context) {
  showBoardSnackbar(
    context,
    message: AppLocalizations.of(context).boardComingSoon,
    icon: LucideIcons.info,
  );
}

class BoardSnackbarContent extends StatelessWidget {
  const BoardSnackbarContent({
    super.key,
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    return Row(
      spacing: spacing.snackbarGap,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            icon,
            size: sizes.iconSnackbar,
            color: colors.snackbarIcon,
          ),
        ),
        Expanded(child: Text(message)),
      ],
    );
  }
}
