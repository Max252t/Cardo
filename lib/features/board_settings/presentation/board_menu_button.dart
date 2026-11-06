import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/cardo_theme.dart';
import 'board_settings_screen.dart';

class BoardMenuButton extends StatelessWidget {
  const BoardMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = CardoLayout.of(context);
    final sizes = CardoSizes.of(context);
    return IconButton(
      tooltip: l10n.boardMenu,
      onPressed: () => openBoardSettings(context),
      iconSize: layout.iconHeader,
      constraints: BoxConstraints(
        minWidth: sizes.tapTarget,
        minHeight: sizes.tapTarget,
      ),
      icon: const Icon(LucideIcons.ellipsis),
    );
  }
}
