import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/rune_length_formatter.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/op_limits.dart';

class NewColumnField extends StatefulWidget {
  const NewColumnField({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    this.width,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  final double? width;

  @override
  State<NewColumnField> createState() => _NewColumnFieldState();
}

class _NewColumnFieldState extends State<NewColumnField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _controller.text.trim().isEmpty) {
      widget.onCancel();
    }
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      return;
    }
    widget.onSubmit(title);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final tokens = CardoColumnTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmInset = (sizes.tapTarget - tokens.confirmButton) / 2;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: SizedBox(
        width: widget.width,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: sizes.tapTarget),
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: <Widget>[
              Container(
                constraints: BoxConstraints(minHeight: layout.tabHeight),
                margin: EdgeInsetsDirectional.only(end: spacing.xs),
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md,
                  end: sizes.tapTarget - confirmInset,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(radii.buttonSmall),
                  border: Border.all(
                    color: colors.accent,
                    width: sizes.emphasisBorder,
                  ),
                ),
                child: Semantics(
                  label: l10n.columnNewSemantic,
                  textField: true,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: <TextInputFormatter>[
                      const RuneLengthLimitingFormatter(
                        ColumnLimits.titleMaxLength,
                      ),
                    ],
                    style: typography.tab.copyWith(color: colors.textPrimary),
                    cursorColor: colors.textPrimary,
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.columnNewHint,
                      hintStyle: typography.tab.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: sizes.tapTarget,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => _ConfirmButton(
                    enabled: value.text.trim().isNotEmpty,
                    onPressed: _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final tokens = CardoColumnTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.columnNewCreate,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: enabled ? onPressed : null,
          radius: tokens.confirmButton,
          child: Center(
            child: Container(
              width: tokens.confirmButton,
              height: tokens.confirmButton,
              decoration: BoxDecoration(
                color: enabled ? colors.emphasis : colors.outlineMuted,
                borderRadius: BorderRadius.circular(tokens.confirmRadius),
              ),
              child: Icon(
                LucideIcons.check,
                size: tokens.confirmIcon,
                color: colors.onEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewColumnTab extends StatefulWidget {
  const NewColumnTab({super.key, required this.onCreate});

  final ValueChanged<String> onCreate;

  @override
  State<NewColumnTab> createState() => _NewColumnTabState();
}

class _NewColumnTabState extends State<NewColumnTab> {
  bool _editing = false;

  void _open() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(Scrollable.ensureVisible(context));
      }
    });
  }

  void _close() {
    if (mounted && _editing) {
      setState(() => _editing = false);
    }
  }

  void _create(String title) {
    setState(() => _editing = false);
    widget.onCreate(title);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return NewColumnField(
        width: CardoColumnTokens.of(context).newFieldWidth,
        onSubmit: _create,
        onCancel: _close,
      );
    }
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(radii.buttonSmall);
    return Semantics(
      button: true,
      label: l10n.boardAddColumnSemantic,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _open,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: sizes.tapTarget),
            child: Center(
              widthFactor: 1,
              child: Container(
                constraints: BoxConstraints(minHeight: layout.tabHeight),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.md,
                ),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: colors.outlineMuted,
                    width: sizes.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing.iconGap,
                  children: <Widget>[
                    Icon(
                      LucideIcons.plus,
                      size: layout.iconDense,
                      color: colors.textSoft,
                    ),
                    Text(
                      l10n.boardAddColumn,
                      style: typography.tab.copyWith(color: colors.textSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
