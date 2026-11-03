import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../board_providers.dart';
import '../card_inline_state.dart';

class CardInlineTitleEditor extends ConsumerStatefulWidget {
  const CardInlineTitleEditor({
    super.key,
    required this.cardId,
    required this.dense,
    required this.bottomGap,
  });

  final String cardId;
  final bool dense;
  final double bottomGap;

  @override
  ConsumerState<CardInlineTitleEditor> createState() =>
      _CardInlineTitleEditorState();
}

class _CardInlineTitleEditorState extends ConsumerState<CardInlineTitleEditor> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final text = ref.read(cardInlineProvider).editingTitle;
    _controller = TextEditingController(text: text);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focus.requestFocus();
      unawaited(Scrollable.ensureVisible(context, duration: Duration.zero));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancel() => ref.read(cardInlineProvider.notifier).stopEditing();

  void _save() {
    if (!isValidCardTitle(_controller.text)) {
      _focus.requestFocus();
      return;
    }
    ref
        .read(boardNotifierProvider.notifier)
        .editCardTitle(cardId: widget.cardId, title: _controller.text);
    ref.read(cardInlineProvider.notifier).stopEditing();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final l10n = AppLocalizations.of(context);
    final dense = widget.dense;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.buttonSmall),
    );
    final minimum = Size(sizes.tapTarget, sizes.tapTarget);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: widget.bottomGap),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(
              dense ? radii.cardDense : radii.card,
            ),
            border: Border.all(
              color: colors.emphasis,
              width: sizes.emphasisBorder,
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(
              dense ? spacing.sm : spacing.md - spacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: <Widget>[
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: const <TextInputFormatter>[
                    RuneLimitFormatter(CardLimits.titleMaxLength),
                  ],
                  onChanged: (value) => ref
                      .read(cardInlineProvider.notifier)
                      .setEditingTitle(value),
                  onEditingComplete: _save,
                  style: typography.cardTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.cardTitleField,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: EdgeInsetsDirectional.all(spacing.xs),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: spacing.xs,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: spacing.xs),
                      child: Text(
                        l10n.cardInlineEditCaption,
                        style: typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: spacing.xs,
                      children: <Widget>[
                        IconButton(
                          tooltip: l10n.cardInlineEditCancel,
                          onPressed: _cancel,
                          style: IconButton.styleFrom(
                            minimumSize: minimum,
                            fixedSize: minimum,
                            backgroundColor: colors.field,
                            foregroundColor: colors.textPrimary,
                            shape: buttonShape,
                          ),
                          iconSize: sizes.iconCompact,
                          icon: const Icon(LucideIcons.x),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) => IconButton(
                            tooltip: l10n.cardInlineEditSave,
                            onPressed: isValidCardTitle(value.text)
                                ? _save
                                : null,
                            style: IconButton.styleFrom(
                              minimumSize: minimum,
                              fixedSize: minimum,
                              backgroundColor: colors.emphasis,
                              foregroundColor: colors.onEmphasis,
                              shape: buttonShape,
                            ),
                            iconSize: sizes.iconCompact,
                            icon: const Icon(LucideIcons.check),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
