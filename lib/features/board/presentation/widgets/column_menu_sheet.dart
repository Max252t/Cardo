import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/rune_length_formatter.dart';
import '../../../../shared/widgets/single_line_formatter.dart';
import '../../../../theme/cardo_theme.dart';
import '../../domain/op_limits.dart';
import '../board_providers.dart';
import '../column_menu_data.dart';

class ColumnNameDraft {
  ColumnNameDraft(this.initial) : text = initial;

  final String initial;
  String text;
  bool discarded = false;
}

Future<void> showColumnMenu(BuildContext context, String columnId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final sizes = CardoSizes.of(context);
  final title = container.read(columnMenuProvider(columnId))?.title;
  if (title == null) {
    return;
  }
  final draft = ColumnNameDraft(title);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: BoxConstraints(maxWidth: sizes.previewMaxWidth),
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: ColumnMenuSheet(columnId: columnId, draft: draft),
    ),
  );
  if (!draft.discarded && draft.text.trim() != draft.initial) {
    container
        .read(boardNotifierProvider.notifier)
        .renameColumn(columnId: columnId, title: draft.text);
  }
}

class ColumnMenuSheet extends ConsumerWidget {
  const ColumnMenuSheet({
    super.key,
    required this.columnId,
    required this.draft,
  });

  final String columnId;
  final ColumnNameDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(
      columnMenuProvider(columnId).select((data) => data == null),
      (previous, gone) {
        if (gone && context.mounted) {
          draft.discarded = true;
          unawaited(Navigator.of(context).maybePop());
        }
      },
    );
    ref.listen<bool>(canEditBoardProvider, (previous, canEdit) {
      if (!canEdit && context.mounted) {
        draft.discarded = true;
        unawaited(Navigator.of(context).maybePop());
      }
    });
    ref.listen<bool>(
      boardNotifierProvider.select((state) => state.ended != null),
      (previous, ended) {
        final route = ModalRoute.of(context);
        if (ended && context.mounted && route != null) {
          draft.discarded = true;
          Navigator.of(context).removeRoute(route);
        }
      },
    );
    final data = ref.watch(columnMenuProvider(columnId));
    if (data == null) {
      return const SizedBox.shrink();
    }
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: l10n.columnSheetSemantic(data.title),
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.only(
          start: spacing.xl,
          end: spacing.xl,
          top: layout.sheetPaddingTop,
          bottom:
              layout.sheetPaddingBottom +
              MediaQuery.viewPaddingOf(context).bottom +
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.md + spacing.xxs,
          children: <Widget>[
            const _SheetHandle(),
            _NameField(draft: draft),
            _MoveItems(columnId: columnId, data: data),
            ColumnArchiveBlock(
              data: data,
              onCancel: () => unawaited(Navigator.of(context).maybePop()),
              onConfirm: () {
                draft.discarded = true;
                ref
                    .read(boardNotifierProvider.notifier)
                    .archiveColumn(columnId);
                unawaited(Navigator.of(context).maybePop());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: sizes.sheetHandleWidth,
          height: sizes.sheetHandleHeight,
          decoration: BoxDecoration(
            color: colors.lineStrong,
            borderRadius: BorderRadius.circular(CardoRadii.of(context).pill),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.draft});

  final ColumnNameDraft draft;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoColumnTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.iconGap,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            l10n.columnNameLabel,
            style: typography.pill.copyWith(color: colors.textSoft),
          ),
        ),
        Semantics(
          label: l10n.columnNameLabel,
          textField: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tokens.nameFieldHeight),
            child: TextField(
              controller: _controller,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: <TextInputFormatter>[
                const SingleLineFormatter(),
                const RuneLengthLimitingFormatter(ColumnLimits.titleMaxLength),
              ],
              style: typography.paragraph.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) => widget.draft.text = value,
              onSubmitted: (_) => unawaited(Navigator.of(context).maybePop()),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoveItems extends ConsumerWidget {
  const _MoveItems({required this.columnId, required this.data});

  final String columnId;
  final ColumnMenuData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(boardNotifierProvider.notifier);
    final earlier = ColumnMenuItem(
      icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
      label: rtl ? l10n.columnMoveRight : l10n.columnMoveLeft,
      onTap: data.canMoveEarlier
          ? () => notifier.moveColumn(columnId: columnId, direction: -1)
          : null,
    );
    final later = ColumnMenuItem(
      icon: rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
      label: rtl ? l10n.columnMoveLeft : l10n.columnMoveRight,
      onTap: data.canMoveLater
          ? () => notifier.moveColumn(columnId: columnId, direction: 1)
          : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rtl ? <Widget>[later, earlier] : <Widget>[earlier, later],
    );
  }
}

class ColumnMenuItem extends StatelessWidget {
  const ColumnMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoColumnTokens.of(context);
    final color = onTap == null ? colors.textSecondary : colors.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.menuItemHeight),
            padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.xs),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.background,
                  width: sizes.hairline,
                ),
              ),
            ),
            child: Row(
              spacing: spacing.md,
              children: <Widget>[
                Icon(icon, size: sizes.iconLarge, color: color),
                Expanded(
                  child: Text(
                    label,
                    style: typography.body.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColumnArchiveBlock extends StatelessWidget {
  const ColumnArchiveBlock({
    super.key,
    required this.data,
    required this.onCancel,
    required this.onConfirm,
  });

  final ColumnMenuData data;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final tokens = CardoColumnTokens.of(context);
    final radii = CardoRadii.of(context);
    final l10n = AppLocalizations.of(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.button),
    );
    final buttonSize = Size(sizes.tapTarget, sizes.buttonHeight);
    return Container(
      padding: EdgeInsetsDirectional.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.nackBackground,
        borderRadius: BorderRadius.circular(tokens.dangerRadius),
        border: Border.all(color: colors.nackBorder, width: sizes.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md + spacing.xxs,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.md,
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: tokens.dangerIconBox,
                  height: tokens.dangerIconBox,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(
                      tokens.dangerIconRadius,
                    ),
                    border: Border.all(
                      color: colors.nackBorder,
                      width: sizes.hairline,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.archive,
                    size: sizes.iconLarge,
                    color: colors.nackText,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: spacing.xs,
                  children: <Widget>[
                    Text(
                      l10n.columnArchiveTitle(data.title),
                      style: typography.paragraph.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _ArchiveBody(count: data.cardCount),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: spacing.sm,
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: buttonSize,
                    backgroundColor: colors.surface,
                    foregroundColor: colors.textPrimary,
                    shape: buttonShape,
                    side: BorderSide(
                      color: colors.nackBorder,
                      width: sizes.hairline,
                    ),
                  ),
                  child: Text(
                    l10n.columnArchiveCancel,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: buttonSize,
                    backgroundColor: colors.nackText,
                    foregroundColor: colors.surface,
                    shape: buttonShape,
                  ),
                  child: Text(
                    l10n.columnArchiveConfirm,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchiveBody extends StatelessWidget {
  const _ArchiveBody({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final l10n = AppLocalizations.of(context);
    final style = typography.message.copyWith(color: colors.textSoft);
    if (count == 0) {
      return Text(l10n.columnArchiveBodyEmpty, style: style);
    }
    final cards = l10n.columnArchiveCards(count);
    final body = l10n.columnArchiveBody(cards);
    final at = body.indexOf(cards);
    if (at < 0) {
      return Text(body, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: body.substring(0, at)),
          TextSpan(
            text: cards,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          TextSpan(text: body.substring(at + cards.length)),
        ],
      ),
    );
  }
}
