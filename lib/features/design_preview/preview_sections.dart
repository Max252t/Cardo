import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/board_role.dart';
import '../../core/realtime/connection_status.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/avatar_stack.dart';
import '../../shared/widgets/card_tile.dart';
import '../../shared/widgets/cardo_logo.dart';
import '../../shared/widgets/connection_pill.dart';
import '../../shared/widgets/role_badge.dart';
import '../../theme/cardo_theme.dart';
import 'preview_section.dart';

class PreviewLogoSection extends StatelessWidget {
  const PreviewLogoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    return PreviewSection(
      title: AppLocalizations.of(context).previewSectionLogo,
      child: Wrap(
        spacing: spacing.section,
        runSpacing: spacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const <Widget>[
          CardoLogo(size: CardoLogoSize.large),
          CardoLogo(),
          CardoLogo(showWordmark: false),
        ],
      ),
    );
  }
}

class PreviewCardsSection extends StatelessWidget {
  const PreviewCardsSection({
    super.key,
    required this.people,
    required this.dense,
  });

  final PreviewPeople people;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final gap = SizedBox(height: spacing.cardGapFor(dense: dense));
    return PreviewSection(
      title: dense ? l10n.previewSectionCardsDense : l10n.previewSectionCards,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.column,
          border: Border.all(color: colors.columnBorder),
          borderRadius: BorderRadius.circular(radii.columnFor(dense: dense)),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CardTile(
                title: l10n.previewCardConfirmed,
                hasDescription: true,
                updatedBy: people.anya,
                dense: dense,
                onTap: () {},
              ),
              gap,
              CardTile(
                title: l10n.previewCardPending,
                state: CardTileState.pending,
                dense: dense,
              ),
              gap,
              CardDropPlaceholder(dense: dense),
              gap,
              CardTile(
                title: l10n.previewCardRejected,
                state: CardTileState.rejected,
                rejectReason: l10n.previewRejectReason,
                dense: dense,
              ),
              SizedBox(height: spacing.lg),
              CardTile(
                title: l10n.previewCardEditing,
                hasDescription: true,
                updatedBy: people.anya,
                editingBy: people.anya,
                dense: dense,
                onTap: () {},
              ),
              SizedBox(height: spacing.xl),
              CardTile(
                title: l10n.previewCardDragging,
                state: CardTileState.dragging,
                updatedBy: people.maxim,
                dense: dense,
              ),
              SizedBox(height: spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewConnectionSection extends StatelessWidget {
  const PreviewConnectionSection({super.key});

  static const int _sampleReconnectSeconds = 4;

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    return PreviewSection(
      title: AppLocalizations.of(context).previewSectionConnection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.lg,
        children: <Widget>[
          for (final variant in ConnectionPillVariant.values)
            Wrap(
              spacing: variant == ConnectionPillVariant.pill
                  ? spacing.md
                  : spacing.xl,
              runSpacing: spacing.md,
              children: <Widget>[
                for (final status in ConnectionStatus.values)
                  ConnectionPill(
                    status: status,
                    reconnectSeconds: _sampleReconnectSeconds,
                    variant: variant,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class PreviewRolesSection extends StatelessWidget {
  const PreviewRolesSection({super.key, required this.people});

  final PreviewPeople people;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    return PreviewSection(
      title: AppLocalizations.of(context).previewSectionRoles,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.lg,
        children: <Widget>[
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              for (final role in BoardRole.values) RoleBadge(role: role),
            ],
          ),
          Wrap(
            spacing: spacing.xl,
            runSpacing: spacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AvatarStack(
                people: people.presence.take(4).toList(),
                diameter: sizes.avatarPresenceLarge,
                overlap: sizes.avatarOverlapLarge,
                ringWidth: sizes.avatarRingLarge,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(
                    CardoRadii.of(context).badge,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.all(spacing.sm),
                  child: AvatarStack(
                    people: people.presence,
                    diameter: sizes.avatarPresence,
                    overlap: sizes.avatarOverlap,
                    ringWidth: sizes.avatarRing,
                    ringColor: colors.surface,
                    maxVisible: 3,
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

class PreviewButtonsSection extends StatelessWidget {
  const PreviewButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    return PreviewSection(
      title: l10n.previewSectionButtons,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.lg,
        children: <Widget>[
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(LucideIcons.plus),
                label: Text(l10n.previewNewBoard),
              ),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
                child: Text(l10n.previewInvite),
              ),
              OutlinedButton(onPressed: () {}, child: Text(l10n.previewCancel)),
              TextButton(onPressed: () {}, child: Text(l10n.previewOverwrite)),
            ],
          ),
          TextField(
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: InputDecoration(hintText: l10n.previewEmailHint),
          ),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: _PreviewSnackbarButton(),
          ),
        ],
      ),
    );
  }
}

class _PreviewSnackbarButton extends StatelessWidget {
  const _PreviewSnackbarButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton(
      onPressed: () {
        final colors = CardoColors.of(context);
        final sizes = CardoSizes.of(context);
        final spacing = CardoSpacing.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              spacing: spacing.snackbarGap,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.circleAlert,
                    size: sizes.iconSnackbar,
                    color: colors.snackbarIcon,
                  ),
                ),
                Expanded(child: Text(l10n.previewSnackbarMessage)),
              ],
            ),
            action: SnackBarAction(
              label: l10n.previewSnackbarAction,
              onPressed: () {},
            ),
          ),
        );
      },
      child: Text(l10n.previewShowSnackbar),
    );
  }
}
