import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../boards_providers.dart';

class BoardsRefreshButton extends ConsumerWidget {
  const BoardsRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = CardoLayout.of(context);
    final sizes = CardoSizes.of(context);
    return Semantics(
      button: true,
      label: l10n.boardsRefresh,
      excludeSemantics: true,
      child: IconButton(
        tooltip: l10n.boardsRefresh,
        onPressed: () =>
            unawaited(ref.read(boardsListProvider.notifier).reload()),
        iconSize: layout.iconHeader,
        constraints: BoxConstraints(
          minWidth: sizes.tapTarget,
          minHeight: sizes.tapTarget,
        ),
        icon: const Icon(LucideIcons.refreshCw),
      ),
    );
  }
}
