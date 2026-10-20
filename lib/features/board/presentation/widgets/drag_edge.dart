import 'package:flutter/widgets.dart';

int edgeDirection({
  required double localX,
  required double width,
  required double edge,
  required TextDirection textDirection,
}) {
  final raw = localX > width - edge
      ? 1
      : localX < edge
      ? -1
      : 0;
  return textDirection == TextDirection.rtl ? -raw : raw;
}

int? edgeDirectionWithin(BuildContext context, Offset global, double edge) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  return edgeDirection(
    localX: box.globalToLocal(global).dx,
    width: box.size.width,
    edge: edge,
    textDirection: Directionality.of(context),
  );
}
