import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/avatar_identity.dart';
import '../../theme/cardo_theme.dart';

@immutable
class PreviewPeople {
  const PreviewPeople({
    required this.anya,
    required this.maxim,
    required this.elena,
    required this.olga,
    required this.dmitry,
  });

  factory PreviewPeople.of(AppLocalizations l10n) {
    return PreviewPeople(
      anya: AvatarIdentity(
        name: l10n.previewNameAnya,
        colorHex: CardoAvatarPalette.violet,
      ),
      maxim: AvatarIdentity(
        name: l10n.previewNameMaxim,
        colorHex: CardoAvatarPalette.green,
      ),
      elena: AvatarIdentity(
        name: l10n.previewNameElena,
        colorHex: CardoAvatarPalette.blue,
      ),
      olga: AvatarIdentity(
        name: l10n.previewNameOlga,
        colorHex: CardoAvatarPalette.amber,
      ),
      dmitry: AvatarIdentity(
        name: l10n.previewNameDmitry,
        colorHex: CardoAvatarPalette.pink,
      ),
    );
  }

  final AvatarIdentity anya;
  final AvatarIdentity maxim;
  final AvatarIdentity elena;
  final AvatarIdentity olga;
  final AvatarIdentity dmitry;

  List<AvatarIdentity> get presence => <AvatarIdentity>[
    elena,
    maxim,
    anya,
    olga,
    dmitry,
  ];
}

class PreviewSection extends StatelessWidget {
  const PreviewSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final spacing = CardoSpacing.of(context);
    final typography = CardoTypography.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(top: spacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: typography.overline.copyWith(color: colors.textSecondary),
            ),
          ),
          SizedBox(height: spacing.md),
          child,
        ],
      ),
    );
  }
}
