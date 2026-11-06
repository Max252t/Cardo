import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class CardoSyncTokens extends ThemeExtension<CardoSyncTokens> {
  const CardoSyncTokens({
    required this.noticeIconBox,
    required this.noticeIconRadius,
    required this.noticeIcon,
    required this.summaryMaxWidth,
    required this.summaryBottomInset,
    required this.rejectedItemGap,
  });

  static const CardoSyncTokens standard = CardoSyncTokens(
    noticeIconBox: 56,
    noticeIconRadius: 18,
    noticeIcon: 26,
    summaryMaxWidth: 420,
    summaryBottomInset: 20,
    rejectedItemGap: 10,
  );

  final double noticeIconBox;
  final double noticeIconRadius;
  final double noticeIcon;
  final double summaryMaxWidth;
  final double summaryBottomInset;
  final double rejectedItemGap;

  static CardoSyncTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoSyncTokens>();
    assert(
      extension != null,
      'CardoSyncTokens missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  @override
  CardoSyncTokens copyWith({
    double? noticeIconBox,
    double? noticeIconRadius,
    double? noticeIcon,
    double? summaryMaxWidth,
    double? summaryBottomInset,
    double? rejectedItemGap,
  }) {
    return CardoSyncTokens(
      noticeIconBox: noticeIconBox ?? this.noticeIconBox,
      noticeIconRadius: noticeIconRadius ?? this.noticeIconRadius,
      noticeIcon: noticeIcon ?? this.noticeIcon,
      summaryMaxWidth: summaryMaxWidth ?? this.summaryMaxWidth,
      summaryBottomInset: summaryBottomInset ?? this.summaryBottomInset,
      rejectedItemGap: rejectedItemGap ?? this.rejectedItemGap,
    );
  }

  @override
  CardoSyncTokens lerp(ThemeExtension<CardoSyncTokens>? other, double t) {
    if (other is! CardoSyncTokens) {
      return this;
    }
    return CardoSyncTokens(
      noticeIconBox: lerpDouble(noticeIconBox, other.noticeIconBox, t)!,
      noticeIconRadius: lerpDouble(
        noticeIconRadius,
        other.noticeIconRadius,
        t,
      )!,
      noticeIcon: lerpDouble(noticeIcon, other.noticeIcon, t)!,
      summaryMaxWidth: lerpDouble(summaryMaxWidth, other.summaryMaxWidth, t)!,
      summaryBottomInset: lerpDouble(
        summaryBottomInset,
        other.summaryBottomInset,
        t,
      )!,
      rejectedItemGap: lerpDouble(rejectedItemGap, other.rejectedItemGap, t)!,
    );
  }
}
