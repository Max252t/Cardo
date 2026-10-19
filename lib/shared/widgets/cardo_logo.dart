import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

enum CardoLogoSize { regular, large }

class CardoLogo extends StatelessWidget {
  const CardoLogo({
    super.key,
    this.size = CardoLogoSize.regular,
    this.showWordmark = true,
  });

  final CardoLogoSize size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final sizes = CardoSizes.of(context);
    final typography = CardoTypography.of(context);
    final l10n = AppLocalizations.of(context);
    final large = size == CardoLogoSize.large;
    final markSize = large ? sizes.logoMarkLarge : sizes.logoMark;
    final wordStyle = large ? typography.logoLarge : typography.logo;
    return Semantics(
      label: l10n.logoSemanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: large ? sizes.logoGapLarge : sizes.logoGap,
          children: <Widget>[
            CustomPaint(
              size: Size.square(markSize),
              painter: CardoLogoPainter(
                backColor: colors.textPrimary,
                frontColor: colors.accent,
              ),
            ),
            if (showWordmark)
              Text(
                l10n.brandName,
                style: wordStyle.copyWith(color: colors.textPrimary),
              ),
          ],
        ),
      ),
    );
  }
}

class CardoLogoPainter extends CustomPainter {
  const CardoLogoPainter({required this.backColor, required this.frontColor});

  final Color backColor;
  final Color frontColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / CardoLogoGeometry.viewBox;
    final radius = Radius.circular(CardoLogoGeometry.cornerRadius * scale);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          scaleRect(CardoLogoGeometry.back, scale),
          radius,
        ),
        Paint()..color = backColor,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          scaleRect(CardoLogoGeometry.front, scale),
          radius,
        ),
        Paint()..color = frontColor,
      );
  }

  static Rect scaleRect(Rect rect, double scale) {
    return Rect.fromLTWH(
      rect.left * scale,
      rect.top * scale,
      rect.width * scale,
      rect.height * scale,
    );
  }

  @override
  bool shouldRepaint(CardoLogoPainter oldDelegate) {
    return oldDelegate.backColor != backColor ||
        oldDelegate.frontColor != frontColor;
  }
}
