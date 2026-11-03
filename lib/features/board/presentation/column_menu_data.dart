import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_providers.dart';

@immutable
class ColumnMenuData {
  const ColumnMenuData({
    required this.title,
    required this.cardCount,
    required this.canMoveEarlier,
    required this.canMoveLater,
  });

  final String title;
  final int cardCount;
  final bool canMoveEarlier;
  final bool canMoveLater;

  @override
  bool operator ==(Object other) {
    return other is ColumnMenuData &&
        other.title == title &&
        other.cardCount == cardCount &&
        other.canMoveEarlier == canMoveEarlier &&
        other.canMoveLater == canMoveLater;
  }

  @override
  int get hashCode =>
      Object.hash(title, cardCount, canMoveEarlier, canMoveLater);
}

final columnMenuProvider = Provider.autoDispose.family<ColumnMenuData?, String>(
  (ref, columnId) {
    final columns = ref.watch(boardColumnsProvider);
    final index = columns.indexWhere((item) => item.column.id == columnId);
    if (index < 0) {
      return null;
    }
    return ColumnMenuData(
      title: columns[index].column.title,
      cardCount: columns[index].count,
      canMoveEarlier: index > 0,
      canMoveLater: index < columns.length - 1,
    );
  },
  dependencies: [boardColumnsProvider],
);
