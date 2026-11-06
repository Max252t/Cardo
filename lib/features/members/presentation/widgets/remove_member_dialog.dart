import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/cardo_theme.dart';

Future<bool> confirmRemoveMember(
  BuildContext context, {
  required String memberName,
  required String boardTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) =>
        RemoveMemberDialog(memberName: memberName, boardTitle: boardTitle),
  );
  return confirmed ?? false;
}

class RemoveMemberDialog extends StatelessWidget {
  const RemoveMemberDialog({
    super.key,
    required this.memberName,
    required this.boardTitle,
  });

  final String memberName;
  final String boardTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final radii = CardoRadii.of(context);
    final form = CardoFormTokens.of(context);
    final tokens = CardoColumnTokens.of(context);
    final title = l10n.membersRemoveTitle(memberName);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.button),
    );
    final buttonSize = Size(sizes.tapTarget, sizes.buttonHeight);
    return Dialog(
      backgroundColor: colors.nackBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(form.dialogRadius),
        side: BorderSide(color: colors.nackBorder, width: sizes.hairline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: form.dialogMaxWidth),
        child: Semantics(
          container: true,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.lg,
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
                          LucideIcons.userMinus,
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
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: typography.paragraph.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            l10n.membersRemoveBody(boardTitle),
                            style: typography.message.copyWith(
                              color: colors.textSoft,
                            ),
                          ),
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
                        onPressed: () => Navigator.of(context).pop(false),
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
                          l10n.commonCancel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: colors.nackText,
                          foregroundColor: colors.surface,
                          shape: buttonShape,
                        ),
                        child: Text(
                          l10n.membersRemoveConfirm,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
