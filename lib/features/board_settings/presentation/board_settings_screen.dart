import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/board_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/api_failure_text.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/cardo_text_field.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/scrollable_fill.dart';
import '../../../theme/cardo_theme.dart';
import '../../board/presentation/board_providers.dart';
import '../../boards/domain/board_info.dart';
import 'board_settings_controller.dart';
import 'danger_confirm_block.dart';

void openBoardSettings(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => UncontrolledProviderScope(
          container: container,
          child: const BoardSettingsScreen(),
        ),
      ),
    ),
  );
}

class BoardSettingsScreen extends ConsumerStatefulWidget {
  const BoardSettingsScreen({super.key});

  @override
  ConsumerState<BoardSettingsScreen> createState() =>
      _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends ConsumerState<BoardSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  bool _confirming = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: ref.read(boardViewProvider).title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final boardId = ref.read(boardViewProvider).id;
    setState(() => _saved = false);
    final done = await ref
        .read(boardSettingsControllerProvider.notifier)
        .rename(boardId, _title.text.trim());
    if (mounted && done) {
      setState(() => _saved = true);
    }
  }

  Future<void> _exit({required bool owner}) async {
    final boardId = ref.read(boardViewProvider).id;
    final userId = ref.read(currentUserProvider).userId;
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final onBack = ref.read(boardNavigationProvider).onBack;
    final controller = ref.read(boardSettingsControllerProvider.notifier);
    final done = owner
        ? await controller.delete(boardId)
        : await controller.leave(boardId, userId);
    if (!done) {
      return;
    }
    if (route != null && route.isActive) {
      navigator.pop();
    }
    onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    final role = ref.watch(currentRoleProvider);
    final board = ref.watch(boardViewProvider);
    final owner = role == BoardRole.owner;
    final settings = ref.watch(boardSettingsControllerProvider);
    final busy = settings.busy != null;
    final failure = settings.failure;
    final failedAction = settings.failedAction;
    final others = board.members.length - 1;
    ref.listen<bool>(
      boardNotifierProvider.select((state) => state.ended != null),
      (previous, ended) {
        final route = ModalRoute.of(context);
        if (ended && mounted && route != null) {
          Navigator.of(context).removeRoute(route);
        }
      },
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
            child: ScrollableFill(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md,
                  end: spacing.md,
                  top: spacing.sm,
                  bottom: spacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.lg,
                  children: <Widget>[
                    Row(
                      spacing: spacing.xs,
                      children: <Widget>[
                        IconButton(
                          tooltip: l10n.boardSettingsBack,
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          iconSize: layout.iconHeader,
                          icon: const Icon(LucideIcons.chevronLeft),
                        ),
                        Expanded(
                          child: Text(
                            board.title,
                            style: typography.message.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: spacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: spacing.xl,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.boardSettingsTitle,
                              style: typography.display.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (owner)
                            _RenameForm(
                              formKey: _formKey,
                              controller: _title,
                              busy: settings.busy == SettingsAction.rename,
                              locked: busy,
                              saved: _saved,
                              onChanged: () {
                                if (_saved) {
                                  setState(() => _saved = false);
                                }
                                ref
                                    .read(
                                      boardSettingsControllerProvider.notifier,
                                    )
                                    .dismissFailure();
                              },
                              onSubmit: () => unawaited(_rename()),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              spacing: spacing.md,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    l10n.boardSettingsRole,
                                    style: typography.message.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                RoleBadge(role: role),
                              ],
                            ),
                          if (failure != null &&
                              failedAction == SettingsAction.rename)
                            FormMessage(
                              message: describeApiFailure(l10n, failure),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: spacing.sm,
                      ),
                      child: DangerZone(
                        title: owner
                            ? l10n.boardSettingsDeleteTitle
                            : l10n.boardSettingsLeaveTitle,
                        body: owner
                            ? (others > 0
                                  ? l10n.boardSettingsDeleteBody(others)
                                  : l10n.boardSettingsDeleteAlone)
                            : l10n.boardSettingsLeaveBody(board.title),
                        startLabel: owner
                            ? l10n.boardSettingsDeleteAction
                            : l10n.boardSettingsLeaveAction,
                        confirmLabel: owner
                            ? l10n.boardSettingsDeleteConfirm
                            : l10n.boardSettingsLeaveConfirm,
                        confirmIcon: owner
                            ? LucideIcons.trash2
                            : LucideIcons.logOut,
                        confirming: _confirming,
                        busy:
                            settings.busy == SettingsAction.delete ||
                            settings.busy == SettingsAction.leave,
                        locked: busy,
                        failure: failedAction == SettingsAction.rename
                            ? null
                            : failure,
                        onStart: () => setState(() => _confirming = true),
                        onCancel: () {
                          setState(() => _confirming = false);
                          ref
                              .read(boardSettingsControllerProvider.notifier)
                              .dismissFailure();
                        },
                        onConfirm: () => unawaited(_exit(owner: owner)),
                      ),
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

class _RenameForm extends StatelessWidget {
  const _RenameForm({
    required this.formKey,
    required this.controller,
    required this.busy,
    required this.locked,
    required this.saved,
    required this.onChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool busy;
  final bool locked;
  final bool saved;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: <Widget>[
          CardoTextField(
            label: l10n.boardSettingsName,
            controller: controller,
            enabled: !locked,
            maxLength: BoardLimits.titleMax,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
            onFieldSubmitted: (_) => onSubmit(),
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
              valueListenable: controller,
              builder: (context, value, _) => Text(
                l10n.boardTitleCounter(
                  value.text.trim().runes.length,
                  BoardLimits.titleMax,
                ),
                style: typography.mono.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          if (saved)
            FormMessage(
              message: l10n.boardSettingsSaved,
              tone: FormMessageTone.info,
            ),
          CardoPrimaryButton(
            label: l10n.boardSettingsSave,
            large: false,
            busy: busy,
            onPressed: locked ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
