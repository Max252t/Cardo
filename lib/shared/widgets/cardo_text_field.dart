import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';
import 'rune_length_formatter.dart';

class CardoTextField extends StatelessWidget {
  const CardoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffix,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final limit = maxLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs + spacing.xxs,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            label,
            style: typography.label.copyWith(color: colors.textSoft),
          ),
        ),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: false,
            onFieldSubmitted: onFieldSubmitted,
            onChanged: onChanged,
            enabled: enabled,
            autofocus: autofocus,
            textCapitalization: textCapitalization,
            autovalidateMode: autovalidateMode,
            inputFormatters: limit == null
                ? null
                : <TextInputFormatter>[RuneLengthLimitingFormatter(limit)],
            style: typography.paragraph.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(suffixIcon: suffix),
          ),
        ),
      ],
    );
  }
}

class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.visible,
    required this.onToggle,
  });

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = CardoLayout.of(context);
    return IconButton(
      tooltip: visible ? l10n.authHidePassword : l10n.authShowPassword,
      onPressed: onToggle,
      iconSize: layout.iconHeader,
      icon: Icon(visible ? LucideIcons.eyeOff : LucideIcons.eye),
    );
  }
}
