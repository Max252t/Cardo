import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../shared/providers/app_config_provider.dart';
import '../shared/widgets/cardo_buttons.dart';
import '../shared/widgets/cardo_logo.dart';
import '../theme/cardo_theme.dart';
import 'app_routes.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final sizes = CardoSizes.of(context);
    final radii = CardoRadii.of(context);
    final config = ref.watch(appConfigProvider);
    final showDemo = kDebugMode && config.rawValue.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(spacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.xl,
                children: <Widget>[
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CardoLogo(),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.configTitle,
                      style: typography.display.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    l10n.configHint,
                    style: typography.paragraph.copyWith(
                      color: colors.textSoft,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(radii.field),
                      border: Border.all(
                        color: colors.line,
                        width: sizes.hairline,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.all(spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: spacing.xs,
                        children: <Widget>[
                          Text(
                            l10n.configCurrentValue.toUpperCase(),
                            style: typography.overline.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          SelectableText(
                            config.rawValue.isEmpty
                                ? l10n.configValueEmpty
                                : config.rawValue,
                            style: typography.mono.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showDemo)
                    CardoPrimaryButton(
                      label: l10n.configOpenDemo,
                      onPressed: () => context.go(AppRoutes.demo),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
