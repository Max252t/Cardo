import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/scrollable_fill.dart';
import '../../../theme/cardo_theme.dart';
import 'widgets/register_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final layout = CardoLayout.of(context);
    final spacing = CardoSpacing.of(context);
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
                      top: spacing.md,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        tooltip: l10n.registerBack,
                        onPressed: () => context.go(
                          AppRoutes.keepFrom(
                            AppRoutes.login,
                            GoRouterState.of(context).uri,
                          ),
                        ),
                        iconSize: layout.iconHeader,
                        icon: const Icon(LucideIcons.chevronLeft),
                      ),
                    ),
                  ),
                  const Expanded(child: RegisterForm()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
