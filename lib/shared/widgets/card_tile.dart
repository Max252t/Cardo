import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';
import 'avatar_identity.dart';
import 'cardo_avatar.dart';
import 'dashed_border.dart';

enum CardTileState { confirmed, pending, dragging, rejected }

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.title,
    this.state = CardTileState.confirmed,
    this.hasDescription = false,
    this.updatedBy,
    this.editingBy,
    this.rejectReason,
    this.dense = false,
    this.onTap,
  });

  final String title;
  final CardTileState state;
  final bool hasDescription;
  final AvatarIdentity? updatedBy;
  final AvatarIdentity? editingBy;
  final String? rejectReason;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final motion = CardoMotion.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lifted = state == CardTileState.dragging && !reduceMotion;
    final duration = resolveMotion(context, motion.lift);
    final editor = state == CardTileState.rejected ? null : editingBy;
    return MergeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final floatingTag =
              editor != null &&
              CardEditingTag.canFloat(
                context,
                editor: editor,
                dense: dense,
                cardWidth: constraints.maxWidth,
              );
          return AnimatedRotation(
            turns: lifted ? motion.dragTiltTurns : 0,
            duration: duration,
            curve: motion.liftCurve,
            child: AnimatedScale(
              scale: lifted ? motion.dragScale : 1,
              duration: duration,
              curve: motion.liftCurve,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  CardTileSurface(
                    state: state,
                    dense: dense,
                    editingBy: editor,
                    onTap: onTap,
                    child: _CardTileContent(
                      title: title,
                      inlineTag: editor != null && !floatingTag
                          ? CardEditingTagLabel(editor: editor, dense: dense)
                          : null,
                      state: state,
                      hasDescription: hasDescription,
                      updatedBy: updatedBy,
                      rejectReason: rejectReason,
                      dense: dense,
                    ),
                  ),
                  if (editor != null && floatingTag)
                    CardEditingTag(editor: editor, dense: dense),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CardTileSurface extends StatelessWidget {
  const CardTileSurface({
    super.key,
    required this.state,
    required this.dense,
    required this.editingBy,
    required this.onTap,
    required this.child,
  });

  final CardTileState state;
  final bool dense;
  final AvatarIdentity? editingBy;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final shadows = CardoShadows.of(context);
    final motion = CardoMotion.of(context);
    final radius = CardoRadii.of(context).cardFor(dense: dense);
    final borderRadius = BorderRadius.circular(radius);
    final dashed = state == CardTileState.pending;
    final side = _side(colors, sizes);
    final inset = spacing.cardPaddingFor(dense: dense) + sizes.hairline;
    final padding = inset - (dashed ? 0 : side.width);
    final surface = AnimatedContainer(
      duration: resolveMotion(context, motion.lift),
      curve: motion.liftCurve,
      decoration: BoxDecoration(
        color: state == CardTileState.rejected
            ? colors.nackBackground
            : colors.card,
        borderRadius: borderRadius,
        border: dashed ? null : Border.fromBorderSide(side),
        boxShadow: state == CardTileState.dragging
            ? shadows.dragging
            : shadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: sizes.tapTarget),
            child: Padding(
              padding: EdgeInsetsDirectional.all(padding),
              child: child,
            ),
          ),
        ),
      ),
    );
    if (!dashed) {
      return surface;
    }
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: colors.pendingBorder,
        strokeWidth: sizes.pendingBorder,
        radius: radius,
        dashLength: sizes.dashLength,
        gapLength: sizes.dashGap,
      ),
      child: surface,
    );
  }

  BorderSide _side(CardoColors colors, CardoSizes sizes) {
    final editor = editingBy;
    return switch (state) {
      CardTileState.pending => BorderSide.none,
      CardTileState.dragging => BorderSide(
        color: colors.dragBorder,
        width: sizes.emphasisBorder,
      ),
      CardTileState.rejected => BorderSide(
        color: colors.nackBorder,
        width: sizes.hairline,
      ),
      CardTileState.confirmed when editor != null => BorderSide(
        color: colors.avatarSwatch(editor.colorHex).accent,
        width: sizes.emphasisBorder,
      ),
      CardTileState.confirmed => BorderSide(
        color: colors.cardBorder,
        width: sizes.hairline,
      ),
    };
  }
}

class _CardTileContent extends StatelessWidget {
  const _CardTileContent({
    required this.title,
    required this.inlineTag,
    required this.state,
    required this.hasDescription,
    required this.updatedBy,
    required this.rejectReason,
    required this.dense,
  });

  final String title;
  final Widget? inlineTag;
  final CardTileState state;
  final bool hasDescription;
  final AvatarIdentity? updatedBy;
  final String? rejectReason;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final tag = inlineTag;
    final rejected = state == CardTileState.rejected;
    final titleStyle = (dense ? typography.bodyDense : typography.body)
        .copyWith(
          color: rejected ? colors.textSecondary : colors.textPrimary,
          decoration: rejected ? TextDecoration.lineThrough : null,
          decorationColor: colors.textSecondary,
        );
    final showStatus = state != CardTileState.confirmed || hasDescription;
    final author = updatedBy;
    final reason = rejectReason;
    final showFooter = showStatus || author != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (tag != null) ...<Widget>[
          Align(alignment: AlignmentDirectional.topEnd, child: tag),
          SizedBox(height: spacing.xs),
        ],
        Text(title, style: titleStyle),
        if (showFooter) ...<Widget>[
          SizedBox(height: spacing.cardContentGapFor(dense: dense)),
          CardTileFooter(
            state: state,
            showStatus: showStatus,
            updatedBy: author,
            dense: dense,
          ),
        ],
        if (rejected && reason != null) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(
            reason,
            style: typography.caption.copyWith(color: colors.nackText),
          ),
        ],
      ],
    );
  }
}

