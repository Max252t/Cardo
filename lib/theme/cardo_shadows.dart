import 'package:flutter/material.dart';

@immutable
class CardoShadows extends ThemeExtension<CardoShadows> {
  const CardoShadows({
    required this.card,
    required this.dragging,
    required this.fab,
  });

  static const CardoShadows light = CardoShadows(
    card: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(17, 19, 24, 0.06),
        offset: Offset(0, 1),
        blurRadius: 2,
      ),
    ],
    dragging: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(17, 19, 24, 0.22),
        offset: Offset(0, 22),
        blurRadius: 44,
      ),
      BoxShadow(
        color: Color.fromRGBO(17, 19, 24, 0.10),
        offset: Offset(0, 6),
        blurRadius: 12,
      ),
    ],
    fab: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(17, 19, 24, 0.28),
        offset: Offset(0, 12),
        blurRadius: 28,
      ),
    ],
  );

  static const CardoShadows dark = CardoShadows(
    card: <BoxShadow>[],
    dragging: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 22),
        blurRadius: 44,
      ),
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.3),
        offset: Offset(0, 6),
        blurRadius: 12,
      ),
    ],
    fab: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.5),
        offset: Offset(0, 12),
        blurRadius: 28,
      ),
    ],
  );

  final List<BoxShadow> card;
  final List<BoxShadow> dragging;
  final List<BoxShadow> fab;

  static CardoShadows of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoShadows>();
    assert(
      extension != null,
      'CardoShadows missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  @override
  CardoShadows copyWith({
    List<BoxShadow>? card,
    List<BoxShadow>? dragging,
    List<BoxShadow>? fab,
  }) {
    return CardoShadows(
      card: card ?? this.card,
      dragging: dragging ?? this.dragging,
      fab: fab ?? this.fab,
    );
  }

  @override
  CardoShadows lerp(covariant ThemeExtension<CardoShadows>? other, double t) {
    if (other is! CardoShadows) {
      return this;
    }
    return CardoShadows(
      card: BoxShadow.lerpList(card, other.card, t) ?? other.card,
      dragging:
          BoxShadow.lerpList(dragging, other.dragging, t) ?? other.dragging,
      fab: BoxShadow.lerpList(fab, other.fab, t) ?? other.fab,
    );
  }
}
