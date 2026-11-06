import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../../domain/user.dart';
import '../auth_controllers.dart';
import '../auth_providers.dart';
import '../auth_texts.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key});

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _avatarColor;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionUserProvider);
    _name = TextEditingController(text: user?.displayName ?? '');
    _avatarColor = user?.avatarColor ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _isDirty(User user) {
    return _name.text.trim() != user.displayName ||
        _avatarColor != user.avatarColor;
  }

  Future<void> _save(User user) async {
    if (!(_formKey.currentState?.validate() ?? false) || !_isDirty(user)) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppLocalizations.of(context).profileSaved;
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .submit(
          displayName: _name.text.trim() == user.displayName
              ? null
              : _name.text,
          avatarColor: _avatarColor == user.avatarColor ? null : _avatarColor,
        );
    if (ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) {
      setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final user = ref.watch(sessionUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final form = ref.watch(profileControllerProvider);
    final failure = form.failure;
    final busy = form.submitting || _signingOut;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: spacing.xl,
        end: spacing.xl,
        top: spacing.sm,
        bottom: spacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.xl,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.profileTitle,
              style: typography.display.copyWith(color: colors.textPrimary),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radii.column),
              border: Border.all(color: colors.line, width: sizes.hairline),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: spacing.lg + spacing.xs,
                vertical: spacing.section - spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.lg + spacing.xs,
                children: <Widget>[
                  Center(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _name,
                      builder: (context, value, _) => CardoAvatar(
                        identity: AvatarIdentity(
                          name: value.text,
                          colorHex: _avatarColor,
                        ),
                        diameter: metrics.avatarHero,
                        ringColor: colors.surface,
                      ),
                    ),
                  ),
                  Center(
                    child: AvatarColorPicker(
                      selected: _avatarColor,
                      swatchSize: metrics.swatchLarge,
                      enabled: !busy,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _avatarColor = value);
                        }
                      },
                    ),
                  ),
                  Form(
                    key: _formKey,
                    child: CardoTextField(
                      label: l10n.authName,
                      controller: _name,
                      enabled: !busy,
                      maxLength: AuthLimits.nameMax,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        ref
                            .read(profileControllerProvider.notifier)
                            .clearFailure();
                        setState(() {});
                      },
                      onFieldSubmitted: (_) => unawaited(_save(user)),
                      validator: (value) => fieldIssueText(
                        l10n,
                        AuthField.name,
                        AuthValidators.name(value ?? ''),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: spacing.md,
                    children: <Widget>[
                      Text(
                        l10n.profileEmail,
                        style: typography.message.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          user.email,
                          style: typography.message.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (failure != null)
            FormMessage(message: describeApiFailure(l10n, failure)),
          CardoPrimaryButton(
            label: l10n.profileSave,
            busy: form.submitting,
            onPressed: busy || !_isDirty(user)
                ? null
                : () => unawaited(_save(user)),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.sm,
            children: <Widget>[
              CardoSecondaryButton(
                label: l10n.profileSignOut,
                icon: LucideIcons.logOut,
                onPressed: busy ? null : () => unawaited(_signOut()),
              ),
              Text(
                l10n.profileSignOutNote,
                textAlign: TextAlign.center,
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