class CardTileFooter extends StatelessWidget {
  const CardTileFooter({
    super.key,
    required this.state,
    required this.showStatus,
    required this.updatedBy,
    required this.dense,
  });

  final CardTileState state;
  final bool showStatus;
  final AvatarIdentity? updatedBy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final author = updatedBy;
    return Row(
      children: <Widget>[
        Expanded(
          child: showStatus
              ? _CardStatusLine(state: state, dense: dense)
              : const SizedBox.shrink(),
        ),
        if (author != null) ...<Widget>[
          SizedBox(width: spacing.sm),
          CardoAvatar(
            identity: author,
            diameter: sizes.avatarFooterFor(dense: dense),
            semanticLabel: l10n.cardUpdatedBy(author.name),
          ),
        ],
      ],
    );
  }
}

class _CardStatusLine extends StatelessWidget {
  const _CardStatusLine({required this.state, required this.dense});

  final CardTileState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final (IconData icon, String label) = switch (state) {
      CardTileState.confirmed => (
        LucideIcons.textAlignStart,
        l10n.cardDescription,
      ),
      CardTileState.pending => (LucideIcons.clock, l10n.cardPending),
      CardTileState.dragging => (LucideIcons.move, l10n.cardDragging),
      CardTileState.rejected => (LucideIcons.circleAlert, l10n.cardRejected),
    };
    final color = state == CardTileState.rejected
        ? colors.nackText
        : colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            icon,
            size: sizes.iconFooterFor(dense: dense),
            color: color,
          ),
        ),
        SizedBox(width: spacing.iconGap),
        Flexible(
          child: Text(label, style: typography.caption.copyWith(color: color)),
        ),
      ],
    );
  }
}

class CardEditingTag extends StatelessWidget {
  const CardEditingTag({super.key, required this.editor, required this.dense});

  final AvatarIdentity editor;
  final bool dense;

  static String visibleLabel(
    AppLocalizations l10n,
    AvatarIdentity editor, {
    required bool dense,
  }) {
    return dense ? editor.name : l10n.cardEditingBy(editor.name);
  }

  static bool canFloat(
    BuildContext context, {
    required AvatarIdentity editor,
    required bool dense,
    required double cardWidth,
  }) {
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final style = CardoTypography.of(context).tag;
    final painter = TextPainter(
      text: TextSpan(
        text: visibleLabel(AppLocalizations.of(context), editor, dense: dense),
        style: MediaQuery.boldTextOf(context)
            ? style.copyWith(fontWeight: FontWeight.bold)
            : style,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 2 * _horizontalPadding(spacing, dense);
    final height = painter.height + 2 * _verticalPadding(spacing, dense);
    painter.dispose();
    final contentTop = spacing.cardPaddingFor(dense: dense) + sizes.hairline;
    final available = cardWidth - 2 * _inset(spacing, dense);
    return height - spacing.tagOffset <= contentTop && width <= available;
  }

  static double _inset(CardoSpacing spacing, bool dense) =>
      dense ? spacing.tagInsetEndDense : spacing.tagInsetEnd;

  static double _horizontalPadding(CardoSpacing spacing, bool dense) =>
      dense ? spacing.tagPaddingHorizontalDense : spacing.tagPaddingHorizontal;

  static double _verticalPadding(CardoSpacing spacing, bool dense) =>
      dense ? spacing.tagPaddingVerticalDense : spacing.tagPaddingVertical;

  @override
  Widget build(BuildContext context) {
    final spacing = CardoSpacing.of(context);
    final inset = _inset(spacing, dense);
    return PositionedDirectional(
      top: -spacing.tagOffset,
      start: inset,
      end: inset,
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: CardEditingTagLabel(editor: editor, dense: dense),
      ),
    );
  }
}

class CardEditingTagLabel extends StatelessWidget {
  const CardEditingTagLabel({
    super.key,
    required this.editor,
    required this.dense,
  });

  final AvatarIdentity editor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final l10n = AppLocalizations.of(context);
    final swatch = colors.avatarSwatch(editor.colorHex);
    return Semantics(
      label: l10n.cardEditingBy(editor.name),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: swatch.accent,
            borderRadius: BorderRadius.circular(radii.tag),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: CardEditingTag._horizontalPadding(spacing, dense),
              vertical: CardEditingTag._verticalPadding(spacing, dense),
            ),
            child: Text(
              CardEditingTag.visibleLabel(l10n, editor, dense: dense),
              style: typography.tag.copyWith(color: swatch.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class CardDropPlaceholder extends StatelessWidget {
  const CardDropPlaceholder({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final radius = CardoRadii.of(context).cardFor(dense: dense);
    return Semantics(
      label: AppLocalizations.of(context).cardDropPlaceholder,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: colors.dropPlaceholderBorder,
          strokeWidth: sizes.emphasisBorder,
          radius: radius,
          dashLength: sizes.dashLength,
          gapLength: sizes.dashGap,
        ),
        child: Container(
          height: sizes.dropPlaceholderFor(dense: dense),
          decoration: BoxDecoration(
            color: colors.dropPlaceholderFill,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
