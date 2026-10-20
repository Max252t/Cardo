import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../board_providers.dart';
import 'board_snackbar.dart';
import 'column_marker.dart';

class CardDescriptionEditor extends StatefulWidget {
  const CardDescriptionEditor({
    super.key,
    required this.description,
    required this.readOnly,
  });

  final String description;
  final bool readOnly;

  @override
  State<CardDescriptionEditor> createState() => _CardDescriptionEditorState();
}

class _CardDescriptionEditorState extends State<CardDescriptionEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.description,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            l10n.cardDescription.toUpperCase(),
            style: typography.overline.copyWith(color: colors.textSecondary),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: layout.descriptionMinHeight),
          child: TextField(
            controller: _controller,
            readOnly: widget.readOnly,
            maxLines: null,
            minLines: 1,
            maxLength: CardLimits.descriptionMaxLength,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            keyboardType: TextInputType.multiline,
            style: typography.message.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: l10n.cardDescription,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              hintText: l10n.cardPanelDescriptionHint,
              constraints: BoxConstraints(
                minHeight: layout.descriptionMinHeight,
              ),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }
}

class CardPanelActions extends ConsumerWidget {
  const CardPanelActions({
    super.key,
    required this.cardId,
    required this.otherColumns,
    this.locked = false,
  });

  final String cardId;
  final List<ColumnModel> otherColumns;
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
          onPressed: () => showComingSoon(context),
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
