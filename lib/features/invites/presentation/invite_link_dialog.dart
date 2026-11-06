import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../core/invite/invite_link.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/cardo_text_field.dart';
import '../../../theme/cardo_theme.dart';

Future<void> openInviteFromLink(BuildContext context) async {
  final router = GoRouter.of(context);
  final token = await showInviteLinkDialog(context);
  if (token != null) {
    router.go(AppRoutes.inviteFor(token));
  }
}

Future<String?> showInviteLinkDialog(BuildContext context) {
  final layout = CardoLayout.of(context);
  final expanded =
      layout.windowClassFor(MediaQuery.sizeOf(context).width) ==
      CardoWindowClass.expanded;
  if (expanded) {
    return showDialog<String>(
      context: context,
      builder: (context) => const InviteLinkDialog(),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const InviteLinkSheet(),
  );
}

class InviteLinkDialog extends StatelessWidget {
  const InviteLinkDialog({super.key});

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
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.all(spacing.section),
          child: const InviteLinkForm(),
        ),
      ),
    );
  }
}

class InviteLinkSheet extends StatelessWidget {
  const InviteLinkSheet({super.key});

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
      child: const InviteLinkForm(),
    );
  }
}

class InviteLinkForm extends StatefulWidget {
  const InviteLinkForm({super.key});

  @override
  State<InviteLinkForm> createState() => _InviteLinkFormState();
}

class _InviteLinkFormState extends State<InviteLinkForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final token = InviteLink.parse(_input.text);
    if (token != null) {
      Navigator.of(context).pop(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
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
                  l10n.inviteLinkTitle,
                  style: typography.titleLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
              iconSize: layout.iconHeader,
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
        Form(
          key: _formKey,
          child: CardoTextField(
            label: l10n.inviteLinkField,
            controller: _input,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) {
                return l10n.inviteLinkRequired;
              }
              return InviteLink.parse(text) == null
                  ? l10n.inviteLinkInvalid
                  : null;
            },
          ),
        ),
        CardoPrimaryButton(label: l10n.inviteLinkSubmit, onPressed: _submit),
      ],
    );
  }
}

class HaveLinkButton extends StatelessWidget {
  const HaveLinkButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = CardoLayout.of(context);
    final sizes = CardoSizes.of(context);
    return IconButton(
      tooltip: l10n.inviteHaveLink,
      onPressed: () => unawaited(openInviteFromLink(context)),
      iconSize: layout.iconHeader,
      constraints: BoxConstraints(
        minWidth: sizes.tapTarget,
        minHeight: sizes.tapTarget,
      ),
      icon: const Icon(LucideIcons.link),
    );
  }
}
