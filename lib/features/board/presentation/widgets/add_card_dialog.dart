import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';

Future<String?> showAddCardDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const AddCardDialog(),
  );
}

class AddCardDialog extends StatefulWidget {
  const AddCardDialog({super.key});

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final radii = CardoRadii.of(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.sheet),
      ),
      title: Text(
        l10n.addCardTitle,
        style: typography.title.copyWith(color: colors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: CardLimits.titleMaxLength,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => _submit(),
        decoration: InputDecoration(hintText: l10n.addCardHint),
      ),
      actions: <Widget>[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.addCardCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(l10n.addCardSubmit),
          ),
        ),
      ],
    );
  }
}
