import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/scrollable_fill.dart';
import '../../../theme/cardo_theme.dart';
import 'widgets/profile_form.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final layout = CardoLayout.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
            child: ScrollableFill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: spacing.sm,
                      end: spacing.lg,
                      top: spacing.md,
                    ),
                    child: Row(
                      spacing: spacing.xs,
                      children: <Widget>[
                        IconButton(
                          tooltip: l10n.profileBack,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.boards),
                          iconSize: layout.iconHeader,
                          icon: const Icon(LucideIcons.chevronLeft),
                        ),
                        Text(
                          l10n.profileBack,
                          style: typography.body.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: ProfileForm()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
