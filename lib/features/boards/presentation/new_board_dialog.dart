import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/cardo_text_field.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../theme/cardo_theme.dart';
import '../domain/board_info.dart';
import 'boards_providers.dart';

Future<BoardInfo?> showNewBoardDialog(BuildContext context) {
  final layout = CardoLayout.of(context);
  final expanded =
      layout.windowClassFor(MediaQuery.sizeOf(context).width) ==
      CardoWindowClass.expanded;
  if (expanded) {
    return showDialog<BoardInfo>(
      context: context,
      builder: (context) => const NewBoardDialog(),
    );
  }
  return showModalBottomSheet<BoardInfo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const NewBoardSheet(),
  );
}

class NewBoardDialog extends StatelessWidget {
  const NewBoardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.dialogMaxWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.section),
          child: const NewBoardForm(wide: true),
        ),
      ),
    );
  }
}

class NewBoardSheet extends StatelessWidget {
  const NewBoardSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(
        start: spacing.xl,
        end: spacing.xl,
        bottom: inset + spacing.section,
      ),
      child: const NewBoardForm(wide: false),
    );
  }
}

class NewBoardForm extends ConsumerStatefulWidget {
  const NewBoardForm({super.key, required this.wide});

  final bool wide;

  @override
  ConsumerState<NewBoardForm> createState() => _NewBoardFormState();
}

class _NewBoardFormState extends ConsumerState<NewBoardForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  bool _submitting = false;
  ApiFailure? _failure;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await container
        .read(boardsApiProvider)
        .createBoard(_title.text.trim());
    if (result.isSuccess) {
      container.invalidate(boardsListProvider);
    }
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success<BoardInfo, ApiFailure>(:final value):
        navigator.pop(value);
      case Failure<BoardInfo, ApiFailure>(:final failure):
        setState(() {
          _submitting = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final layout = CardoLayout.of(context);
    final failure = _failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xl - spacing.xxs,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.newBoardTitle,
                  style: typography.titleLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.commonClose,
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              iconSize: layout.iconHeader,
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.xs,
            children: <Widget>[
              CardoTextField(
                label: l10n.newBoardName,
                controller: _title,
                enabled: !_submitting,
                autofocus: true,
                maxLength: BoardLimits.titleMax,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _failure = null),
                onFieldSubmitted: (_) => unawaited(_submit()),
                validator: (value) =>
                    switch (BoardLimits.validateTitle(value ?? '')) {
                      BoardTitleIssue.empty => l10n.newBoardRequired,
                      BoardTitleIssue.tooLong => l10n.fieldTooLong(
                        BoardLimits.titleMax,
                      ),
                      null => null,
                    },
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _title,
                  builder: (context, value, _) => Text(
                    l10n.boardTitleCounter(
                      value.text.trim().runes.length,
                      BoardLimits.titleMax,
                    ),
                    style: typography.mono.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.wide)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(radii.field),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: spacing.cardPadding,
                vertical: spacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.md,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      LucideIcons.info,
                      size: layout.iconDense,
                      color: colors.textSoft,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.newBoardNote,
                      style: typography.caption.copyWith(
                        color: colors.textSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (failure != null)
          FormMessage(message: describeApiFailure(l10n, failure)),
        if (widget.wide)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: spacing.cardGap,
            runSpacing: spacing.cardGap,
            children: <Widget>[
              CardoSecondaryButton(
                label: l10n.commonCancel,
                large: false,
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              CardoPrimaryButton(
                label: l10n.newBoardSubmit,
                large: false,
                busy: _submitting,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          )
        else
          CardoPrimaryButton(
            label: l10n.newBoardSubmit,
            busy: _submitting,
            onPressed: () => unawaited(_submit()),
          ),
      ],
    );
  }
}
