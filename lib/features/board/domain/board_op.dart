sealed class BoardOp {
  const BoardOp({required this.opId});

  final String opId;

  String? get cardId => null;

  bool referencesColumn(String columnId) => false;
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
  bool referencesColumn(String columnId) => toColumnId == columnId;

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
    this.at,
  });

  @override
  final String cardId;
  final String columnId;
  final String title;
  final String description;
  final String actorId;
  final String? afterId;
  final String? beforeId;
  final DateTime? at;

  @override
  bool referencesColumn(String columnId) => this.columnId == columnId;

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
        other.beforeId == beforeId &&
        other.at == at;
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
    at,
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
    this.at,
  });

  @override
  final String cardId;
  final String title;
  final String actorId;
  final DateTime? at;

  @override
  bool operator ==(Object other) {
    return other is EditCardTitle &&
        other.opId == opId &&
        other.cardId == cardId &&
        other.title == title &&
        other.actorId == actorId &&
        other.at == at;
  }

  @override
  int get hashCode => Object.hash(opId, cardId, title, actorId, at);

  @override
  String toString() => 'EditCardTitle($opId, $cardId)';
}

final class EditCardDescription extends BoardOp {
  const EditCardDescription({
    required super.opId,
    required this.cardId,
    required this.description,
    required this.baseDescriptionVersion,
    required this.actorId,
    this.at,
  });

  @override
  final String cardId;
  final String description;
  final int baseDescriptionVersion;
  final String actorId;
  final DateTime? at;

  @override
  bool operator ==(Object other) {
    return other is EditCardDescription &&
        other.opId == opId &&
        other.cardId == cardId &&
        other.description == description &&
        other.baseDescriptionVersion == baseDescriptionVersion &&
        other.actorId == actorId &&
        other.at == at;
  }

  @override
  int get hashCode => Object.hash(
    opId,
    cardId,
    description,
    baseDescriptionVersion,
    actorId,
    at,
  );

  @override
  String toString() =>
      'EditCardDescription($opId, $cardId, base d$baseDescriptionVersion)';
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

final class CreateColumn extends BoardOp {
  const CreateColumn({
    required super.opId,
    required this.columnId,
    required this.title,
    this.afterId,
    this.beforeId,
  });

  final String columnId;
  final String title;
  final String? afterId;
  final String? beforeId;

  @override
  bool referencesColumn(String columnId) =>
      this.columnId == columnId || afterId == columnId || beforeId == columnId;

  @override
  bool operator ==(Object other) {
    return other is CreateColumn &&
        other.opId == opId &&
        other.columnId == columnId &&
        other.title == title &&
        other.afterId == afterId &&
        other.beforeId == beforeId;
  }

  @override
  int get hashCode => Object.hash(opId, columnId, title, afterId, beforeId);

  @override
  String toString() => 'CreateColumn($opId, $columnId)';
}

final class RenameColumn extends BoardOp {
  const RenameColumn({
    required super.opId,
    required this.columnId,
    required this.title,
  });

  final String columnId;
  final String title;

  @override
  bool referencesColumn(String columnId) => this.columnId == columnId;

  @override
  bool operator ==(Object other) {
    return other is RenameColumn &&
        other.opId == opId &&
        other.columnId == columnId &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(opId, columnId, title);

  @override
  String toString() => 'RenameColumn($opId, $columnId)';
}

final class MoveColumn extends BoardOp {
  const MoveColumn({
    required super.opId,
    required this.columnId,
    required this.baseVersion,
    this.afterId,
    this.beforeId,
  });

  final String columnId;
  final int baseVersion;
  final String? afterId;
  final String? beforeId;

  @override
  bool referencesColumn(String columnId) =>
      this.columnId == columnId || afterId == columnId || beforeId == columnId;

  @override
  bool operator ==(Object other) {
    return other is MoveColumn &&
        other.opId == opId &&
        other.columnId == columnId &&
        other.baseVersion == baseVersion &&
        other.afterId == afterId &&
        other.beforeId == beforeId;
  }

  @override
  int get hashCode =>
      Object.hash(opId, columnId, baseVersion, afterId, beforeId);

  @override
  String toString() => 'MoveColumn($opId, $columnId, base v$baseVersion)';
}

final class ArchiveColumn extends BoardOp {
  const ArchiveColumn({required super.opId, required this.columnId});

  final String columnId;

  @override
  bool referencesColumn(String columnId) => this.columnId == columnId;

  @override
  bool operator ==(Object other) {
    return other is ArchiveColumn &&
        other.opId == opId &&
        other.columnId == columnId;
  }

  @override
  int get hashCode => Object.hash(opId, columnId);

  @override
  String toString() => 'ArchiveColumn($opId, $columnId)';
}
