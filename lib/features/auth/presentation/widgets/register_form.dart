import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/errors/api_failure_text.dart';
import '../../../../shared/widgets/avatar_color_picker.dart';
import '../../../../shared/widgets/avatar_identity.dart';
import '../../../../shared/widgets/cardo_avatar.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/cardo_text_field.dart';
import '../../../../shared/widgets/form_message.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/auth_validation.dart';
import '../auth_controllers.dart';
import '../auth_texts.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _passwordVisible = false;
  String? _avatarColor;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          avatarColor: _avatarColor,
        );
    if (ok && mounted) {
      TextInput.finishAutofillContext();
    }
  }

  void _onEdited(String value) {
    ref.read(registerControllerProvider.notifier).clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final form = ref.watch(registerControllerProvider);
    final failure = form.failure;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: spacing.xl + spacing.xs,
        end: spacing.xl + spacing.xs,
        top: spacing.sm,
        bottom: spacing.section + spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.xl + spacing.xxs,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.sm,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.registerTitle,
                  style: typography.display.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                l10n.registerSubtitle,
                style: typography.body.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radii.column),
              border: Border.all(color: colors.line, width: sizes.hairline),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.cardPadding),
              child: Row(
                spacing: spacing.lg,
                children: <Widget>[
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => CardoAvatar(
                      identity: AvatarIdentity(
                        name: value.text,
                        colorHex: _avatarColor ?? '',
                      ),
                      diameter: metrics.avatarPreview,
                      ringColor: colors.surface,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: spacing.xs,
                      children: <Widget>[
                        Text(
                          l10n.avatarColorLabel,
                          style: typography.label.copyWith(
                            color: colors.textSoft,
                          ),
                        ),
                        AvatarColorPicker(
                          selected: _avatarColor,
                          enabled: !form.submitting,
                          onChanged: (value) =>
                              setState(() => _avatarColor = value),
                        ),
                        Text(
                          l10n.avatarColorOptional,
                          style: typography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.md + spacing.xxs,
                children: <Widget>[
                  CardoTextField(
                    label: l10n.authName,
                    controller: _name,
                    enabled: !form.submitting,
                    maxLength: AuthLimits.nameMax,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                    validator: (value) => fieldIssueText(
                      l10n,
                      AuthField.name,
                      AuthValidators.name(value ?? ''),
                    ),
                  ),
                  CardoTextField(
                    label: l10n.authEmail,
                    controller: _email,
                    focusNode: _emailFocus,
                    enabled: !form.submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (value) => fieldIssueText(
                      l10n,
                      AuthField.email,
                      AuthValidators.email(value ?? ''),
                    ),
                  ),
                  CardoTextField(
                    label: l10n.authPassword,
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: !form.submitting,
                    maxLength: AuthLimits.passwordMax,
                    obscureText: !_passwordVisible,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => unawaited(_submit()),
                    suffix: PasswordVisibilityToggle(
                      visible: _passwordVisible,
                      onToggle: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    validator: (value) => fieldIssueText(
                      l10n,
                      AuthField.password,
                      AuthValidators.newPassword(value ?? ''),
                    ),
                  ),
                  if (failure != null)
                    FormMessage(message: describeApiFailure(l10n, failure)),
                ],
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.md,
            children: <Widget>[
              CardoPrimaryButton(
                label: l10n.registerSubmit,
                busy: form.submitting,
                onPressed: () => unawaited(_submit()),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.registerHaveAccount,
                    style: typography.message.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: form.submitting
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: Text(l10n.registerSignIn),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
