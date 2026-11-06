import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/errors/api_failure_text.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/cardo_text_field.dart';
import '../../../../shared/widgets/form_message.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/auth_validation.dart';
import '../../domain/session.dart';
import '../auth_controllers.dart';
import '../auth_providers.dart';
import '../auth_texts.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key, required this.wide});

  final bool wide;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
    if (ok && mounted) {
      TextInput.finishAutofillContext();
    }
  }

  void _onEdited(String value) {
    ref.read(loginControllerProvider.notifier).clearFailure();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final form = ref.watch(loginControllerProvider);
    final session = ref.watch(sessionProvider);
    final reason = session is SessionSignedOut ? session.reason : null;
    final failure = form.failure;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: spacing.xl + spacing.xs,
        end: spacing.xl + spacing.xs,
        top: spacing.section,
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
                  l10n.loginTitle,
                  style: typography.display.copyWith(color: colors.textPrimary),
                ),
              ),
              Text(
                widget.wide ? l10n.loginSubtitleWide : l10n.loginSubtitle,
                style: typography.body.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          if (reason != null)
            FormMessage(
              message: signOutReasonText(l10n, reason),
              tone: FormMessageTone.info,
            ),
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.md + spacing.xxs,
                children: <Widget>[
                  CardoTextField(
                    label: l10n.authEmail,
                    controller: _email,
                    enabled: !form.submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (value) => fieldIssueText(
                      l10n,
                      AuthField.email,
                      AuthValidators.loginEmail(value ?? ''),
                    ),
                  ),
                  CardoTextField(
                    label: l10n.authPassword,
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: !form.submitting,
                    obscureText: !_passwordVisible,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    onChanged: _onEdited,
                    onFieldSubmitted: (_) => unawaited(_submit()),
                    suffix: PasswordVisibilityToggle(
                      visible: _passwordVisible,
                      onToggle: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    validator: (value) => fieldIssueText(
                      l10n,
                      AuthField.loginPassword,
                      AuthValidators.loginPassword(value ?? ''),
                    ),
                  ),
                  if (failure != null)
                    FormMessage(message: describeApiFailure(l10n, failure)),
                ],
              ),
            ),
          ),
          if (widget.wide) SizedBox(height: spacing.xs) else const Spacer(),
          CardoPrimaryButton(
            label: l10n.loginSubmit,
            busy: form.submitting,
            onPressed: () => unawaited(_submit()),
          ),
          if (widget.wide)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.xs,
              children: <Widget>[
                Text(
                  l10n.loginNoAccount,
                  style: typography.message.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: form.submitting
                      ? null
                      : () => context.go(
                          AppRoutes.keepFrom(
                            AppRoutes.register,
                            GoRouterState.of(context).uri,
                          ),
                        ),
                  child: Text(l10n.loginCreateLink),
                ),
              ],
            )
          else
            CardoSecondaryButton(
              label: l10n.loginCreateAccount,
              onPressed: form.submitting
                  ? null
                  : () => context.go(
                      AppRoutes.keepFrom(
                        AppRoutes.register,
                        GoRouterState.of(context).uri,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
