import 'package:flutter/material.dart';

import '../../theme/cardo_theme.dart';
import 'avatar_identity.dart';

class CardoAvatar extends StatelessWidget {
  const CardoAvatar({
    super.key,
    required this.identity,
    required this.diameter,
    this.ringWidth = 0,
    this.ringColor,
    this.semanticLabel,
  });

  final AvatarIdentity identity;
  final double diameter;
  final double ringWidth;
  final Color? ringColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final swatch = colors.avatarSwatch(identity.colorHex);
    return Semantics(
      label: semanticLabel ?? identity.name,
      image: true,
      child: ExcludeSemantics(
        child: AvatarCircle(
          diameter: diameter,
          fill: swatch.fill,
          ringWidth: ringWidth,
          ringColor: ringColor ?? colors.background,
          child: Text(
            identity.initial,
            style: typography
                .avatarInitial(diameter)
                .copyWith(color: swatch.onFill),
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
          ),
        ),
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.diameter,
    required this.fill,
    required this.ringWidth,
    required this.ringColor,
    required this.child,
  });

  final double diameter;
  final Color fill;
  final double ringWidth;
  final Color ringColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: ringWidth > 0
            ? Border.all(color: ringColor, width: ringWidth)
            : null,
      ),
      child: child,
    );
  }
}
