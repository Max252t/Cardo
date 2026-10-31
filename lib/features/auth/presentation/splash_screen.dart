import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/cardo_buttons.dart';
import '../../../shared/widgets/cardo_logo.dart';
import '../../../theme/cardo_theme.dart';
import '../domain/session.dart';
import 'auth_providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final spacing = CardoSpacing.of(context);
    final unavailable = ref.watch(sessionProvider) is SessionUnavailable;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsetsDirectional.all(spacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.formMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.xl,
                children: <Widget>[
                  const Center(child: CardoLogo(size: CardoLogoSize.large)),
                  if (unavailable) ...<Widget>[
                    Text(
                      l10n.splashUnavailableTitle,
                      textAlign: TextAlign.center,
                      style: typography.title.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    CardoPrimaryButton(
                      label: l10n.commonRetry,
                      onPressed: () => unawaited(
                        ref.read(sessionProvider.notifier).retryRestore(),
                      ),
                    ),
                  ] else ...<Widget>[
                    const Center(child: BusyIndicator()),
                    Text(
                      l10n.splashRestoring,
                      textAlign: TextAlign.center,
                      style: typography.message.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
