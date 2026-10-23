import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';
import '../card_drafts.dart';
import '../card_sheet_data.dart';
import 'card_editor_style.dart';

class CardDescriptionSection extends ConsumerStatefulWidget {
  const CardDescriptionSection({
    super.key,
    required this.cardId,
    required this.variant,
    required this.saveOnBlur,
  });

  final String cardId;
  final CardEditorVariant variant;
  final bool saveOnBlur;

  @override
  ConsumerState<CardDescriptionSection> createState() =>
      _CardDescriptionSectionState();
}

class _CardDescriptionSectionState
    extends ConsumerState<CardDescriptionSection> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final text = ref.read(cardSheetProvider(widget.cardId))?.text ?? '';
    _controller = TextEditingController(text: text);
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted || _focus.hasFocus || !widget.saveOnBlur) {
      return;
    }
    ref.read(cardDraftsProvider.notifier).flush(widget.cardId);
  }

  void _syncText(String? next) {
    if (next == null || next == _controller.text) {
      return;
    }
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardId = widget.cardId;
    ref.listen<String?>(
      cardSheetProvider(cardId).select((data) => data?.text),
      (previous, next) => _syncText(next),
    );
    final data = ref.watch(cardSheetProvider(cardId));
    if (data == null) {
      return const SizedBox.shrink();
    }
    final layout = CardoLayout.of(context);
    final style = CardEditorStyle.of(context, widget.variant);
    final field = _DescriptionInput(
      controller: _controller,
      focusNode: _focus,
      editable: data.editable,
      tooLong: data.tooLong,
      style: style,
      onChanged: (text) =>
          ref.read(cardDraftsProvider.notifier).edit(cardId, text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CardoSpacing.of(context).sm,
      children: <Widget>[
        _DescriptionLabel(uppercase: style.uppercaseLabel),
        if (style.fillField)
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: layout.descriptionMinHeight,
              ),
              child: field,
            ),
          )
        else
          field,
        _DescriptionCounter(length: data.text.length, tooLong: data.tooLong),
      ],
    );
  }
}

class _DescriptionLabel extends StatelessWidget {
  const _DescriptionLabel({required this.uppercase});

  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final label = AppLocalizations.of(context).cardDescription;
    return ExcludeSemantics(
      child: uppercase
          ? Text(
              label.toUpperCase(),
              style: typography.overline.copyWith(color: colors.textSecondary),
            )
          : Text(
              label,
              style: typography.buttonSmall.copyWith(color: colors.textSoft),
            ),
    );
  }
}

class _DescriptionInput extends StatelessWidget {
  const _DescriptionInput({
    required this.controller,
    required this.focusNode,
    required this.editable,
    required this.tooLong,
    required this.style,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editable;
  final bool tooLong;
  final CardEditorStyle style;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final l10n = AppLocalizations.of(context);
    final fill = style.fillField;
    final accent = tooLong ? colors.nackText : colors.emphasis;
    final idle = tooLong ? colors.nackBorder : colors.lineStrong;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(style.fieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
    return Semantics(
      label: l10n.cardDescription,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: !editable,
        expands: fill,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        onChanged: onChanged,
        style: style.field.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: editable ? l10n.cardPanelDescriptionHint : null,
          alignLabelWithHint: true,
          constraints: fill
              ? null
              : BoxConstraints(
                  minHeight: CardoLayout.of(context).descriptionMinHeight,
                ),
          contentPadding: EdgeInsetsDirectional.all(
            CardoSpacing.of(context).cardPadding,
          ),
          border: border(idle, sizes.hairline),
          enabledBorder: border(idle, sizes.hairline),
          focusedBorder: border(accent, sizes.emphasisBorder),
        ),
      ),
    );
  }
}

class _DescriptionCounter extends StatelessWidget {
  const _DescriptionCounter({required this.length, required this.tooLong});

  final int length;
  final bool tooLong;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final color = tooLong ? colors.nackText : colors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            l10n.cardDescriptionCounter(
              length,
              CardLimits.descriptionMaxLength,
            ),
            style: typography.mono.copyWith(color: color),
          ),
        ),
        if (tooLong)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.iconGap,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.circleAlert,
                    size: sizes.iconCompact,
                    color: color,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.cardDescriptionTooLong(
                      CardLimits.descriptionMaxLength,
                    ),
                    style: typography.caption.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
