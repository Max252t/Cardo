import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/rune_length_formatter.dart';
import '../../../../shared/widgets/single_line_formatter.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../board_providers.dart';
import '../card_inline_state.dart';

class CardComposer extends ConsumerStatefulWidget {
  const CardComposer({super.key, required this.columnId, required this.dense});

  final String columnId;
  final bool dense;

  @override
  ConsumerState<CardComposer> createState() => _CardComposerState();
}

class _CardComposerState extends ConsumerState<CardComposer>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final draft = ref.read(cardInlineProvider);
    _title = TextEditingController(text: draft.composerTitle);
    _description = TextEditingController(text: draft.composerDescription);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocus.requestFocus();
      _reveal();
    });
  }

  @override
  void didChangeMetrics() => _reveal();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _description.dispose();
    _titleFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  CardInlineNotifier get _inline => ref.read(cardInlineProvider.notifier);

  void _cancel() => _inline.closeComposer();

  void _submit() {
    if (!isValidCardTitle(_title.text)) {
      _titleFocus.requestFocus();
      return;
    }
    final open = ref.read(cardInlineProvider).composerDescriptionOpen;
    final description = open ? _description.text.trim() : '';
    final created = ref
        .read(boardNotifierProvider.notifier)
        .createCard(
          columnId: widget.columnId,
          title: _title.text,
          description: description,
        );
    if (!created) {
      _titleFocus.requestFocus();
      return;
    }
    _title.clear();
    _description.clear();
    _inline.clearComposerText();
    _titleFocus.requestFocus();
    _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final position = Scrollable.maybeOf(context)?.position;
      if (position != null &&
          position.axis == Axis.vertical &&
          position.hasContentDimensions) {
        position.jumpTo(position.maxScrollExtent);
      }
    });
  }

  void _toggleDescription() {
    _inline.toggleComposerDescription();
    if (ref.read(cardInlineProvider).composerDescriptionOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _descriptionFocus.requestFocus();
        }
      });
    }
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
    final descriptionOpen = ref.watch(
      cardInlineProvider.select((state) => state.composerDescriptionOpen),
    );
    final fieldStyle = typography.cardTitle.copyWith(color: colors.textPrimary);
    final padding = dense ? spacing.cardPaddingDense : spacing.md;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.addCardTitle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(
              dense ? radii.cardDense : radii.card,
            ),
            border: Border.all(
              color: colors.accent,
              width: sizes.emphasisBorder,
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(
                    l10n.addCardTitle.toUpperCase(),
                    style: typography.overline.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                _ComposerField(
                  controller: _title,
                  focusNode: _titleFocus,
                  hint: l10n.addCardHint,
                  style: fieldStyle,
                  limit: CardLimits.titleMaxLength,
                  singleLine: true,
                  maxLines: 4,
                  action: TextInputAction.done,
                  onChanged: (value) {
                    _inline.setComposer(title: value);
                    _reveal();
                  },
                  onSubmit: _submit,
                ),
                if (descriptionOpen)
                  _ComposerField(
                    controller: _description,
                    focusNode: _descriptionFocus,
                    hint: l10n.cardPanelDescriptionHint,
                    style: typography.message.copyWith(
                      color: colors.textPrimary,
                    ),
                    limit: CardLimits.descriptionMaxLength,
                    singleLine: false,
                    maxLines: 6,
                    action: TextInputAction.newline,
                    onChanged: (value) {
                      _inline.setComposer(description: value);
                      _reveal();
                    },
                    onSubmit: null,
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: spacing.xs,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _toggleDescription,
                      icon: Icon(
                        LucideIcons.textAlignStart,
                        size: sizes.iconCompact,
                      ),
                      label: Text(l10n.cardComposerDescription),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSoft,
                        minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
                        textStyle: typography.buttonSmall,
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: spacing.xs,
                      children: <Widget>[
                        TextButton(
                          onPressed: _cancel,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            minimumSize: Size(sizes.tapTarget, sizes.tapTarget),
                            textStyle: typography.buttonSmall,
                          ),
                          child: Text(l10n.addCardCancel),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _title,
                          builder: (context, value, child) => FilledButton(
                            onPressed: isValidCardTitle(value.text)
                                ? _submit
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.emphasis,
                              foregroundColor: colors.onEmphasis,
                              minimumSize: Size(
                                sizes.tapTarget,
                                sizes.tapTarget,
                              ),
                              textStyle: typography.buttonSmall,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.buttonSmall,
                                ),
                              ),
                            ),
                            child: Text(l10n.addCardSubmit),
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

class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.style,
    required this.limit,
    required this.singleLine,
    required this.maxLines,
    required this.action,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextStyle style;
  final int limit;
  final bool singleLine;
  final int maxLines;
  final TextInputAction action;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final multiline = onSubmit == null;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: maxLines,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: action,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: <TextInputFormatter>[
        if (singleLine) const SingleLineFormatter(),
        RuneLengthLimitingFormatter(limit),
      ],
      onChanged: onChanged,
      onEditingComplete: onSubmit,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        isCollapsed: true,
        contentPadding: EdgeInsetsDirectional.symmetric(
          vertical: CardoSpacing.of(context).xs,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }
}
