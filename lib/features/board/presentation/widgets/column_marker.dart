import 'package:flutter/material.dart';

import '../../../../theme/cardo_theme.dart';
import '../../domain/board_model.dart';

Color columnMarkerColor(CardoColors colors, ColumnMarker marker) {
  return switch (marker) {
    ColumnMarker.backlog => colors.columnBacklog,
    ColumnMarker.inProgress => colors.columnInProgress,
    ColumnMarker.review => colors.columnReview,
    ColumnMarker.done => colors.columnDone,
  };
}

class MarkerSquare extends StatelessWidget {
  const MarkerSquare({
    super.key,
    required this.color,
    required this.size,
    required this.radius,
  });

  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

class ColumnMarkerSquare extends StatelessWidget {
  const ColumnMarkerSquare({
    super.key,
    required this.marker,
    required this.size,
    required this.radius,
  });

  final ColumnMarker marker;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return MarkerSquare(
      color: columnMarkerColor(CardoColors.of(context), marker),
      size: size,
      radius: radius,
    );
  }
}
