import 'board_model.dart';
import 'board_op.dart';

abstract final class ColumnLimits {
  static const int titleMaxLength = 200;
}

int? textLimitOf(BoardOp op) {
  return switch (op) {
    EditCardDescription() => CardLimits.descriptionMaxLength,
    CreateCard() || EditCardTitle() => CardLimits.titleMaxLength,
    CreateColumn() || RenameColumn() => ColumnLimits.titleMaxLength,
    MoveCard() || ArchiveCard() || MoveColumn() || ArchiveColumn() => null,
  };
}
