import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';
import 'avatar_identity.dart';
import 'cardo_avatar.dart';

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    required this.diameter,
    required this.overlap,
    required this.ringWidth,
    this.ringColor,
    this.maxVisible = 4,
  }) : assert(maxVisible > 0);

  final List<AvatarIdentity> people;
  final double diameter;
  final double overlap;
  final double ringWidth;
  final Color? ringColor;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final ring = ringColor ?? CardoColors.of(context).background;
    final visible = people.take(maxVisible).toList();
    final hidden = people.length - visible.length;
    final slots = visible.length + (hidden > 0 ? 1 : 0);
    final step = math.max<double>(0, diameter - overlap);
    return Semantics(
      container: true,
      label: l10n.presenceCount(people.length),
      child: SizedBox(
        width: diameter + step * (slots - 1),
        height: diameter,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (var i = 0; i < visible.length; i++)
              PositionedDirectional(
                start: step * i,
                top: 0,
                child: CardoAvatar(
                  identity: visible[i],
                  diameter: diameter,
                  ringWidth: ringWidth,
                  ringColor: ring,
                ),
              ),
            if (hidden > 0)
              PositionedDirectional(
                start: step * visible.length,
                top: 0,
                child: AvatarOverflowBubble(
                  count: hidden,
                  diameter: diameter,
                  ringWidth: ringWidth,
                  ringColor: ring,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AvatarOverflowBubble extends StatelessWidget {
  const AvatarOverflowBubble({
    super.key,
    required this.count,
    required this.diameter,
    required this.ringWidth,
    required this.ringColor,
  });

  final int count;
  final double diameter;
  final double ringWidth;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    return ExcludeSemantics(
      child: AvatarCircle(
        diameter: diameter,
        fill: colors.avatarOverflowBackground,
        ringWidth: ringWidth,
        ringColor: ringColor,
        child: Text(
          AppLocalizations.of(context).avatarOverflow(count),
          style: typography
              .avatarInitial(diameter)
              .copyWith(color: colors.avatarOverflowText),
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}
