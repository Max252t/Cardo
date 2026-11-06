import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/board_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/cardo_buttons.dart';
import '../../../../shared/widgets/cardo_text_field.dart';
import '../../../../shared/widgets/form_message.dart';
import '../../../../shared/widgets/role_badge.dart';
import '../../../../theme/cardo_theme.dart';
import '../../../auth/domain/auth_validation.dart';
import '../../../auth/presentation/auth_texts.dart';
import '../../domain/invite_policy.dart';
import '../members_controller.dart';
import '../members_texts.dart';
import 'role_picker.dart';

class AddMemberForm extends ConsumerStatefulWidget {
  const AddMemberForm({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends ConsumerState<AddMemberForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  BoardRole _role = InvitePolicy.defaultRole;
  String? _addedName;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final email = _email.text.trim();
    final member = await ref
        .read(membersControllerProvider(widget.boardId).notifier)
        .addMember(email: email, role: _role);
    if (!mounted || member == null) {
      return;
    }
    _email.clear();
    form.reset();
    setState(() => _addedName = member.name);
  }

  void _onChanged(String value) {
    ref
        .read(membersControllerProvider(widget.boardId).notifier)
        .clearAddFailure();
    if (_addedName != null) {
      setState(() => _addedName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = CardoSpacing.of(context);
    final state = ref.watch(membersControllerProvider(widget.boardId));
    final failure = state.addFailure;
    final added = _addedName;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: <Widget>[
          CardoTextField(
            label: l10n.membersAddLabel,
            controller: _email,
            enabled: !state.adding,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            maxLength: AuthLimits.emailMax,
            onChanged: _onChanged,
            onFieldSubmitted: (_) => unawaited(_submit()),
            autovalidateMode: AutovalidateMode.disabled,
            validator: (value) => fieldIssueText(
              l10n,
              AuthField.email,
              AuthValidators.email(value ?? ''),
            ),
          ),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              RolePickerButton(
                role: _role,
                semanticLabel: l10n.membersRoleForNew(
                  RoleBadge.labelFor(l10n, _role),
                ),
                onSelected: state.adding
                    ? null
                    : (role) => setState(() => _role = role),
              ),
              CardoPrimaryButton(
                label: l10n.membersAddAction,
                busy: state.adding,
                large: false,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          ),
          if (failure != null)
            FormMessage(message: addMemberFailureText(l10n, failure))
          else if (added != null)
            FormMessage(
              message: l10n.membersAdded(added),
              tone: FormMessageTone.info,
            ),
        ],
      ),
    );
  }
}
