import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';
import 'preview_section.dart';
import 'preview_sections.dart';

class DesignSystemPreview extends StatelessWidget {
  const DesignSystemPreview({super.key});

  static final ThemeData _lightTheme = buildLightTheme();
  static final ThemeData _darkTheme = buildDarkTheme();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sizes = CardoSizes.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.previewTitle)),
      body: ListView(
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sizes.previewMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _PreviewPane(
                    title: l10n.previewLightTheme,
                    theme: _lightTheme,
                  ),
                  _PreviewPane(title: l10n.previewDarkTheme, theme: _darkTheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = CardoColors.of(context);
          final spacing = CardoSpacing.of(context);
          final typography = CardoTypography.of(context);
          final people = PreviewPeople.of(AppLocalizations.of(context));
          return Material(
            color: colors.background,
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    title,
                    style: typography.display.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const PreviewLogoSection(),
                  PreviewCardsSection(people: people, dense: false),
                  PreviewCardsSection(people: people, dense: true),
                  const PreviewConnectionSection(),
                  PreviewRolesSection(people: people),
                  const PreviewButtonsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
