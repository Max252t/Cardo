import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

class AvatarColorPicker extends StatelessWidget {
  const AvatarColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.swatchSize,
    this.enabled = true,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;
  final double? swatchSize;
  final bool enabled;

  static String nameOf(AppLocalizations l10n, String hex) {
    return switch (hex) {
      CardoAvatarPalette.blue => l10n.avatarColorBlue,
      CardoAvatarPalette.green => l10n.avatarColorGreen,
      CardoAvatarPalette.violet => l10n.avatarColorViolet,
      CardoAvatarPalette.pink => l10n.avatarColorPink,
      CardoAvatarPalette.amber => l10n.avatarColorAmber,
      _ => hex,
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.avatarColorLabel,
      child: Wrap(
        children: <Widget>[
          for (final hex in CardoAvatarPalette.choices)
            AvatarColorSwatch(
              hex: hex,
              label: nameOf(l10n, hex),
              size: swatchSize ?? metrics.swatch,
              selected: hex == selected,
              onTap: enabled
                  ? () => onChanged(hex == selected ? null : hex)
                  : null,
            ),
        ],
      ),
    );
  }
}

class AvatarColorSwatch extends StatelessWidget {
  const AvatarColorSwatch({
    super.key,
    required this.hex,
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = CardoFormTokens.of(context);
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final fill = colors.avatarSwatch(hex).fill;
    final ring = sizes.emphasisBorder + metrics.swatchRingGap;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: sizes.tapTarget / 2,
        child: SizedBox.square(
          dimension: sizes.tapTarget,
          child: Center(
            child: ExcludeSemantics(
              child: Container(
                width: size + ring * 2,
                height: size + ring * 2,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: colors.textPrimary,
                          width: sizes.emphasisBorder,
                        )
                      : null,
                ),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
