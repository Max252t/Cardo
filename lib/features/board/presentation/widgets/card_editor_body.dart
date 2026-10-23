import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/conflict_banner.dart';
import '../../../../theme/cardo_theme.dart';
import '../card_drafts.dart';
import '../card_sheet_data.dart';
import 'card_description_field.dart';
import 'card_editor_style.dart';
import 'card_meta_row.dart';
import 'card_nack_strip.dart';
import 'card_title_editor.dart';

class CardEditorBody extends ConsumerWidget {
  const CardEditorBody({
    super.key,
    required this.cardId,
    required this.variant,
    this.saveOnBlur = false,
  });

  final String cardId;
  final CardEditorVariant variant;
  final bool saveOnBlur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exists = ref.watch(
      cardSheetProvider(cardId).select((data) => data != null),
    );
    if (!exists) {
      return const SizedBox.shrink();
    }
    final gap = CardoLayout.of(context).panelGap;
    final header = _CardEditorHeader(cardId: cardId, variant: variant);
    final description = CardDescriptionSection(
      cardId: cardId,
      variant: variant,
      saveOnBlur: saveOnBlur,
    );
    if (variant == CardEditorVariant.panel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: <Widget>[header, description],
      );
    }
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        SliverToBoxAdapter(child: header),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: gap),
            child: description,
          ),
        ),
      ],
    );
  }
}

class _CardEditorHeader extends ConsumerWidget {
  const _CardEditorHeader({required this.cardId, required this.variant});

  final String cardId;
  final CardEditorVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cardSheetProvider(cardId).select((data) => data?.header),
    );
    if (data == null) {
      return const SizedBox.shrink();
    }
    final style = CardEditorStyle.of(context, variant);
    final conflict = data.conflict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CardoLayout.of(context).panelGap,
      children: <Widget>[
        if (variant == CardEditorVariant.sheet) CardNackStrip(cardId: cardId),
        CardTitleEditor(
          cardId: cardId,
          title: data.title,
          editable: data.editable,
          style: style.title,
        ),
        CardMetaRow(
          createdBy: data.createdBy,
          createdAt: data.createdAt,
          version: data.version,
          avatarDiameter: style.avatarDiameter,
        ),
        if (conflict != null)
          _DescriptionConflictBanner(cardId: cardId, conflict: conflict),
      ],
    );
  }
}

class _DescriptionConflictBanner extends ConsumerWidget {
  const _DescriptionConflictBanner({
    required this.cardId,
    required this.conflict,
  });

  final String cardId;
  final CardConflictData conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final actorName = conflict.actorName;
    return ConflictBanner(
      title: actorName == null
          ? l10n.cardConflictTitleUnknown
          : l10n.cardConflictTitle(actorName),
      text: l10n.cardConflictBody,
      onOverwrite: () =>
          ref.read(cardDraftsProvider.notifier).overwrite(cardId),
      onCancel: () => ref.read(cardDraftsProvider.notifier).discard(cardId),
      waitingText: conflict.resolvable ? null : l10n.cardConflictWaiting,
    );
  }
}
