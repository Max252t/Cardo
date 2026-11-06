import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cardo_logo.dart';
import '../../../shared/widgets/scrollable_fill.dart';
import '../../../theme/cardo_theme.dart';

class InviteShell extends StatelessWidget {
  const InviteShell({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
          child: ScrollableFill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InviteHeader(title: title),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InviteHeader extends StatelessWidget {
  const InviteHeader({super.key, required this.title});

  final String title;

  static final ThemeData _dark = buildDarkTheme();

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: _dark,
      child: Builder(
        builder: (context) {
          final colors = CardoColors.of(context);
          final typography = CardoTypography.of(context);
          final spacing = CardoSpacing.of(context);
          final layout = CardoLayout.of(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadiusDirectional.vertical(
                bottom: Radius.circular(metrics.heroRadius),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.all(spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.section,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const CardoLogo(),
                        IconButton(
                          tooltip: l10n.commonClose,
                          onPressed: () => context.go(AppRoutes.boards),
                          iconSize: layout.iconHeader,
                          icon: const Icon(LucideIcons.x),
                        ),
                      ],
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: typography.display.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
