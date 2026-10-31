import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../board_providers.dart';
import '../board_view_data.dart';
import '../card_drafts.dart';
import 'column_marker.dart';

class CardPanelActions extends ConsumerWidget {
  const CardPanelActions({
    super.key,
    required this.cardId,
    required this.otherColumns,
    required this.canSave,
    this.locked = false,
  });

  final String cardId;
  final List<ColumnInfo> otherColumns;
  final bool canSave;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final typography = CardoTypography.of(context);
    final l10n = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.buttonCompact),
    );
    final minimum = Size(sizes.tapTarget, sizes.tapTarget);
    final padding = EdgeInsetsDirectional.symmetric(horizontal: spacing.lg);
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: <Widget>[
        FilledButton(
          onPressed: canSave
              ? () => ref.read(cardDraftsProvider.notifier).save(cardId)
              : null,
          style: FilledButton.styleFrom(
            minimumSize: minimum,
            padding: padding,
            shape: shape,
            textStyle: typography.buttonCompact,
          ),
          child: Text(l10n.cardPanelSave),
        ),
        MenuAnchor(
          menuChildren: <Widget>[
            for (final column in otherColumns)
              MenuItemButton(
                leadingIcon: ColumnMarkerSquare(
                  marker: column.marker,
                  size: sizes.markerTab,
                  radius: radii.markerTab,
                ),
                onPressed: () => ref
                    .read(boardNotifierProvider.notifier)
                    .moveCardToColumnEnd(cardId: cardId, toColumnId: column.id),
                child: Text(l10n.cardMoveTo(column.title)),
              ),
          ],
          builder: (context, controller, child) => OutlinedButton(
            onPressed: locked || otherColumns.isEmpty
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            style: OutlinedButton.styleFrom(
              minimumSize: minimum,
              padding: padding,
              shape: shape,
              textStyle: typography.buttonCompact,
            ),
            child: Text(l10n.cardPanelMove),
          ),
        ),
      ],
    );
  }
}
