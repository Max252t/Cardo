import 'package:flutter/foundation.dart';

@immutable
sealed class BoardOp {
  const BoardOp({required this.opId});

  final String opId;

  String get cardId;
}

final class MoveCard extends BoardOp {
  const MoveCard({
    required super.opId,
    required this.cardId,
    required this.toColumnId,
    required this.baseVersion,
    this.afterId,
    this.beforeId,
  });

  @override
  final String cardId;
  final String toColumnId;
  final String? afterId;
  final String? beforeId;
  final int baseVersion;

  @override
  bool operator ==(Object other) {
    return other is MoveCard &&
        other.opId == opId &&
        other.cardId == cardId &&
        other.toColumnId == toColumnId &&
        other.afterId == afterId &&
        other.beforeId == beforeId &&
        other.baseVersion == baseVersion;
  }

  @override
  int get hashCode =>
      Object.hash(opId, cardId, toColumnId, afterId, beforeId, baseVersion);

  @override
  String toString() =>
      'MoveCard($opId, $cardId -> $toColumnId, after $afterId, '
      'before $beforeId, base v$baseVersion)';
}

final class CreateCard extends BoardOp {
  const CreateCard({
    required super.opId,
    required this.cardId,
    required this.columnId,
    required this.title,
    required this.actorId,
    this.description = '',
    this.afterId,
    this.beforeId,
  });

  @override
  final String cardId;
  final String columnId;
  final String title;
  final String description;
  final String actorId;
  final String? afterId;
  final String? beforeId;

  @override
  bool operator ==(Object other) {
    return other is CreateCard &&
        other.opId == opId &&
        other.cardId == cardId &&
        other.columnId == columnId &&
        other.title == title &&
        other.description == description &&
        other.actorId == actorId &&
        other.afterId == afterId &&
        other.beforeId == beforeId;
  }

  @override
  int get hashCode => Object.hash(
    opId,
    cardId,
    columnId,
    title,
    description,
    actorId,
    afterId,
    beforeId,
  );

  @override
  String toString() => 'CreateCard($opId, $cardId in $columnId)';
}

final class EditCardTitle extends BoardOp {
  const EditCardTitle({
    required super.opId,
    required this.cardId,
    required this.title,
    required this.actorId,
  });

  @override
  final String cardId;
  final String title;
  final String actorId;

  @override
  bool operator ==(Object other) {
    return other is EditCardTitle &&
        other.opId == opId &&
        other.cardId == cardId &&
        other.title == title &&
        other.actorId == actorId;
  }

  @override
  int get hashCode => Object.hash(opId, cardId, title, actorId);

  @override
  String toString() => 'EditCardTitle($opId, $cardId)';
}

final class ArchiveCard extends BoardOp {
  const ArchiveCard({required super.opId, required this.cardId});

  @override
  final String cardId;

  @override
  bool operator ==(Object other) {
    return other is ArchiveCard && other.opId == opId && other.cardId == cardId;
  }

  @override
  int get hashCode => Object.hash(opId, cardId);

  @override
  String toString() => 'ArchiveCard($opId, $cardId)';
}
